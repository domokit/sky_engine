// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "flutter/shell/common/display.h"

#include "flutter/fml/logging.h"

namespace flutter {
double Display::GetRefreshRate() const {
  return refresh_rate_;
}
}  // namespace flutter
