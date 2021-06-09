// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

in vec3 color;
in vec3 color2;

layout(location = 0) out vec4 fragColor;

void main() {
  fragColor = vec4(color * color2, 1.0);
}
