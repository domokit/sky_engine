// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "impeller/renderer/allocator.h"

#include "impeller/base/validation.h"
#include "impeller/renderer/device_buffer.h"
#include "impeller/renderer/range.h"

namespace impeller {

Allocator::Allocator() = default;

Allocator::~Allocator() = default;

std::shared_ptr<DeviceBuffer> Allocator::CreateBufferWithCopy(
    const uint8_t* buffer,
    size_t length) {
  DeviceBufferDescriptor desc;
  desc.size = length;
  desc.storage_mode = StorageMode::kHostVisible;
  auto new_buffer = CreateBuffer(desc);

  if (!new_buffer) {
    return nullptr;
  }

  auto entire_range = Range{0, length};

  if (!new_buffer->CopyHostBuffer(buffer, entire_range)) {
    return nullptr;
  }

  return new_buffer;
}

std::shared_ptr<DeviceBuffer> Allocator::CreateBufferWithCopy(
    const fml::Mapping& mapping) {
  return CreateBufferWithCopy(mapping.GetMapping(), mapping.GetSize());
}

std::shared_ptr<DeviceBuffer> Allocator::CreateBuffer(
    const DeviceBufferDescriptor& desc) {
  return OnCreateBuffer(desc);
}

#if (FLUTTER_RUNTIME_MODE != FLUTTER_RUNTIME_MODE_RELEASE)
const std::vector<ISize>& Allocator::GetAllocatedSizes() const {
  return allocated_sizes_;
}

void Allocator::ResetAllocatedSizes() {
  allocated_sizes_.clear();
}

void Allocator::SetTrackAllocations(bool value) {
  track_allocation_ = value;
  if (!track_allocation_) {
    ResetAllocatedSizes();
  }
}
#endif

std::shared_ptr<Texture> Allocator::CreateTexture(
    const TextureDescriptor& desc) {
  const auto max_size = GetMaxTextureSizeSupported();
  if (desc.size.width > max_size.width || desc.size.height > max_size.height) {
    VALIDATION_LOG
        << "Requested texture size exceeds maximum supported size of "
        << desc.size;
    return nullptr;
  }
#if (FLUTTER_RUNTIME_MODE != FLUTTER_RUNTIME_MODE_RELEASE)
  if (track_allocation_) {
    allocated_sizes_.push_back(desc.size);
  }
#endif

  return OnCreateTexture(desc);
}

uint16_t Allocator::MinimumBytesPerRow(PixelFormat format) const {
  return BytesPerPixelForPixelFormat(format);
}

}  // namespace impeller
