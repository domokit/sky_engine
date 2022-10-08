// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <Carbon/Carbon.h>
#import <Foundation/Foundation.h>
#import <OCMock/OCMock.h>

#import "flutter/shell/platform/darwin/macos/framework/Source/FlutterEngine_Internal.h"
#import "flutter/shell/platform/darwin/macos/framework/Source/FlutterViewController_Internal.h"
#import "flutter/shell/platform/darwin/macos/framework/Source/FlutterViewProvider.h"
#import "flutter/testing/testing.h"
#include "third_party/googletest/googletest/include/gtest/gtest.h"

#import "flutter/testing/testing.h"
#include "third_party/googletest/googletest/include/gtest/gtest.h"

namespace flutter::testing {

TEST(FlutterViewProviderUnittests, GetViewReturnsTheCorrectView) {
  FlutterViewProvider* viewProvider;
  id mockEngine = OCMClassMock([FlutterEngine class]);
  __block id mockFlutterViewController;
  OCMStub([mockEngine viewController]).andDo(^(NSInvocation *invocation) {
    if (mockFlutterViewController != nil) {
      [invocation setReturnValue:&mockFlutterViewController];
    }
  });
  viewProvider = [[FlutterViewProvider alloc] initWithEngine:mockEngine];

  // When the view controller is not set, the returned view is nil.
  EXPECT_EQ([viewProvider getView:0], nil);

  // When the view controller is set, the returned view is the controller's view.
  mockFlutterViewController = OCMStrictClassMock([FlutterViewController class]);
  id mockView = OCMStrictClassMock([FlutterView class]);
  OCMStub([mockFlutterViewController flutterView]).andReturn(mockView);
  EXPECT_EQ([viewProvider getView:0], mockView);
}

}  // namespace flutter::testing
