// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_SHELL_PLATFORM_DARWIN_IOS_FRAMEWORK_SOURCE_FLUTTER_EMBEDDER_KEY_RESPONDER_H_
#define FLUTTER_SHELL_PLATFORM_DARWIN_IOS_FRAMEWORK_SOURCE_FLUTTER_EMBEDDER_KEY_RESPONDER_H_

#import <Foundation/NSObject.h>
#import <UIKit/UIKit.h>

// NOLINTBEGIN(google-build-namespaces)
#include "fml/memory/weak_ptr.h"

#import "flutter/shell/platform/darwin/ios/framework/Headers/FlutterViewController.h"
#import "flutter/shell/platform/darwin/ios/framework/Source/FlutterKeyPrimaryResponder.h"
#import "flutter/shell/platform/embedder/embedder.h"

// For whatever reason, NOLINTNEXTLINE is not working here.
namespace {
typedef void* _VoidPtr;
}
// NOLINTEND(google-build-namespaces)

typedef void (^FlutterSendKeyEvent)(const FlutterKeyEvent& /* event */,
                                    _Nullable FlutterKeyEventCallback /* callback */,
                                    _Nullable _VoidPtr /* user_data */);

/**
 * A primary responder of |FlutterKeyboardManager| that handles events by
 * sending the converted events through a Dart hook to the framework.
 *
 * This class interfaces with the HardwareKeyboard API in the framework.
 */
@interface FlutterEmbedderKeyResponder : NSObject <FlutterKeyPrimaryResponder>

/**
 * Create an instance by specifying the function to send converted events to.
 *
 * The |sendEvent| is typically |FlutterEngine|'s |sendKeyEvent|.
 */
- (nonnull instancetype)initWithSendEvent:(nonnull FlutterSendKeyEvent)sendEvent;

@end

#endif  // FLUTTER_SHELL_PLATFORM_DARWIN_IOS_FRAMEWORK_SOURCE_FLUTTER_EMBEDDER_KEY_RESPONDER_H_
