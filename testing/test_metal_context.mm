// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "flutter/testing/test_metal_context.h"

#include <Metal/Metal.h>
#include <iostream>

#include "flutter/fml/logging.h"
#include "flutter/fml/platform/darwin/scoped_nsobject.h"
#include "third_party/skia/include/core/SkSurface.h"
#include "third_party/skia/include/gpu/ganesh/GrDirectContext.h"
#include "third_party/skia/include/gpu/ganesh/mtl/GrMtlBackendContext.h"
#include "third_party/skia/include/gpu/ganesh/mtl/GrMtlDirectContext.h"

static_assert(__has_feature(objc_arc), "ARC must be enabled.");

namespace flutter {

TestMetalContext::TestMetalContext() {
  id<MTLDevice> device = MTLCreateSystemDefaultDevice();
  if (!device) {
    FML_LOG(ERROR) << "Could not acquire Metal device.";
    return;
  }

  id<MTLCommandQueue> command_queue = [device newCommandQueue];
  if (!command_queue) {
    FML_LOG(ERROR) << "Could not create the default command queue.";
    return;
  }

  [command_queue setLabel:@"Flutter Test Queue"];

  GrMtlBackendContext backendContext = {};
  // Skia expect arguments to `MakeMetal` transfer ownership of the reference in for release later
  // when the GrDirectContext is collected.
  backendContext.fDevice.retain((__bridge GrMTLHandle)device);
  backendContext.fQueue.retain((__bridge GrMTLHandle)command_queue);
  skia_context_ = GrDirectContexts::MakeMetal(backendContext);
  if (!skia_context_) {
    FML_LOG(ERROR) << "Could not create the GrDirectContext from the Metal Device "
                      "and command queue.";
  }

  // Retain and transfer to non-ARC-managed pointers.
  device_ = (__bridge_retained void*)device;
  command_queue_ = (__bridge_retained void*)command_queue;
}

TestMetalContext::~TestMetalContext() {
  std::scoped_lock lock(textures_mutex_);
  textures_.clear();
  if (device_) {
    // Release and transfer to ARC-managed pointer.
    id<MTLDevice> device =  // NOLINT(clang-analyzer-deadcode.DeadStores)
        (__bridge_transfer id<MTLDevice>)device_;
    device = nil;
  }
  if (command_queue_) {
    // Release and transfer to ARC-managed pointer.
    id<MTLCommandQueue> command_queue =  // NOLINT(clang-analyzer-deadcode.DeadStores)
        (__bridge_transfer id<MTLCommandQueue>)command_queue_;
    command_queue = nil;
  }
}

void* TestMetalContext::GetMetalDevice() const {
  return device_;
}

void* TestMetalContext::GetMetalCommandQueue() const {
  return command_queue_;
}

sk_sp<GrDirectContext> TestMetalContext::GetSkiaContext() const {
  return skia_context_;
}

TestMetalContext::TextureInfo TestMetalContext::CreateMetalTexture(const SkISize& size) {
  std::scoped_lock lock(textures_mutex_);
  MTLTextureDescriptor* texture_descriptor =
      [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
                                                         width:size.width()
                                                        height:size.height()
                                                     mipmapped:NO];

  // The most pessimistic option and disables all optimizations but allows tests
  // the most flexible access to the surface. They may read and write to the
  // surface from shaders or use as a pixel view.
  texture_descriptor.usage = MTLTextureUsageUnknown;

  if (!texture_descriptor) {
    FML_CHECK(false) << "Invalid texture descriptor.";
    return {.texture_id = -1, .texture = nullptr};
  }

  id<MTLDevice> device = (__bridge id<MTLDevice>)GetMetalDevice();
  id<MTLTexture> texture = [device newTextureWithDescriptor:texture_descriptor];
  if (!texture) {
    FML_CHECK(false) << "Could not create texture from texture descriptor.";
    return {.texture_id = -1, .texture = nullptr};
  }

  const int64_t texture_id = texture_id_ctr_++;
  sk_cfp<void*> texture_ptr;
  texture_ptr.reset((__bridge_retained void*)texture);
  textures_[texture_id] = texture_ptr;

  return {
      .texture_id = texture_id,
      .texture = (__bridge void*)texture,
  };
}

// Don't remove the texture from the map here.
bool TestMetalContext::Present(int64_t texture_id) {
  std::scoped_lock lock(textures_mutex_);
  if (textures_.find(texture_id) == textures_.end()) {
    return false;
  } else {
    return true;
  }
}

TestMetalContext::TextureInfo TestMetalContext::GetTextureInfo(int64_t texture_id) {
  std::scoped_lock lock(textures_mutex_);
  if (textures_.find(texture_id) == textures_.end()) {
    FML_CHECK(false) << "Invalid texture id: " << texture_id;
    return {.texture_id = -1, .texture = nullptr};
  } else {
    return {
        .texture_id = texture_id,
        .texture = textures_[texture_id].get(),
    };
  }
}

}  // namespace flutter
