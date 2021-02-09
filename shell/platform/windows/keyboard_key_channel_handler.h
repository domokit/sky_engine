// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_SHELL_PLATFORM_WINDOWS_KEYBOARD_KEY_CHANNEL_HANDLER_H_
#define FLUTTER_SHELL_PLATFORM_WINDOWS_KEYBOARD_KEY_CHANNEL_HANDLER_H_

#include <deque>
#include <memory>
#include <string>

#include "flutter/shell/platform/common/client_wrapper/include/flutter/basic_message_channel.h"
#include "flutter/shell/platform/common/client_wrapper/include/flutter/binary_messenger.h"
#include "flutter/shell/platform/windows/keyboard_key_handler.h"
#include "rapidjson/document.h"

namespace flutter {

// Handled
class KeyboardKeyChannelHandler
    : public KeyboardKeyHandler::KeyboardKeyHandlerDelegate {
 public:
  explicit KeyboardKeyChannelHandler(flutter::BinaryMessenger* messenger);

  ~KeyboardKeyChannelHandler();

  // |KeyboardKeyHandler::KeyboardKeyHandlerDelegate|
  bool KeyboardHook(int key,
                    int scancode,
                    int action,
                    char32_t character,
                    bool extended,
                    bool was_down,
                    std::function<void(bool)> callback);

 private:
  // The Flutter system channel for key event messages.
  std::unique_ptr<flutter::BasicMessageChannel<rapidjson::Document>> channel_;
};

}  // namespace flutter

#endif  // FLUTTER_SHELL_PLATFORM_WINDOWS_KEYBOARD_KEY_CHANNEL_HANDLER_H_
