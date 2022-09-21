// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "impeller/renderer/backend/vulkan/render_pass_vk.h"
#include <array>
#include <vector>

#include "fml/logging.h"
#include "impeller/base/validation.h"
#include "impeller/renderer/backend/vulkan/context_vk.h"
#include "impeller/renderer/backend/vulkan/device_buffer_vk.h"
#include "impeller/renderer/backend/vulkan/formats_vk.h"
#include "impeller/renderer/backend/vulkan/pipeline_vk.h"
#include "impeller/renderer/backend/vulkan/surface_producer_vk.h"
#include "impeller/renderer/backend/vulkan/texture_vk.h"
#include "impeller/renderer/shader_types.h"
#include "vulkan/vulkan_handles.hpp"
#include "vulkan/vulkan_structs.hpp"

namespace impeller {

static uint32_t color_flash = 0;

RenderPassVK::RenderPassVK(std::weak_ptr<const Context> context,
                           vk::Device device,
                           RenderTarget target,
                           vk::UniqueCommandBuffer command_buffer,
                           vk::UniqueRenderPass render_pass,
                           SurfaceProducerVK* surface_producer)
    : RenderPass(context, target),
      device_(device),
      command_buffer_(std::move(command_buffer)),
      render_pass_(std::move(render_pass)),
      surface_producer_(surface_producer) {
  is_valid_ = true;
}

RenderPassVK::~RenderPassVK() = default;

bool RenderPassVK::IsValid() const {
  return is_valid_;
}

void RenderPassVK::OnSetLabel(std::string label) {
  label_ = std::move(label);
}

bool RenderPassVK::OnEncodeCommands(const Context& context) const {
  if (!IsValid()) {
    return false;
  }

  const auto& render_target = GetRenderTarget();
  if (!render_target.HasColorAttachment(0u)) {
    return false;
  }

  vk::CommandBufferBeginInfo begin_info;
  auto res = command_buffer_->begin(begin_info);
  if (res != vk::Result::eSuccess) {
    VALIDATION_LOG << "Failed to begin command buffer: " << vk::to_string(res);
    return false;
  }

  const auto& color0 = render_target.GetColorAttachments().at(0u);
  const auto& depth0 = render_target.GetDepthAttachment();
  const auto& stencil0 = render_target.GetStencilAttachment();

  auto& wrapped_texture = TextureVK::Cast(*color0.texture);
  FML_CHECK(wrapped_texture.IsWrapped());

  // maybe get the semaphores here.
  // signal the submission of command buffer here!.

  auto tex_info = wrapped_texture.GetTextureInfo()->wrapped_texture;
  vk::UniqueFramebuffer framebuffer = CreateFrameBuffer(tex_info);

  uint32_t frame_num = tex_info.frame_num;
  FML_LOG(ERROR) << __PRETTY_FUNCTION__ << ": frame_num: " << frame_num;

  // if (commands_.empty()) {
  //   FML_LOG(ERROR) << "NO COMMANDS TO ENCODE!!!";
  //   return const_cast<RenderPassVK*>(this)->EndCommandBuffer(frame_num);
  // }

  // swapchain framebuffer.

  // layout transition?
  {
    auto pool = command_buffer_.getPool();
    vk::CommandBufferAllocateInfo alloc_info =
        vk::CommandBufferAllocateInfo()
            .setCommandPool(pool)
            .setLevel(vk::CommandBufferLevel::ePrimary)
            .setCommandBufferCount(1);
    auto cmd_buf_res = device_.allocateCommandBuffersUnique(alloc_info);
    if (cmd_buf_res.result != vk::Result::eSuccess) {
      VALIDATION_LOG << "Failed to allocate command buffer: "
                     << vk::to_string(cmd_buf_res.result);
      return false;
    }
    auto cmd_buf_one_time = std::move(cmd_buf_res.value[0]);

    vk::CommandBufferBeginInfo begin_info;
    auto res = cmd_buf_one_time->begin(begin_info);

    vk::ImageMemoryBarrier barrier =
        vk::ImageMemoryBarrier()
            .setSrcAccessMask(vk::AccessFlagBits::eColorAttachmentRead)
            .setDstAccessMask(vk::AccessFlagBits::eColorAttachmentWrite)
            .setOldLayout(vk::ImageLayout::eUndefined)
            .setNewLayout(vk::ImageLayout::eColorAttachmentOptimal)
            .setSrcQueueFamilyIndex(VK_QUEUE_FAMILY_IGNORED)
            .setDstQueueFamilyIndex(VK_QUEUE_FAMILY_IGNORED)
            .setImage(tex_info.swapchain_image->GetImage())
            .setSubresourceRange(
                vk::ImageSubresourceRange()
                    .setAspectMask(vk::ImageAspectFlagBits::eColor)
                    .setBaseMipLevel(0)
                    .setLevelCount(1)
                    .setBaseArrayLayer(0)
                    .setLayerCount(1));
    cmd_buf_one_time->pipelineBarrier(
        vk::PipelineStageFlagBits::eColorAttachmentOutput,
        vk::PipelineStageFlagBits::eColorAttachmentOutput, {}, nullptr, nullptr,
        barrier);

    res = cmd_buf_one_time->end();
    if (res != vk::Result::eSuccess) {
      VALIDATION_LOG << "Failed to end command buffer: " << vk::to_string(res);
      return false;
    }

    surface_producer_->QueueCommandBuffer(frame_num,
                                          std::move(cmd_buf_one_time));
  }

  vk::ClearValue clear_value;
  float flash = abs(sin(color_flash++ / 120.f));
  // clear_value.color =
  //     vk::ClearColorValue(std::array<float, 4>{0.0f, 0.0f, flash, 1.0f});
  clear_value.color =
      vk::ClearColorValue(std::array<float, 4>{0.0f, 0.0f, 0.0, 0.0f});

  std::array<vk::ImageView, 1> fbo_attachments = {
      tex_info.swapchain_image->GetImageView(),
  };

  const auto& size = tex_info.swapchain_image->GetSize();

  // TODO destroy fbo after present.
  vk::FramebufferCreateInfo fb_create_info =
      vk::FramebufferCreateInfo()
          .setAttachments(fbo_attachments)
          .setRenderPass(*render_pass_)
          .setWidth(size.width)
          .setHeight(size.height)
          .setLayers(1);
  auto fb_res = device_.createFramebuffer(fb_create_info);
  if (fb_res.result != vk::Result::eSuccess) {
    VALIDATION_LOG << "Failed to create framebuffer: "
                   << vk::to_string(fb_res.result);
    return false;
  }

  FML_LOG(ERROR) << "rendering to swapchain image: "
                 << tex_info.swapchain_image->GetImage();

  vk::Rect2D render_area =
      vk::Rect2D()
          .setOffset(vk::Offset2D(0, 0))
          .setExtent(vk::Extent2D(size.width, size.height));
  auto rp_begin_info = vk::RenderPassBeginInfo()
                           .setRenderPass(*render_pass_)
                           .setFramebuffer(fb_res.value)
                           .setRenderArea(render_area)
                           .setClearValues(clear_value);

  command_buffer_->beginRenderPass(rp_begin_info, vk::SubpassContents::eInline);

  {
    const auto& transients_allocator = context.GetResourceAllocator();

    // encode the commands.
    for (const auto& command : commands_) {
      if (command.index_count == 0u) {
        continue;
      }

      if (command.instance_count == 0u) {
        continue;
      }

      if (!command.pipeline) {
        continue;
      }

      const auto& pipeline_desc = command.pipeline->GetDescriptor();
      // configure blending
      // configure stencil
      // configure depth
      FML_LOG(ERROR) << "configuring pipeline: " << pipeline_desc.GetLabel();

      auto& pipeline_vk = PipelineVK::Cast(*command.pipeline);
      PipelineCreateInfoVK* pipeline_create_info = pipeline_vk.GetCreateInfo();

      auto vertex_buffer_view = command.GetVertexBuffer();
      auto index_buffer_view = command.index_buffer;

      if (!vertex_buffer_view || !index_buffer_view) {
        return false;
      }

      auto& allocator = *transients_allocator;
      auto vertex_buffer =
          vertex_buffer_view.buffer->GetDeviceBuffer(allocator);
      auto index_buffer = index_buffer_view.buffer->GetDeviceBuffer(allocator);

      if (!vertex_buffer || !index_buffer) {
        FML_LOG(ERROR) << "Failed to get device buffers for vertex and index";
        return false;
      } else {
        FML_LOG(ERROR) << "got device buffers for vertex and index";
      }

      // descriptor sets
      vk::PipelineLayout pipeline_layout =
          pipeline_create_info->GetPipelineLayout();

      // bind pipeline
      command_buffer_->bindPipeline(vk::PipelineBindPoint::eGraphics,
                                    pipeline_create_info->GetPipeline());

      const auto& context_vk = ContextVK::Cast(context);
      const auto& pool = context_vk.GetDescriptorPool();

      vk::DescriptorSetAllocateInfo alloc_info;
      std::array<vk::DescriptorSetLayout, 1> dsls = {
          pipeline_create_info->GetDescriptorSetLayout(),
      };

      alloc_info.setDescriptorPool(pool->GetPool());
      alloc_info.setSetLayouts(dsls);

      auto desc_sets_res = device_.allocateDescriptorSets(alloc_info);
      if (desc_sets_res.result != vk::Result::eSuccess) {
        VALIDATION_LOG << "Failed to allocate descriptor sets: "
                       << vk::to_string(desc_sets_res.result);
        return false;
      }
      auto desc_sets = desc_sets_res.value;
      bool update_vertex_descriptors = UpdateDescriptorSets(
          "vertex_bindings", command.vertex_bindings, allocator, desc_sets[0]);
      if (!update_vertex_descriptors) {
        return false;
      }
      bool update_frag_descriptors =
          UpdateDescriptorSets("fragment_bindings", command.fragment_bindings,
                               allocator, desc_sets[0]);
      if (!update_frag_descriptors) {
        return false;
      }

      command_buffer_->bindDescriptorSets(vk::PipelineBindPoint::eGraphics,
                                          pipeline_layout, 0, desc_sets,
                                          nullptr);

      // bind vertex buffer
      auto vertex_buffer_handle = DeviceBufferVK::Cast(*vertex_buffer)
                                      .GetAllocation()
                                      ->GetBufferHandle();
      vk::Buffer vertex_buffers[] = {vertex_buffer_handle};
      vk::DeviceSize vertex_buffer_offsets[] = {
          vertex_buffer_view.range.offset};
      FML_LOG(ERROR) << "binding vertex buffer: " << vertex_buffer_handle;
      command_buffer_->bindVertexBuffers(0, 1, vertex_buffers,
                                         vertex_buffer_offsets);

      // index buffer
      auto index_buffer_handle = DeviceBufferVK::Cast(*index_buffer)
                                     .GetAllocation()
                                     ->GetBufferHandle();
      command_buffer_->bindIndexBuffer(index_buffer_handle,
                                       index_buffer_view.range.offset,
                                       vk::IndexType::eUint16);

      // set viewport.
      const auto& vp = command.viewport.value_or<Viewport>(
          {.rect = Rect::MakeSize(GetRenderTargetSize())});
      vk::Viewport viewport = vk::Viewport()
                                  .setWidth(vp.rect.size.width)
                                  .setHeight(vp.rect.size.height)
                                  .setMinDepth(0.0f)
                                  .setMaxDepth(1.0f);
      command_buffer_->setViewport(0, 1, &viewport);

      // scissor
      const auto& sc =
          command.scissor.value_or(IRect::MakeSize(GetRenderTargetSize()));
      vk::Rect2D scissor =
          vk::Rect2D()
              .setOffset(vk::Offset2D(sc.origin.x, sc.origin.y))
              .setExtent(vk::Extent2D(sc.size.width, sc.size.height));
      command_buffer_->setScissor(0, 1, &scissor);

      // execute draw
      command_buffer_->drawIndexed(command.index_count, command.instance_count,
                                   0, 0, 0);
    }
  }

  command_buffer_->endRenderPass();

  return const_cast<RenderPassVK*>(this)->EndCommandBuffer(frame_num);
}

bool RenderPassVK::EndCommandBuffer(uint32_t frame_num) {
  if (command_buffer_) {
    auto res = command_buffer_->end();
    if (res != vk::Result::eSuccess) {
      FML_LOG(ERROR) << "Failed to end command buffer: " << vk::to_string(res);
      return false;
    }

    surface_producer_->StashRP(frame_num, std::move(render_pass_));

    return surface_producer_->QueueCommandBuffer(frame_num,
                                                 std::move(command_buffer_));
  }
  return false;
}

bool RenderPassVK::UpdateDescriptorSets(const char* label,
                                        const Bindings& bindings,
                                        Allocator& allocator,
                                        vk::DescriptorSet desc_set) const {
  std::vector<vk::WriteDescriptorSet> writes;
  std::vector<vk::DescriptorBufferInfo> buffer_infos;
  for (const auto& [buffer_index, view] : bindings.buffers) {
    const auto& buffer_view = view.resource.buffer;

    auto device_buffer = buffer_view->GetDeviceBuffer(allocator);
    if (!device_buffer) {
      VALIDATION_LOG << "Failed to get device buffer for vertex binding";
      return false;
    }

    auto buffer = DeviceBufferVK::Cast(*device_buffer).GetAllocation();
    if (!buffer) {
      return false;
    }

    if (buffer_index == VertexDescriptor::kReservedVertexBufferIndex) {
      continue;
    }

    uint32_t offset = view.resource.range.offset;

    vk::DescriptorBufferInfo desc_buffer_info;
    desc_buffer_info.setBuffer(buffer->GetBufferHandle());
    desc_buffer_info.setOffset(offset);
    desc_buffer_info.setRange(view.resource.range.length);
    buffer_infos.push_back(desc_buffer_info);

    const ShaderUniformSlot& uniform = bindings.uniforms.at(buffer_index);
    FML_LOG(ERROR) << label << "; at buffer index: " << buffer_index
                   << " name: " << uniform.name
                   << " buffer: " << buffer->GetBufferHandle()
                   << " offset: " << offset
                   << " range: " << view.resource.range.length
                   << " uniform_binding: " << uniform.binding
                   << " uniform_set: " << uniform.set;

    vk::WriteDescriptorSet setWrite;
    setWrite.setDstSet(desc_set);
    setWrite.setDstBinding(uniform.binding);
    setWrite.setDescriptorCount(1);
    setWrite.setDescriptorType(vk::DescriptorType::eUniformBuffer);
    setWrite.setPBufferInfo(&buffer_infos.back());

    writes.push_back(setWrite);
  }

  std::array<vk::CopyDescriptorSet, 0> copies;
  device_.updateDescriptorSets(writes, copies);

  return true;
}

vk::UniqueFramebuffer RenderPassVK::CreateFrameBuffer(
    const WrappedTextureInfoVK& wrapped_texture_info) const {
  auto img_view = wrapped_texture_info.swapchain_image->GetImageView();
  auto size = wrapped_texture_info.swapchain_image->GetSize();
  vk::FramebufferCreateInfo fb_create_info = vk::FramebufferCreateInfo()
                                                 .setRenderPass(*render_pass_)
                                                 .setAttachmentCount(1)
                                                 .setPAttachments(&img_view)
                                                 .setWidth(size.width)
                                                 .setHeight(size.height)
                                                 .setLayers(1);
  auto res = device_.createFramebufferUnique(fb_create_info);
  FML_CHECK(res.result == vk::Result::eSuccess);
  return std::move(res.value);
}

}  // namespace impeller
