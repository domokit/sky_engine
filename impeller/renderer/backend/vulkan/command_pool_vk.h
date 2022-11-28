// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#pragma once

#include <mutex>

#include "flutter/fml/macros.h"
#include "impeller/renderer/backend/vulkan/vk.h"

namespace impeller {

class CommandPoolVK {
 public:
  static std::shared_ptr<CommandPoolVK> Create(vk::Device device,
                                               uint32_t queue_index);

  CommandPoolVK(vk::Device device, vk::UniqueCommandPool command_pool);

  ~CommandPoolVK();

  vk::CommandBuffer CreateCommandBuffer();

  void FreeCommandBuffers(const std::vector<vk::CommandBuffer>& buffers);

 private:
  vk::Device device_;
  std::mutex pool_mutex_;
  vk::UniqueCommandPool command_pool_;

  FML_DISALLOW_COPY_AND_ASSIGN(CommandPoolVK);
};

}  // namespace impeller
