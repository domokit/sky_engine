// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_VULKAN_VULKAN_APPLICATION_H_
#define FLUTTER_VULKAN_VULKAN_APPLICATION_H_

#include <memory>
#include <string>
#include <vector>
#include "flutter/vulkan/vulkan_handle.h"
#include "lib/ftl/macros.h"

namespace vulkan {

class VulkanDevice;
class VulkanProcTable;

class VulkanApplication {
 public:
  VulkanApplication(const VulkanProcTable& vk,
                    const std::string& application_name,
                    const std::vector<std::string>& enabled_extensions,
                    uint32_t application_version = VK_MAKE_VERSION(1, 0, 0),
                    uint32_t api_version = VK_MAKE_VERSION(1, 0, 0));

  ~VulkanApplication();

  bool IsValid() const;

  uint32_t APIVersion() const;

  const VulkanHandle<VkInstance>& Instance();

  std::unique_ptr<VulkanDevice> AcquireCompatibleLogicalDevice() const;

 private:
  const VulkanProcTable& vk;
  VulkanHandle<VkInstance> instance_;
  uint32_t api_version_;
  bool valid_;

  std::vector<VkPhysicalDevice> GetPhysicalDevices() const;

  FTL_DISALLOW_COPY_AND_ASSIGN(VulkanApplication);
};

}  // namespace vulkan

#endif  // FLUTTER_VULKAN_VULKAN_APPLICATION_H_
