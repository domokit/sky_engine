// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_SHELL_PLATFORM_CPP_GLFW_TEXT_INPUT_PLUGIN_H_
#define FLUTTER_SHELL_PLATFORM_CPP_GLFW_TEXT_INPUT_PLUGIN_H_

#include <map>
#include <memory>

#include "flutter/shell/platform/cpp/client_wrapper/include/flutter/binary_messenger.h"
#include "flutter/shell/platform/cpp/client_wrapper/include/flutter/method_channel.h"
#include "flutter/shell/platform/cpp/glfw/keyboard_hook_handler.h"
#include "flutter/shell/platform/cpp/text_input_model.h"

namespace shell {

// Implements a text input plugin.
//
// Specifically handles window events within GLFW.
class TextInputPlugin : public KeyboardHookHandler {
 public:
  explicit TextInputPlugin(flutter::BinaryMessenger* messenger);
  virtual ~TextInputPlugin();

  // KeyboardHookHandler:
  void KeyboardHook(GLFWwindow* window,
                    int key,
                    int scancode,
                    int action,
                    int mods) override;
  void CharHook(GLFWwindow* window, unsigned int code_point) override;

 private:
  // Sends the current state of the given model to the Flutter engine.
  void SendStateUpdate(const TextInputModel& model);

  // Sends an action triggered by the Enter key to the Flutter engine.
  void EnterPressed(TextInputModel* model);

  // Called when a method is called on |channel_|;
  void HandleMethodCall(
      const flutter::MethodCall<Json::Value>& method_call,
      std::unique_ptr<flutter::MethodResult<Json::Value>> result);

  // The MethodChannel used for communication with the Flutter engine.
  std::unique_ptr<flutter::MethodChannel<Json::Value>> channel_;

  // Mapping of client IDs to text input models.
  std::map<int, std::unique_ptr<TextInputModel>> input_models_;

  // The active model. nullptr if not set.
  TextInputModel* active_model_;
};

}  // namespace shell

#endif  // FLUTTER_SHELL_PLATFORM_CPP_GLFW_TEXT_INPUT_PLUGIN_H_
