// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_SHELL_PLATFORM_WINDOWS_KEYBOARD_KEY_HANDLER_H_
#define FLUTTER_SHELL_PLATFORM_WINDOWS_KEYBOARD_KEY_HANDLER_H_

#include <deque>
#include <memory>
#include <string>

#include "flutter/shell/platform/common/client_wrapper/include/flutter/basic_message_channel.h"
#include "flutter/shell/platform/common/client_wrapper/include/flutter/binary_messenger.h"
#include "flutter/shell/platform/windows/keyboard_handler_base.h"
#include "flutter/shell/platform/windows/public/flutter_windows.h"
#include "rapidjson/document.h"

namespace flutter {

class FlutterWindowsView;

// Handles key events.
//
// This class detects whether an incoming event is a redispatched one,
// dispatches native events to delegates and collect their responses,
// and redispatches events unhandled by Flutter back to the system.
// See |KeyboardHook| for more information about dispatching.
//
// The exact behavior to handle events are further forwarded into
// delegates. See |KeyboardKeyHandlerDelegate| and its subclasses.
class KeyboardKeyHandler : public KeyboardHandlerBase {
 public:
  // An interface for concrete definition of how to asynchronously handle key
  // events.
  class KeyboardKeyHandlerDelegate {
   public:
    // Defines how to how to asynchronously handle key events.
    //
    // |KeyboardHook| should invoke |callback| with the response (whether the
    // event is handled) later for exactly once.
    virtual void KeyboardHook(int key,
                              int scancode,
                              int action,
                              char32_t character,
                              bool extended,
                              bool was_down,
                              std::function<void(bool)> callback) = 0;

    virtual ~KeyboardKeyHandlerDelegate();
  };

  using EventRedispatcher =
      std::function<UINT(UINT cInputs, LPINPUT pInputs, int cbSize)>;

  // Create a KeyboardKeyHandler and specify where to redispatch events.
  //
  // The |redispatch_event| is typically |SendInput|.
  explicit KeyboardKeyHandler(EventRedispatcher redispatch_event);

  ~KeyboardKeyHandler();

  // Add a delegate that handles events received by |KeyboardHook|.
  void AddDelegate(std::unique_ptr<KeyboardKeyHandlerDelegate> delegate);

  // Handles a key event.
  //
  // Returns whether this handler claims to handle the event, which is true if
  // the event is a native event, or false if the event is a redispatched one.
  //
  // Windows requires a synchronous response of whether a key event should be
  // handled, while the query to Flutter is always asynchronous. This is
  // resolved by "redispatching": the response to the native event is always
  // true. If Flutter later decides not to handle the event, an event is then
  // synthesized, dispatched to system, received again, detected, at which time
  // |KeyboardHook| returns false, then falls back to other keyboard handlers.
  //
  // Received events are further dispatched to all added delegates. If any
  // delegate returns true (handled), the event is considered handled. When
  // all delegates responded, any unhandled events are redispatched via
  // |redispatch_event| and recorded. The next (one) time this exact event is
  // received, |KeyboardHook| will skip it and immediately return false.
  //
  // Inherited from |KeyboardHandlerBase|.
  bool KeyboardHook(FlutterWindowsView* window,
                    int key,
                    int scancode,
                    int action,
                    char32_t character,
                    bool extended,
                    bool was_down) override;

  // |KeyboardHandlerBase|
  void TextHook(FlutterWindowsView* window,
                const std::u16string& text) override;

  // |KeyboardHandlerBase|
  void ComposeBeginHook() override;

  // |KeyboardHandlerBase|
  void ComposeEndHook() override;

  // |KeyboardHandlerBase|
  void ComposeChangeHook(const std::u16string& text, int cursor_pos) override;

 protected:
  size_t RedispatchedCount();

 private:
  struct PendingEvent {
    uint32_t key;
    uint8_t scancode;
    uint32_t action;
    char32_t character;
    bool extended;
    bool was_down;

    // Self-incrementing ID attached to an event sent to the framework.
    uint64_t sequence_id;
    // The number of delegates that haven't replied.
    size_t unreplied;
    // Whether any replied delegates reported true (handled).
    bool any_handled;

    // A value calculated out of critical event information that can be used
    // to identify redispatched events.
    uint64_t hash;
  };

  // Find an event in the redispatch list that matches the given one.
  //
  // If an matching event is found, removes the matching event from the
  // redispatch list, and returns true. Otherwise, returns false;
  bool RemoveRedispatchedEvent(const PendingEvent& incoming);
  void RedispatchEvent(std::unique_ptr<PendingEvent> event);
  void ResolvePendingEvent(uint64_t sequence_id, bool handled);

  std::vector<std::unique_ptr<KeyboardKeyHandlerDelegate>> delegates_;

  // The queue of key events that have been sent to the framework but have not
  // yet received a response.
  std::deque<std::unique_ptr<PendingEvent>> pending_responds_;

  // The queue of key events that have been redispatched to the system but have
  // not yet been received for a second time.
  std::deque<std::unique_ptr<PendingEvent>> pending_redispatches_;

  // The sequence_id attached to the last event sent to the framework.
  uint64_t last_sequence_id_;

  // The callback used to redispatch synthesized events.
  EventRedispatcher redispatch_event_;

  // Calculate a hash based on event data for fast comparison for a redispatched
  // event.
  //
  // This uses event data instead of generating a serial number because
  // information can't be attached to the redispatched events, so it has to be
  // possible to compute an ID from the identifying data in the event when it is
  // received again in order to differentiate between events that are new, and
  // events that have been redispatched.
  //
  // Another alternative would be to compute a checksum from all the data in the
  // event (just compute it over the bytes in the struct, probably skipping
  // timestamps), but the fields used are enough to differentiate them, and
  // since Windows does some processing on the events (coming up with virtual key
  // codes, setting timestamps, etc.), it's not clear that the redispatched
  // events would have the same checksums.
  static uint64_t ComputeEventHash(const PendingEvent& event);
};

}  // namespace flutter

#endif  // FLUTTER_SHELL_PLATFORM_WINDOWS_KEYBOARD_KEY_HANDLER_H_
