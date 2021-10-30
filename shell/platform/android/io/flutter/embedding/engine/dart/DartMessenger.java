// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.embedding.engine.dart;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.UiThread;
import androidx.tracing.Trace;
import io.flutter.Log;
import io.flutter.embedding.engine.FlutterJNI;
import io.flutter.plugin.common.BinaryMessenger;
import java.nio.ByteBuffer;
import java.util.HashMap;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.WeakHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.ThreadFactory;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Message conduit for 2-way communication between Android and Dart.
 *
 * <p>See {@link BinaryMessenger}, which sends messages from Android to Dart
 *
 * <p>See {@link PlatformMessageHandler}, which handles messages to Android from Dart
 */
class DartMessenger implements BinaryMessenger, PlatformMessageHandler {
  private static final String TAG = "DartMessenger";

  @NonNull private final FlutterJNI flutterJNI;

  /**
   * Maps a channel name to an object that contains the task queue and the handler associated with
   * the channel.
   *
   * <p>Reads and writes to this map must lock {@code handlersLock}.
   */
  @NonNull private final Map<String, HandlerInfo> messageHandlers = new HashMap<>();

  /**
   * Maps a channel name to an object that holds information about the incoming Dart message.
   *
   * <p>Reads and writes to this map must lock {@code handlersLock}.
   */
  @NonNull private final Map<String, List<BufferedMessageInfo>> bufferedMessages = new HashMap<>();

  @NonNull private final Object handlersLock = new Object();
  private boolean enableBufferingIncomingMessages = false;

  @NonNull private final Map<Integer, BinaryMessenger.BinaryReply> pendingReplies = new HashMap<>();
  private int nextReplyId = 1;

  @NonNull private final DartMessengerTaskQueue platformTaskQueue = new PlatformTaskQueue();

  @NonNull
  private WeakHashMap<TaskQueue, DartMessengerTaskQueue> createdTaskQueues =
      new WeakHashMap<TaskQueue, DartMessengerTaskQueue>();

  @NonNull private TaskQueueFactory taskQueueFactory;

  DartMessenger(@NonNull FlutterJNI flutterJNI, @NonNull TaskQueueFactory taskQueueFactory) {
    this.flutterJNI = flutterJNI;
    this.taskQueueFactory = taskQueueFactory;
  }

  DartMessenger(@NonNull FlutterJNI flutterJNI) {
    this(flutterJNI, new DefaultTaskQueueFactory());
  }

  private static class TaskQueueToken implements TaskQueue {}

  interface DartMessengerTaskQueue {
    void dispatch(@NonNull Runnable runnable);
  }

  interface TaskQueueFactory {
    DartMessengerTaskQueue makeBackgroundTaskQueue();
  }

  private static class DefaultTaskQueueFactory implements TaskQueueFactory {
    public DartMessengerTaskQueue makeBackgroundTaskQueue() {
      return new DefaultTaskQueue();
    }
  }

  /**
   * Holds information about a platform handler, such as the task queue that processes messages from
   * Dart.
   */
  private static class HandlerInfo {
    @NonNull public final BinaryMessenger.BinaryMessageHandler handler;
    @Nullable public final DartMessengerTaskQueue taskQueue;

    HandlerInfo(
        @NonNull BinaryMessenger.BinaryMessageHandler handler,
        @Nullable DartMessengerTaskQueue taskQueue) {
      this.handler = handler;
      this.taskQueue = taskQueue;
    }
  }

  /**
   * Holds information that allows to dispatch a Dart message to a platform handler when it becomes
   * available.
   */
  private static class BufferedMessageInfo {
    @NonNull public final ByteBuffer message;
    int replyId;
    long messageData;

    BufferedMessageInfo(@NonNull ByteBuffer message, int replyId, long messageData) {
      this.message = message;
      this.replyId = replyId;
      this.messageData = messageData;
    }
  }

  private static class DefaultTaskQueue implements DartMessengerTaskQueue {
    @NonNull private final ExecutorService executor;

    DefaultTaskQueue() {
      // TODO(gaaclarke): Use a shared thread pool with serial queues instead of
      // making a thread for each TaskQueue.
      ThreadFactory threadFactory =
          (Runnable runnable) -> {
            return new Thread(runnable, "DartMessenger.DefaultTaskQueue");
          };
      this.executor = Executors.newSingleThreadExecutor(threadFactory);
    }

    @Override
    public void dispatch(@NonNull Runnable runnable) {
      executor.execute(runnable);
    }
  }

  @Override
  public TaskQueue makeBackgroundTaskQueue() {
    DartMessengerTaskQueue taskQueue = taskQueueFactory.makeBackgroundTaskQueue();
    TaskQueueToken token = new TaskQueueToken();
    createdTaskQueues.put(token, taskQueue);
    return token;
  }

  @Override
  public void setMessageHandler(
      @NonNull String channel, @Nullable BinaryMessenger.BinaryMessageHandler handler) {
    setMessageHandler(channel, handler, null);
  }

  @Override
  public void setMessageHandler(
      @NonNull String channel,
      @Nullable BinaryMessenger.BinaryMessageHandler handler,
      @Nullable TaskQueue taskQueue) {
    if (handler == null) {
      Log.v(TAG, "Removing handler for channel '" + channel + "'");
      synchronized (handlersLock) {
        messageHandlers.remove(channel);
      }
      return;
    }
    DartMessengerTaskQueue dartMessengerTaskQueue = null;
    if (taskQueue != null) {
      dartMessengerTaskQueue = createdTaskQueues.get(taskQueue);
      if (dartMessengerTaskQueue == null) {
        throw new IllegalArgumentException(
            "Unrecognized TaskQueue, use BinaryMessenger to create your TaskQueue (ex makeBackgroundTaskQueue).");
      }
    }
    Log.v(TAG, "Setting handler for channel '" + channel + "'");

    LinkedList<BufferedMessageInfo> list;
    synchronized (handlersLock) {
      messageHandlers.put(channel, new HandlerInfo(handler, dartMessengerTaskQueue));
      if (!bufferedMessages.containsKey(channel)) {
        return;
      }
      list = (LinkedList) bufferedMessages.get(channel);
      bufferedMessages.remove(channel);
    }
    for (BufferedMessageInfo info : list) {
      dispatchMessageToQueue(
          channel, messageHandlers.get(channel), info.message, info.replyId, info.messageData);
    }
  }

  /**
   * Enables the ability to queue tasks when messages are received from Dart.
   *
   * <p>This is useful when there are pending channel handler registrations. For example, Dart may
   * be initialized concurrently, and prior to the registration of the channel handlers. This
   * implies that Dart may start sending messages while plugins are being registered.
   */
  public void enableBufferingIncomingMessages() {
    enableBufferingIncomingMessages = true;
  }

  @Override
  @UiThread
  public void send(@NonNull String channel, @NonNull ByteBuffer message) {
    Log.v(TAG, "Sending message over channel '" + channel + "'");
    send(channel, message, null);
  }

  @Override
  public void send(
      @NonNull String channel,
      @Nullable ByteBuffer message,
      @Nullable BinaryMessenger.BinaryReply callback) {
    Trace.beginSection("DartMessenger#send on " + channel);
    Log.v(TAG, "Sending message with callback over channel '" + channel + "'");

    try {
      int replyId = nextReplyId++;
      if (callback != null) {
        pendingReplies.put(replyId, callback);
      }
      if (message == null) {
        flutterJNI.dispatchEmptyPlatformMessage(channel, replyId);
      } else {
        flutterJNI.dispatchPlatformMessage(channel, message, message.position(), replyId);
      }
    } finally {
      Trace.endSection();
    }
  }

  private void invokeHandler(
      @Nullable HandlerInfo handlerInfo, @Nullable ByteBuffer message, final int replyId) {
    // Called from any thread.
    if (handlerInfo != null) {
      try {
        Log.v(TAG, "Deferring to registered handler to process message.");
        handlerInfo.handler.onMessage(message, new Reply(flutterJNI, replyId));
      } catch (Exception ex) {
        Log.e(TAG, "Uncaught exception in binary message listener", ex);
        flutterJNI.invokePlatformMessageEmptyResponseCallback(replyId);
      } catch (Error err) {
        handleError(err);
      }
    } else {
      Log.v(TAG, "No registered handler for message. Responding to Dart with empty reply message.");
      flutterJNI.invokePlatformMessageEmptyResponseCallback(replyId);
    }
  }

  private void dispatchMessageToQueue(
      @NonNull String channel,
      @Nullable HandlerInfo handlerInfo,
      @Nullable ByteBuffer message,
      int replyId,
      long messageData) {
    final DartMessengerTaskQueue taskQueue = (handlerInfo != null) ? handlerInfo.taskQueue : null;
    Runnable myRunnable =
        () -> {
          Trace.beginSection("DartMessenger#handleMessageFromDart on " + channel);
          try {
            invokeHandler(handlerInfo, message, replyId);
            if (message != null && message.isDirect()) {
              // This ensures that if a user retains an instance to the ByteBuffer and it
              // happens to be direct they will get a deterministic error.
              message.limit(0);
            }
          } finally {
            // This is deleting the data underneath the message object.
            flutterJNI.cleanupMessageData(messageData);
            Trace.endSection();
          }
        };
    final DartMessengerTaskQueue nonnullTaskQueue =
        taskQueue == null ? platformTaskQueue : taskQueue;
    nonnullTaskQueue.dispatch(myRunnable);
  }

  @Override
  public void handleMessageFromDart(
      @NonNull String channel, @Nullable ByteBuffer message, int replyId, long messageData) {
    // Called from the ui thread.
    Log.v(TAG, "Received message from Dart over channel '" + channel + "'");

    HandlerInfo handlerInfo;
    boolean messageDeferred;
    synchronized (handlersLock) {
      handlerInfo = messageHandlers.get(channel);
      messageDeferred = (enableBufferingIncomingMessages && handlerInfo == null);
      if (messageDeferred) {
        // The channel is not defined when the Dart VM sends a message before the channels are
        // registered.
        //
        // This is possible if the Dart VM starts before channel registration, and if the thread
        // that registers the channels is busy or slow at registering the channel handlers.
        //
        // In such cases, the task dispatchers are queued, and processed when the channel is
        // defined.
        if (!bufferedMessages.containsKey(channel)) {
          bufferedMessages.put(channel, new LinkedList<>());
        }
        List<BufferedMessageInfo> buffer = bufferedMessages.get(channel);
        buffer.add(new BufferedMessageInfo(message, replyId, messageData));
      }
    }
    if (!messageDeferred) {
      dispatchMessageToQueue(channel, handlerInfo, message, replyId, messageData);
    }
  }

  @Override
  public void handlePlatformMessageResponse(int replyId, @Nullable ByteBuffer reply) {
    Log.v(TAG, "Received message reply from Dart.");
    BinaryMessenger.BinaryReply callback = pendingReplies.remove(replyId);
    if (callback != null) {
      try {
        Log.v(TAG, "Invoking registered callback for reply from Dart.");
        callback.reply(reply);
        if (reply != null && reply.isDirect()) {
          // This ensures that if a user retains an instance to the ByteBuffer and it happens to
          // be direct they will get a deterministic error.
          reply.limit(0);
        }
      } catch (Exception ex) {
        Log.e(TAG, "Uncaught exception in binary message reply handler", ex);
      } catch (Error err) {
        handleError(err);
      }
    }
  }

  /**
   * Returns the number of pending channel callback replies.
   *
   * <p>When sending messages to the Flutter application using {@link BinaryMessenger#send(String,
   * ByteBuffer, io.flutter.plugin.common.BinaryMessenger.BinaryReply)}, developers can optionally
   * specify a reply callback if they expect a reply from the Flutter application.
   *
   * <p>This method tracks all the pending callbacks that are waiting for response, and is supposed
   * to be called from the main thread (as other methods). Calling from a different thread could
   * possibly capture an indeterministic internal state, so don't do it.
   */
  @UiThread
  public int getPendingChannelResponseCount() {
    return pendingReplies.size();
  }

  // Handles `Error` objects which are not supposed to be caught.
  //
  // We forward them to the thread's uncaught exception handler if there is one. If not, they
  // are rethrown.
  private static void handleError(Error err) {
    Thread currentThread = Thread.currentThread();
    if (currentThread.getUncaughtExceptionHandler() == null) {
      throw err;
    }
    currentThread.getUncaughtExceptionHandler().uncaughtException(currentThread, err);
  }

  static class Reply implements BinaryMessenger.BinaryReply {
    @NonNull private final FlutterJNI flutterJNI;
    private final int replyId;
    private final AtomicBoolean done = new AtomicBoolean(false);

    Reply(@NonNull FlutterJNI flutterJNI, int replyId) {
      this.flutterJNI = flutterJNI;
      this.replyId = replyId;
    }

    @Override
    public void reply(@Nullable ByteBuffer reply) {
      if (done.getAndSet(true)) {
        throw new IllegalStateException("Reply already submitted");
      }
      if (reply == null) {
        flutterJNI.invokePlatformMessageEmptyResponseCallback(replyId);
      } else {
        flutterJNI.invokePlatformMessageResponseCallback(replyId, reply, reply.position());
      }
    }
  }
}
