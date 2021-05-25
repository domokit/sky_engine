package io.flutter.embedding.engine.dart;

import static junit.framework.TestCase.assertNotNull;
import static junit.framework.TestCase.assertTrue;
import static org.mockito.Matchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import io.flutter.embedding.engine.FlutterJNI;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.BinaryMessenger.BinaryMessageHandler;
import java.nio.ByteBuffer;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.Mockito;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;

@Config(manifest = Config.NONE)
@RunWith(RobolectricTestRunner.class)
public class DartMessengerTest {
  private static class ReportingUncaughtExceptionHandler
      implements Thread.UncaughtExceptionHandler {
    public Throwable latestException;

    @Override
    public void uncaughtException(Thread t, Throwable e) {
      latestException = e;
    }
  }

  @Test
  public void itHandlesErrors() {
    // Setup test.
    final FlutterJNI fakeFlutterJni = mock(FlutterJNI.class);
    final Thread currentThread = Thread.currentThread();
    final Thread.UncaughtExceptionHandler savedHandler =
        currentThread.getUncaughtExceptionHandler();
    final ReportingUncaughtExceptionHandler reportingHandler =
        new ReportingUncaughtExceptionHandler();
    currentThread.setUncaughtExceptionHandler(reportingHandler);

    // Create object under test.
    final DartMessenger messenger = new DartMessenger(fakeFlutterJni);
    final BinaryMessageHandler throwingHandler = mock(BinaryMessageHandler.class);
    Mockito.doThrow(AssertionError.class)
        .when(throwingHandler)
        .onMessage(any(ByteBuffer.class), any(DartMessenger.Reply.class));

    messenger.setMessageHandler("test", throwingHandler, true);
    messenger.handleMessageFromDart("test", ByteBuffer.allocate(0), 0);
    assertNotNull(reportingHandler.latestException);
    assertTrue(reportingHandler.latestException instanceof AssertionError);
    currentThread.setUncaughtExceptionHandler(savedHandler);
  }

  @Test
  public void setsDirectByteBuffer() {
    final FlutterJNI fakeFlutterJni = mock(FlutterJNI.class);
    final DartMessenger messenger = new DartMessenger(fakeFlutterJni);
    final String channel = "foo";
    final BinaryMessenger.BinaryMessageHandler handler = (byteBuffer, reply) -> {};
    messenger.setMessageHandler(channel, handler, true);
    verify(fakeFlutterJni, never())
        .setDirectByteBufferDecodingPreference(Mockito.anyString(), Mockito.anyBoolean());
  }

  @Test
  public void setsIndirectByteBuffer() {
    final FlutterJNI fakeFlutterJni = mock(FlutterJNI.class);
    final DartMessenger messenger = new DartMessenger(fakeFlutterJni);
    final String channel = "foo";
    final BinaryMessenger.BinaryMessageHandler handler = (byteBuffer, reply) -> {};
    when(fakeFlutterJni.isAttached()).thenReturn(true);
    messenger.setMessageHandler(channel, handler, false);
    verify(fakeFlutterJni).setDirectByteBufferDecodingPreference(channel, false);
  }

  @Test
  public void clearsDirectByteBuffer() {
    final FlutterJNI fakeFlutterJni = mock(FlutterJNI.class);
    final DartMessenger messenger = new DartMessenger(fakeFlutterJni);
    final String channel = "foo";
    messenger.setMessageHandler(channel, null, true);
    verify(fakeFlutterJni).clearDirectByteBufferDecodingPreference(channel);
  }
}
