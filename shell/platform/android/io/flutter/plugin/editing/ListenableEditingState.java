// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugin.editing;

import android.text.Editable;
import android.text.Selection;
import android.text.SpannableStringBuilder;
import android.view.View;
import android.view.inputmethod.BaseInputConnection;
import io.flutter.Log;
import io.flutter.embedding.engine.systemchannels.TextInputChannel;
import java.util.ArrayList;

/// The current editing state (text, selection range, composing range) the text input plugin holds.
///
/// As the name implies, this class also notifies its listeners when the editing state changes. When
/// there're ongoing batch edits, change notifications will be deferred until all batch edits end
/// (i.e. when the outermost batch edit ends). Listeners added during a batch edit will always be
/// notified when all batch edits end, even if there's no real change.
///
/// Adding/removing listeners or changing the editing state in a didChangeEditingState callback may
/// cause unexpected behavior.
//
// Currently this class does not notify its listeners on spans-only changes (e.g.,
// Selection.setSelection). Wrap them in a batch edit to trigger a change notification.
class ListenableEditingState extends SpannableStringBuilder {
  interface EditingStateWatcher {
    // Changing the editing state in a didChangeEditingState callback may cause unexpected
    // behavior.
    void didChangeEditingState(
        boolean textChanged, boolean selectionChanged, boolean composingRegionChanged);
  }

  private static final String TAG = "flutter";

  private int mBatchEditNestDepth = 0;
  // We don't support adding/removing listeners, or changing the editing state in a listener
  // callback for now.
  private int mChangeNotificationDepth = 0;
  private ArrayList<EditingStateWatcher> mListeners = new ArrayList<>();
  private ArrayList<EditingStateWatcher> mPendingListeners = new ArrayList<>();

  private String mToStringCache;

  private String mTextWhenBeginBatchEdit;
  private int mSelectionStartWhenBeginBatchEdit;
  private int mSelectionEndWhenBeginBatchEdit;
  private int mComposingStartWhenBeginBatchEdit;
  private int mComposingEndWhenBeginBatchEdit;

  private BaseInputConnection mDummyConnection;

  // The View is only use for creating a dummy BaseInputConnection for setComposingRegion. The View
  // needs to have a non-null Context.
  public ListenableEditingState(TextInputChannel.TextEditState configuration, View view) {
    super();
    if (configuration != null) {
      setEditingState(configuration);
    }

    Editable self = this;
    mDummyConnection =
        new BaseInputConnection(view, true) {
          @Override
          public Editable getEditable() {
            return self;
          }
        };
  }

  /// Starts a new batch edit during which change notifications will be put on hold until all batch
  /// edits end.
  ///
  /// Batch edits nest.
  public void beginBatchEdit() {
    mBatchEditNestDepth++;
    if (mChangeNotificationDepth > 0) {
      Log.e(TAG, "editing state should not be changed in a listener callback");
    }
    if (mBatchEditNestDepth == 1 && !mListeners.isEmpty()) {
      mTextWhenBeginBatchEdit = toString();
      mSelectionStartWhenBeginBatchEdit = getSelecionStart();
      mSelectionEndWhenBeginBatchEdit = getSelecionEnd();
      mComposingStartWhenBeginBatchEdit = getComposingStart();
      mComposingEndWhenBeginBatchEdit = getComposingEnd();
    }
  }

  /// Ends the current batch edit and flush pending change notifications if the current batch edit
  /// is not nested (i.e. it is the last ongoing batch edit).
  public void endBatchEdit() {
    if (mBatchEditNestDepth == 0) {
      Log.e(TAG, "endBatchEdit called without a matching beginBatchEdit");
      return;
    }
    if (mBatchEditNestDepth == 1) {
      for (final EditingStateWatcher listener : mPendingListeners) {
        notifyListener(listener, true, true, true);
      }

      if (!mListeners.isEmpty()) {
        Log.v(TAG, "didFinishBatchEdit with " + String.valueOf(mListeners.size()) + " listener(s)");
        final boolean textChanged = !toString().equals(mTextWhenBeginBatchEdit);
        final boolean selectionChanged =
            mSelectionStartWhenBeginBatchEdit != getSelecionStart()
                || mSelectionEndWhenBeginBatchEdit != getSelecionEnd();
        final boolean composingRegionChanged =
            mComposingStartWhenBeginBatchEdit != getComposingStart()
                || mComposingEndWhenBeginBatchEdit != getComposingEnd();

        notifyListenersIfNeeded(textChanged, selectionChanged, composingRegionChanged);
      }
    }

    mListeners.addAll(mPendingListeners);
    mPendingListeners.clear();
    mBatchEditNestDepth--;
  }

  /// Update the composing region of the current editing state.
  ///
  /// If the range is invalid or empty, the current composing region will be removed.
  public void setComposingRange(int composingStart, int composingEnd) {
    if (composingStart < 0 || composingStart >= composingEnd) {
      BaseInputConnection.removeComposingSpans(this);
    } else {
      mDummyConnection.setComposingRegion(composingStart, composingEnd);
    }
  }

  /// Called when the framework sends updates to the text input plugin.
  ///
  /// This method will also update the composing region if it has changed.
  public void setEditingState(TextInputChannel.TextEditState newState) {
    beginBatchEdit();
    replace(0, length(), newState.text);

    if (newState.selectionStart >= 0 && newState.selectionEnd >= newState.selectionStart) {
      Selection.setSelection(this, newState.selectionStart, newState.selectionEnd);
    } else {
      Selection.removeSelection(this);
    }
    setComposingRange(newState.composingStart, newState.composingEnd);
    endBatchEdit();
  }

  public void addEditingStateListener(EditingStateWatcher listener) {
    if (mChangeNotificationDepth > 0) {
      Log.e(TAG, "adding a listener " + listener.toString() + " in a listener callback");
    }
    // It is possible for a listener to get added during a batch edit. When that happens we always
    // notify the new listeners.
    // This does not check if the listener is already in the list of existing listeners.
    if (mBatchEditNestDepth > 0) {
      Log.w(TAG, "a listener was added to EditingState while a batch edit was in progress");
      mPendingListeners.add(listener);
    } else {
      mListeners.add(listener);
    }
  }

  public void removeEditingStateListener(EditingStateWatcher listener) {
    if (mChangeNotificationDepth > 0) {
      Log.e(TAG, "removing a listener " + listener.toString() + " in a listener callback");
    }
    mListeners.remove(listener);
    if (mBatchEditNestDepth > 0) {
      mPendingListeners.remove(listener);
    }
  }

  @Override
  public SpannableStringBuilder replace(
      int start, int end, CharSequence tb, int tbstart, int tbend) {

    if (mChangeNotificationDepth > 0) {
      Log.e(TAG, "editing state should not be changed in a listener callback");
    }

    boolean textChanged = end - start != tbend - tbstart;
    for (int i = 0; i < end - start && !textChanged; i++) {
      textChanged |= charAt(start + i) != tb.charAt(tbstart + i);
    }
    if (textChanged) {
      mToStringCache = null;
    }

    final int selectionStart = getSelecionStart();
    final int selectionEnd = getSelecionEnd();
    final int composingStart = getComposingStart();
    final int composingEnd = getComposingEnd();

    final SpannableStringBuilder editable = super.replace(start, end, tb, tbstart, tbend);
    if (mBatchEditNestDepth > 0) {
      return editable;
    }

    final boolean selectionChanged =
        getSelecionStart() != selectionStart || getSelecionEnd() != selectionEnd;
    final boolean composingRegionChanged =
        getComposingStart() != composingStart || getComposingEnd() != composingEnd;
    notifyListenersIfNeeded(textChanged, selectionChanged, composingRegionChanged);
    return editable;
  }

  private void notifyListener(
      EditingStateWatcher listener,
      boolean textChanged,
      boolean selectionChanged,
      boolean composingChanged) {
    mChangeNotificationDepth++;
    listener.didChangeEditingState(textChanged, selectionChanged, composingChanged);
    mChangeNotificationDepth--;
  }

  private void notifyListenersIfNeeded(
      boolean textChanged, boolean selectionChanged, boolean composingChanged) {
    if (textChanged || selectionChanged || composingChanged) {
      for (final EditingStateWatcher listener : mListeners) {
        notifyListener(listener, textChanged, selectionChanged, composingChanged);
      }
    }
  }

  public final int getSelecionStart() {
    return Selection.getSelectionStart(this);
  }

  public final int getSelecionEnd() {
    return Selection.getSelectionEnd(this);
  }

  public final int getComposingStart() {
    return BaseInputConnection.getComposingSpanStart(this);
  }

  public final int getComposingEnd() {
    return BaseInputConnection.getComposingSpanEnd(this);
  }

  @Override
  public String toString() {
    return mToStringCache != null ? mToStringCache : (mToStringCache = super.toString());
  }
}
