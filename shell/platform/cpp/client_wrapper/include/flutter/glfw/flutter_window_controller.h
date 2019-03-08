// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_SHELL_PLATFORM_CPP_CLIENT_WRAPPER_INCLUDE_FLUTTER_GLFW_FLUTTER_WINDOW_CONTROLLER_H_
#define FLUTTER_SHELL_PLATFORM_CPP_CLIENT_WRAPPER_INCLUDE_FLUTTER_GLFW_FLUTTER_WINDOW_CONTROLLER_H_

#include <string>
#include <vector>

#ifdef FLUTTER_DESKTOP_LIBRARY
#include "flutter/shell/platform/cpp/public/flutter_glfw.h"
#else
#include <flutter_glfw.h>
#endif

#ifdef FLUTTER_DESKTOP_LIBRARY
#include "../plugin_registrar.h"
#else
#include "plugin_registrar.h"
#endif

namespace flutter {

// A controller for a window displaying Flutter content.
//
// This is the primary wrapper class for the desktop embedding C API.
// If you use this class, you should not call any of the setup or teardown
// methods in embedder.h directly, as this class will do that internally.
//
// Note: This is an early implementation (using GLFW internally) which
// requires control of the application's event loop, and is thus useful
// primarily for building a simple one-window shell hosting a Flutter
// application. The final implementation and API will be very different.
class FlutterWindowController {
 public:
  // There must be only one instance of this class in an application at any
  // given time, as Flutter does not support multiple engines in one process,
  // or multiple views in one engine.
  explicit FlutterWindowController(std::string& icu_data_path);

  ~FlutterWindowController();

  // Creates and displays a window for displaying Flutter content.
  //
  // The |assets_path| is the path to the flutter_assets folder for the Flutter
  // application to be run. |icu_data_path| is the path to the icudtl.dat file
  // for the version of Flutter you are using.
  //
  // The |arguments| are passed to the Flutter engine. See:
  // https://github.com/flutter/engine/blob/master/shell/common/switches.h for
  // for details. Not all arguments will apply to embedding mode.
  //
  // Only one Flutter window can exist at a time; see constructor comment.
  bool CreateWindow(int width,
                    int height,
                    const std::string& assets_path,
                    const std::vector<std::string>& arguments);

  // Returns the FlutterEmbedderPluginRegistrarRef to register a plugin with the
  // given name.
  //
  // The name must be unique across the application.
  FlutterEmbedderPluginRegistrarRef GetRegistrarForPlugin(
      const std::string& plugin_name);

  // Enables or disables hover tracking.
  //
  // If hover is enabled, mouse movement will send hover events to the Flutter
  // engine, rather than only tracking the mouse while the button is pressed.
  // Defaults to off.
  void SetHoverEnabled(bool enabled);

  // Loops on Flutter window events until the window closes.
  void RunEventLoop();

 private:
  // The path to the ICU data file. Set at creation time since it is the same
  // for any window created.
  std::string icu_data_path_;

  // Whether or not FlutterEmbedderInit succeeded at creation time.
  bool init_succeeded_ = false;

  // The curent Flutter window, if any.
  FlutterWindowRef window_ = nullptr;
};

}  // namespace flutter

#endif  // FLUTTER_SHELL_PLATFORM_CPP_CLIENT_WRAPPER_INCLUDE_FLUTTER_GLFW_FLUTTER_WINDOW_CONTROLLER_H_
