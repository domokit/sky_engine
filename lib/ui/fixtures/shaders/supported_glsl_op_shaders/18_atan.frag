#version 320 es

// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

precision highp float;

layout(location = 0) out vec4 fragColor;

layout(location = 0) uniform float a;

void main() {
  fragColor = vec4(
      // tan(0.0) = 0.0
      atan(0.0),
      // tan(1.0) = 1.55740772465
      atan(a * 1.55740772465), 0.0, 1.0);
}
