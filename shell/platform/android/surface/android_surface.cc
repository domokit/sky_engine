// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "flutter/shell/platform/android/surface/android_surface.h"

namespace flutter {

AndroidSurface::AndroidSurface(
    const std::shared_ptr<AndroidContext>& android_context) {
  android_context_ = android_context;
}

AndroidSurface::~AndroidSurface() = default;

}  // namespace flutter
