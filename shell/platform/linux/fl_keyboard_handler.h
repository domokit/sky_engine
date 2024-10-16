// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_SHELL_PLATFORM_LINUX_FL_KEYBOARD_HANDLER_H_
#define FLUTTER_SHELL_PLATFORM_LINUX_FL_KEYBOARD_HANDLER_H_

#include <gdk/gdk.h>

#include "flutter/shell/platform/linux/fl_keyboard_view_delegate.h"
#include "flutter/shell/platform/linux/public/flutter_linux/fl_binary_messenger.h"

G_BEGIN_DECLS

#define FL_TYPE_KEYBOARD_HANDLER fl_keyboard_handler_get_type()
G_DECLARE_FINAL_TYPE(FlKeyboardHandler,
                     fl_keyboard_handler,
                     FL,
                     KEYBOARD_HANDLER,
                     GObject);

/**
 * FlKeyboardHandler:
 *
 * Provides the channel to receive keyboard requests from the Dart code.
 */

/**
 * fl_keyboard_handler_new:
 * @view_delegate: An interface that the handler requires to communicate with
 * the platform. Usually implemented by FlView.
 *
 * Create a new #FlKeyboardHandler.
 *
 * Returns: a new #FlKeyboardHandler.
 */
FlKeyboardHandler* fl_keyboard_handler_new(
    FlBinaryMessenger* messenger,
    FlKeyboardViewDelegate* view_delegate);

G_END_DECLS

#endif  // FLUTTER_SHELL_PLATFORM_LINUX_FL_KEYBOARD_HANDLER_H_
