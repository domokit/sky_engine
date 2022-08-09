// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

precision mediump float;

#include <impeller/blending.glsl>

vec3 Blend(vec3 dst, vec3 src) {
  return IPBlendHardLight(dst, src);
}

#include "advanced_blend.glsl"
