// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#pragma once

#include "flutter/shell/platform/windows/flutter_window.h"

#include "flutter/fml/macros.h"

namespace flutter {
namespace testing {

/// Test class for FlutterWindow.
class FlutterWindowTest : public FlutterWindow {
 public:
  FlutterWindowTest(int width, int height);
  virtual ~FlutterWindowTest();

 private:
  FML_DISALLOW_COPY_AND_ASSIGN(FlutterWindowTest);
};

}  // namespace testing
}  // namespace flutter
