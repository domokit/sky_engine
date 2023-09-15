// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#pragma once

#include <functional>
#include <memory>
#include <string>
#include <vector>

#include "impeller/base/thread.h"
#include "impeller/renderer/backend/vulkan/context_vk.h"
#include "vulkan/vulkan_enums.hpp"

namespace impeller {
namespace testing {

std::shared_ptr<std::vector<std::string>> GetMockVulkanFunctions(
    VkDevice device);

// A test-controlled version of |vk::Fence|.
class MockFence final {
 public:
  MockFence() = default;

  // Returns the result that was set in the constructor or |SetStatus|.
  VkResult GetStatus() {
    Lock lock(result_mutex_);
    return static_cast<VkResult>(result_);
  }

  // Sets the result that will be returned by `GetFenceStatus`.
  void SetStatus(vk::Result result) { result_ = result; }

  // Sets the result that will be returned by `GetFenceStatus`.
  static void SetStatus(vk::UniqueFence& fence, vk::Result result) {
    // Cast the fence to a MockFence and set the result.
    VkFence raw_fence = fence.get();
    MockFence* mock_fence = reinterpret_cast<MockFence*>(raw_fence);
    mock_fence->SetStatus(result);
  }

  // Gets a raw pointer to manipulate the fence after it's been moved.
  static MockFence* GetRawPointer(vk::UniqueFence& fence) {
    // Cast the fence to a MockFence and get the result.
    VkFence raw_fence = fence.get();
    MockFence* mock_fence = reinterpret_cast<MockFence*>(raw_fence);
    return mock_fence;
  }

 private:
  vk::Result result_ = vk::Result::eSuccess;
  Mutex result_mutex_;

  FML_DISALLOW_COPY_AND_ASSIGN(MockFence);
};

class MockVulkanContextBuilder {
 public:
  MockVulkanContextBuilder();

  //------------------------------------------------------------------------------
  /// @brief      Create a Vulkan context with Vulkan functions mocked. The
  ///             caller is given a chance to tinker on the settings right
  ///             before a context is created.
  ///
  /// @return     A context if one can be created.
  ///
  std::shared_ptr<ContextVK> Build();

  /// A callback that allows the modification of the ContextVK::Settings before
  /// the context is made.
  MockVulkanContextBuilder& SetSettingsCallback(
      const std::function<void(ContextVK::Settings&)>& settings_callback) {
    settings_callback_ = settings_callback;
    return *this;
  }

  MockVulkanContextBuilder& SetInstanceExtensions(
      const std::vector<std::string>& instance_extensions) {
    instance_extensions_ = instance_extensions;
    return *this;
  }

  MockVulkanContextBuilder& SetInstanceLayers(
      const std::vector<std::string>& instance_layers) {
    instance_layers_ = instance_layers;
    return *this;
  }

 private:
  std::function<void(ContextVK::Settings&)> settings_callback_;
  std::vector<std::string> instance_extensions_;
  std::vector<std::string> instance_layers_;
};

}  // namespace testing
}  // namespace impeller
