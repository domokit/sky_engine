// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "flutter/shell/platform/android/image_lru.h"

namespace flutter {

sk_sp<flutter::DlImage> ImageLRU::FindImage(uint64_t key) {
  for (size_t i = 0u; i < kImageReaderSwapchainSize; i++) {
    if (images_[i].key == key) {
      auto result = images_[i].value;
      UpdateKey(result, key);
      return result;
    }
  }
  return nullptr;
}

void ImageLRU::UpdateKey(const sk_sp<flutter::DlImage>& image, uint64_t key) {
  if (images_[0].key == key) {
    return;
  }
  size_t i = 1u;
  for (; i < kImageReaderSwapchainSize; i++) {
    if (images_[i].key == key) {
      break;
    }
  }
  for (auto j = i; j > 0; j--) {
    images_[j] = images_[j - 1];
  }
  images_[0] = Data{.key = key, .value = image};
}

uint64_t ImageLRU::AddImage(const sk_sp<flutter::DlImage>& image,
                            uint64_t key) {
  uint64_t lru_key = images_[kImageReaderSwapchainSize - 1].key;
  bool updated_image = false;
  for (size_t i = 0u; i < kImageReaderSwapchainSize; i++) {
    if (images_[i].key == lru_key) {
      updated_image = true;
      images_[i] = Data{.key = key, .value = image};
      break;
    }
  }
  if (!updated_image) {
    images_[0] = Data{.key = key, .value = image};
  }
  UpdateKey(image, key);
  return lru_key;
}

void ImageLRU::Clear() {
  for (size_t i = 0u; i < kImageReaderSwapchainSize; i++) {
    images_[i] = Data{.key = 0u, .value = nullptr};
  }
}

}  // namespace flutter
