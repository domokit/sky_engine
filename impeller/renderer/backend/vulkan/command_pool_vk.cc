// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "impeller/renderer/backend/vulkan/command_pool_vk.h"

#include <memory>
#include <optional>
#include <utility>

#include "impeller/renderer/backend/vulkan/context_vk.h"
#include "impeller/renderer/backend/vulkan/descriptor_pool_vk.h"
#include "impeller/renderer/backend/vulkan/resource_manager_vk.h"

#include "impeller/renderer/backend/vulkan/vk.h"  // IWYU pragma: keep.
#include "vulkan/vulkan_handles.hpp"
#include "vulkan/vulkan_structs.hpp"

namespace impeller {

// Holds the command pool in a background thread, recyling it when not in use.
class BackgroundCommandPoolVK final {
 public:
  BackgroundCommandPoolVK(BackgroundCommandPoolVK&&) = default;

  // The recycler also recycles command buffers that were never used, up to a
  // limit of 16 per frame. This number was somewhat arbitrarily chosen.
  static constexpr size_t kUnusedCommandBufferLimit = 16u;

  explicit BackgroundCommandPoolVK(
      vk::UniqueCommandPool&& pool,
      std::vector<vk::UniqueCommandBuffer>&& buffers,
      size_t unused_count,
      std::weak_ptr<CommandPoolRecyclerVK> recycler)
      : pool_(std::move(pool)),
        buffers_(std::move(buffers)),
        unused_count_(unused_count),
        recycler_(std::move(recycler)) {}

  ~BackgroundCommandPoolVK() {
    auto const recycler = recycler_.lock();

    // Not only does this prevent recycling when the context is being destroyed,
    // but it also prevents the destructor from effectively being called twice;
    // once for the original BackgroundCommandPoolVK() and once for the moved
    // BackgroundCommandPoolVK().
    if (!recycler) {
      return;
    }
    // If there are many unused command buffers, release some of them.
    if (unused_count_ > kUnusedCommandBufferLimit) {
      for (auto i = 0u; i < unused_count_; i++) {
        buffers_.pop_back();
      }
    }

    recycler->Reclaim(std::move(pool_), std::move(buffers_));
  }

 private:
  BackgroundCommandPoolVK(const BackgroundCommandPoolVK&) = delete;

  BackgroundCommandPoolVK& operator=(const BackgroundCommandPoolVK&) = delete;

  vk::UniqueCommandPool pool_;

  // These are retained because the destructor of the C++ UniqueCommandBuffer
  // wrapper type will attempt to reset the cmd buffer, and doing so may be a
  // thread safety violation as this may happen on the fence waiter thread.
  std::vector<vk::UniqueCommandBuffer> buffers_;
  const size_t unused_count_;
  std::weak_ptr<CommandPoolRecyclerVK> recycler_;
};

CommandPoolVK::~CommandPoolVK() {
  if (!pool_) {
    return;
  }

  auto const context = context_.lock();
  if (!context) {
    return;
  }
  auto const recycler = context->GetCommandPoolRecycler();
  if (!recycler) {
    return;
  }
  // Any unused command buffers are added to the set of used command buffers.
  // both will be reset to the initial state when the pool is reset.
  size_t unused_count = unused_command_buffers_.size();
  for (auto i = 0u; i < unused_command_buffers_.size(); i++) {
    collected_buffers_.push_back(std::move(unused_command_buffers_[i]));
  }
  unused_command_buffers_.clear();

  auto reset_pool_when_dropped = BackgroundCommandPoolVK(
      std::move(pool_), std::move(collected_buffers_), unused_count, recycler);

  UniqueResourceVKT<BackgroundCommandPoolVK> pool(
      context->GetResourceManager(), std::move(reset_pool_when_dropped));
}

// TODO(matanlurey): Return a status_or<> instead of {} when we have one.
vk::UniqueCommandBuffer CommandPoolVK::CreateCommandBuffer() {
  auto const context = context_.lock();
  if (!context) {
    return {};
  }

  Lock lock(pool_mutex_);
  if (!pool_) {
    return {};
  }
  if (!unused_command_buffers_.empty()) {
    vk::UniqueCommandBuffer buffer = std::move(unused_command_buffers_.back());
    unused_command_buffers_.pop_back();
    return buffer;
  }

  auto const device = context->GetDevice();
  vk::CommandBufferAllocateInfo info;
  info.setCommandPool(pool_.get());
  info.setCommandBufferCount(1u);
  info.setLevel(vk::CommandBufferLevel::ePrimary);
  auto [result, buffers] = device.allocateCommandBuffersUnique(info);
  if (result != vk::Result::eSuccess) {
    return {};
  }
  return std::move(buffers[0]);
}

void CommandPoolVK::CollectCommandBuffer(vk::UniqueCommandBuffer&& buffer) {
  Lock lock(pool_mutex_);
  if (!pool_) {
    // If the command pool has already been destroyed, then its buffers have
    // already been freed.
    buffer.release();
    return;
  }
  collected_buffers_.push_back(std::move(buffer));
}

void CommandPoolVK::Destroy() {
  Lock lock(pool_mutex_);
  pool_.reset();

  // When the command pool is destroyed, all of its command buffers are freed.
  // Handles allocated from that pool are now invalid and must be discarded.
  for (auto& buffer : collected_buffers_) {
    buffer.release();
  }
  for (auto& buffer : unused_command_buffers_) {
    buffer.release();
  }
  unused_command_buffers_.clear();
  collected_buffers_.clear();
}

// CommandPoolVK Lifecycle:
// 1. End of frame will reset the command pool (clearing this on a thread).
//    There will still be references to the command pool from the uncompleted
//    command buffers.
// 2. The last reference to the command pool will be released from the fence
//    waiter thread, which will schedule a task on the resource
//    manager thread, which in turn will reset the command pool and make it
//    available for reuse ("recycle").
static thread_local std::unique_ptr<CommandPoolMap> tls_command_pool_map;

// Map each context to a list of all thread-local command pools associated
// with that context.
static Mutex g_all_pools_map_mutex;
static std::unordered_map<
    const ContextVK*,
    std::vector<std::weak_ptr<CommandPoolVK>>> g_all_pools_map
    IPLR_GUARDED_BY(g_all_pools_map_mutex);

std::shared_ptr<DescriptorPoolVK> CommandPoolRecyclerVK::GetDescriptorPool() {
  const auto& strong_context = context_.lock();
  if (!strong_context) {
    return nullptr;
  }

  // If there is a resource in used for this thread and context, return it.
  if (!tls_command_pool_map.get()) {
    tls_command_pool_map.reset(new CommandPoolMap());
  }
  CommandPoolMap& pool_map = *tls_command_pool_map.get();
  auto const hash = strong_context->GetHash();
  auto const it = pool_map.find(hash);
  if (it != pool_map.end()) {
    return it->second.descriptor_pool;
  }

  const auto& result =
      InitializeThreadLocalResources(strong_context, pool_map, hash);
  if (result.has_value()) {
    return result->descriptor_pool;
  }

  return nullptr;
}

// TODO(matanlurey): Return a status_or<> instead of nullptr when we have one.
std::shared_ptr<CommandPoolVK> CommandPoolRecyclerVK::Get() {
  const auto& strong_context = context_.lock();
  if (!strong_context) {
    return nullptr;
  }

  // If there is a resource in used for this thread and context, return it.
  if (!tls_command_pool_map.get()) {
    tls_command_pool_map.reset(new CommandPoolMap());
  }
  CommandPoolMap& pool_map = *tls_command_pool_map.get();
  auto const hash = strong_context->GetHash();
  auto const it = pool_map.find(hash);
  if (it != pool_map.end()) {
    return it->second.command_pool;
  }

  const auto& result =
      InitializeThreadLocalResources(strong_context, pool_map, hash);
  if (result.has_value()) {
    return result->command_pool;
  }

  return nullptr;
}

std::optional<ThreadLocalData>
CommandPoolRecyclerVK::InitializeThreadLocalResources(
    const std::shared_ptr<ContextVK>& context,
    CommandPoolMap& pool_map,
    uint64_t pool_key) {
  auto data = Create();
  if (!data || !data->pool) {
    return std::nullopt;
  }

  auto command_pool = std::make_shared<CommandPoolVK>(
      std::move(data->pool), std::move(data->buffers), context_);
  auto descriptor_pool = std::make_shared<DescriptorPoolVK>(context_);
  {
    Lock all_pools_lock(g_all_pools_map_mutex);
    g_all_pools_map[context.get()].push_back(command_pool);
  }

  return pool_map[pool_key] =
             ThreadLocalData{.command_pool = std::move(command_pool),
                             .descriptor_pool = std::move(descriptor_pool)};
}

// TODO(matanlurey): Return a status_or<> instead of nullopt when we have one.
std::optional<CommandPoolRecyclerVK::RecycledData>
CommandPoolRecyclerVK::Create() {
  // If we can reuse a command pool and its buffers, do so.
  if (auto data = Reuse()) {
    return data;
  }

  // Otherwise, create a new one.
  auto context = context_.lock();
  if (!context) {
    return std::nullopt;
  }
  vk::CommandPoolCreateInfo info;
  info.setQueueFamilyIndex(context->GetGraphicsQueue()->GetIndex().family);
  info.setFlags(vk::CommandPoolCreateFlagBits::eTransient);

  auto device = context->GetDevice();
  auto [result, pool] = device.createCommandPoolUnique(info);
  if (result != vk::Result::eSuccess) {
    return std::nullopt;
  }
  return CommandPoolRecyclerVK::RecycledData{.pool = std::move(pool),
                                             .buffers = {}};
}

std::optional<CommandPoolRecyclerVK::RecycledData>
CommandPoolRecyclerVK::Reuse() {
  // If there are no recycled pools, return nullopt.
  Lock recycled_lock(recycled_mutex_);
  if (recycled_.empty()) {
    return std::nullopt;
  }

  // Otherwise, remove and return a recycled pool.
  auto data = std::move(recycled_.back());
  recycled_.pop_back();
  return std::move(data);
}

void CommandPoolRecyclerVK::Reclaim(
    vk::UniqueCommandPool&& pool,
    std::vector<vk::UniqueCommandBuffer>&& buffers) {
  // Reset the pool on a background thread.
  auto strong_context = context_.lock();
  if (!strong_context) {
    return;
  }
  auto device = strong_context->GetDevice();
  device.resetCommandPool(pool.get());

  // Move the pool to the recycled list.
  Lock recycled_lock(recycled_mutex_);
  recycled_.push_back(
      RecycledData{.pool = std::move(pool), .buffers = std::move(buffers)});
}

CommandPoolRecyclerVK::~CommandPoolRecyclerVK() {
  // Ensure all recycled pools are reclaimed before this is destroyed.
  Dispose();
}

void CommandPoolRecyclerVK::Dispose() {
  CommandPoolMap* pool_map = tls_command_pool_map.get();
  if (pool_map) {
    pool_map->clear();
  }
}

void CommandPoolRecyclerVK::DestroyThreadLocalPools(const ContextVK* context) {
  // Delete the context's entry in this thread's command pool map.
  if (tls_command_pool_map.get()) {
    tls_command_pool_map.get()->erase(context->GetHash());
  }

  // Destroy all other thread-local CommandPoolVK instances associated with
  // this context.
  Lock all_pools_lock(g_all_pools_map_mutex);
  auto found = g_all_pools_map.find(context);
  if (found != g_all_pools_map.end()) {
    for (auto& command_pool : found->second) {
      const auto strong_pool = command_pool.lock();
      if (strong_pool) {
        // Delete all objects held by this pool.  The destroyed pool will still
        // remain in its thread's TLS map until that thread exits.
        strong_pool->Destroy();
      }
    }
    g_all_pools_map.erase(found);
  }
}

}  // namespace impeller
