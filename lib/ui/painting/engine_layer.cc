// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "flutter/lib/ui/painting/engine_layer.h"

#include "flutter/flow/layers/container_layer.h"

#include "third_party/tonic/converter/dart_converter.h"
#include "third_party/tonic/dart_args.h"
#include "third_party/tonic/dart_binding_macros.h"
#include "third_party/tonic/dart_library_natives.h"

using tonic::ToDart;

namespace blink {

EngineLayer::~EngineLayer() = default;

IMPLEMENT_WRAPPERTYPEINFO(ui, EngineLayer);

#define FOR_EACH_BINDING(V) // nothing to bind

DART_BIND_ALL(EngineLayer, FOR_EACH_BINDING)

}  // namespace blink
