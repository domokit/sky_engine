// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

uniform vec4 u_color;
// sampler is specifically ordered after color.
uniform sampler2D u_texture;

out vec4 frag_color;

void main() {
  frag_color = u_color + texture(u_texture, vec2(0.5, 0.5));
}
