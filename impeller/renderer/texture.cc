// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "impeller/renderer/texture.h"

#include "impeller/base/validation.h"

namespace impeller {

Texture::Texture(TextureDescriptor desc) : desc_(std::move(desc)) {}

Texture::~Texture() = default;

bool Texture::SetContents(const uint8_t* contents,
                          size_t length,
                          size_t slice) {
  if (!IsSliceValid(slice)) {
    VALIDATION_LOG << "Invalid slice for texture.";
    return false;
  }
  return OnSetContents(contents, length, slice);
}

bool Texture::SetContents(std::shared_ptr<const fml::Mapping> mapping,
                          size_t slice) {
  if (!IsSliceValid(slice)) {
    VALIDATION_LOG << "Invalid slice for texture.";
    return false;
  }

  if (!mapping) {
    return false;
  }

  return OnSetContents(std::move(mapping), slice);
}

const TextureDescriptor& Texture::GetTextureDescriptor() const {
  return desc_;
}

bool Texture::IsSliceValid(size_t slice) const {
  switch (desc_.type) {
    case TextureType::kTexture2D:
    case TextureType::kTexture2DMultisample:
      return slice == 0;
    case TextureType::kTextureCube:
      return slice <= 5;
  }
  FML_UNREACHABLE();
}

}  // namespace impeller
