// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_VULKAN_VULKAN_HANDLE_H_
#define FLUTTER_VULKAN_VULKAN_HANDLE_H_

#include <functional>

#include "lib/ftl/macros.h"
#include "vulkan_interface.h"
#include "lib/ftl/logging.h"

namespace vulkan {

template <class T>
class VulkanHandle {
 public:
  using Handle = T;
  using Disposer = std::function<void(Handle)>;

  VulkanHandle() : handle_(VK_NULL_HANDLE) {}

  VulkanHandle(Handle handle, Disposer disposer)
      : handle_(handle), disposer_(disposer) {}

  VulkanHandle(VulkanHandle&& other)
      : handle_(other.handle_), disposer_(other.disposer_) {
    other.handle_ = VK_NULL_HANDLE;
    other.disposer_ = nullptr;
  }

  ~VulkanHandle() { DisposeIfNecessary(); }

  VulkanHandle& operator=(VulkanHandle&& other) {
    if (handle_ != other.handle_) {
      DisposeIfNecessary();
    }

    handle_ = other.handle_;
    disposer_ = other.disposer_;

    other.handle_ = VK_NULL_HANDLE;
    other.disposer_ = nullptr;

    return *this;
  }

  operator bool() const { return handle_ != VK_NULL_HANDLE; }

  operator Handle() const { return handle_; }

 private:
  Handle handle_;
  Disposer disposer_;

  void DisposeIfNecessary() {
    if (handle_ == VK_NULL_HANDLE) {
      return;
    }
    disposer_(handle_);
    handle_ = VK_NULL_HANDLE;
    disposer_ = nullptr;
  }

  FTL_DISALLOW_COPY_AND_ASSIGN(VulkanHandle);
};

}  // namespace vulkan

#endif  // FLUTTER_VULKAN_VULKAN_HANDLE_H_
