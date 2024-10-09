// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "impeller/toolkit/interop/texture.h"

namespace impeller::interop {

Texture::Texture(const Context& context, const TextureDescriptor& descriptor) {
  if (!context.IsValid()) {
    return;
  }
  auto texture =
      context.GetContext()->GetResourceAllocator()->CreateTexture(descriptor);
  if (!texture || !texture->IsValid()) {
    return;
  }
  texture_ = std::move(texture);
}

Texture::Texture(std::shared_ptr<impeller::Texture> texture)
    : texture_(std::move(texture)) {}

Texture::~Texture() = default;

bool Texture::IsValid() const {
  return !!texture_;
}

bool Texture::SetContents(const uint8_t* contents, uint64_t length) {
  if (!IsValid()) {
    return false;
  }
  return texture_->SetContents(contents, length);
}

bool Texture::SetContents(std::shared_ptr<const fml::Mapping> contents) {
  if (!IsValid()) {
    return false;
  }
  return texture_->SetContents(std::move(contents));
}

sk_sp<DlImageImpeller> Texture::MakeImage() const {
  return DlImageImpeller::Make(texture_);
}

}  // namespace impeller::interop
