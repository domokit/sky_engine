// Copyright 2015 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "flutter/lib/ui/painting/shader.h"

#include "flutter/lib/ui/ui_dart_state.h"

namespace blink {

IMPLEMENT_WRAPPERTYPEINFO(ui, Shader);

Shader::Shader(flow::SkiaGPUObject<SkShader> shader)
    : shader_(std::move(shader)) {}

Shader::~Shader() = default;

}  // namespace blink
