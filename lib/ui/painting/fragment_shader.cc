// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <iostream>

#include "flutter/lib/ui/painting/fragment_shader.h"

#include "flutter/lib/ui/dart_wrapper.h"
#include "flutter/lib/ui/ui_dart_state.h"
#include "third_party/skia/include/core/SkString.h"
#include "third_party/tonic/converter/dart_converter.h"
#include "third_party/tonic/dart_args.h"
#include "third_party/tonic/dart_binding_macros.h"
#include "third_party/tonic/dart_library_natives.h"
#include "third_party/tonic/typed_data/typed_list.h"

using tonic::ToDart;

namespace flutter {

static void FragmentShader_constructor(Dart_NativeArguments args) {
  DartCallConstructor(&FragmentShader::Create, args);
}

IMPLEMENT_WRAPPERTYPEINFO(ui, FragmentShader);

#define FOR_EACH_BINDING(V) \
  V(FragmentShader, init)   \
  V(FragmentShader, update)

FOR_EACH_BINDING(DART_NATIVE_CALLBACK)

void FragmentShader::RegisterNatives(tonic::DartLibraryNatives* natives) {
  natives->Register(
      {{"FragmentShader_constructor", FragmentShader_constructor, 1, true},
       FOR_EACH_BINDING(DART_REGISTER_NATIVE)});
}

sk_sp<SkShader> FragmentShader::shader(SkSamplingOptions sampling) {
  // TODO(antrob): Use sampling?
  // https://github.com/flutter/flutter/issues/88303
  return shader_;
}

void FragmentShader::init(std::string sksl, bool debugPrintSksl) {
  SkRuntimeEffect::Result result =
      SkRuntimeEffect::MakeForShader(SkString(sksl));
  runtime_effect_ = result.effect;

  if (runtime_effect_ == nullptr) {
    Dart_ThrowException(tonic::ToDart(
        std::string("Invalid SkSL:\n") + sksl.c_str() +
        std::string("\nSkSL Error:\n") + result.errorText.c_str()));
    return;
  }
  if (debugPrintSksl) {
    std::cout << std::string("debugPrintSksl:\n") + sksl.c_str() << std::endl;
  }
}

void FragmentShader::update(const tonic::Float32List& uniforms,
                            Dart_Handle children) {
  std::vector<Shader*> shaders =
      tonic::DartConverter<std::vector<Shader*>>::FromDart(children);
  std::vector<sk_sp<SkShader>> sk_children(shaders.size());
  for (size_t i = 0; i < shaders.size(); i++) {
    // The default value for SkSamplingOptions is used because ImageShader
    // uses a cached value set by the user, it is ignored by Gradient,
    // and because it is not necessary for FragmentShader (shaders should
    // implement their own optimal filtering).
    sk_children[i] = shaders[i]->shader(SkSamplingOptions());
  }
  shader_ = runtime_effect_->makeShader(
      SkData::MakeWithCopy(uniforms.data(),
                           uniforms.num_elements() * sizeof(float)),
      sk_children.data(), sk_children.size(), nullptr, false);
}

fml::RefPtr<FragmentShader> FragmentShader::Create() {
  return fml::MakeRefCounted<FragmentShader>();
}

FragmentShader::FragmentShader() = default;

FragmentShader::~FragmentShader() = default;

}  // namespace flutter
