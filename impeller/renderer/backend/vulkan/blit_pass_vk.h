// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#pragma once

#include "flutter/fml/macros.h"
#include "impeller/renderer/backend/vulkan/blit_command_vk.h"
#include "impeller/renderer/blit_pass.h"

namespace impeller {

class CommandEncoderVK;

class BlitPassVK final : public BlitPass {
 public:
  // |BlitPass|
  ~BlitPassVK() override;

 private:
  friend class CommandBufferVK;

  std::weak_ptr<CommandEncoderVK> encoder_;
  std::vector<std::unique_ptr<BlitEncodeVK>> commands_;
  std::string label_;

  BlitPassVK(std::weak_ptr<CommandEncoderVK> encoder);

  // |BlitPass|
  bool IsValid() const override;

  // |BlitPass|
  void OnSetLabel(std::string label) override;

  // |BlitPass|
  bool EncodeCommands(
      const std::shared_ptr<Allocator>& transients_allocator) const override;

  // |BlitPass|
  bool OnCopyTextureToTextureCommand(std::shared_ptr<Texture> source,
                                     std::shared_ptr<Texture> destination,
                                     IRect source_region,
                                     IPoint destination_origin,
                                     std::string label) override;

  // |BlitPass|
  bool OnCopyTextureToBufferCommand(std::shared_ptr<Texture> source,
                                    std::shared_ptr<DeviceBuffer> destination,
                                    IRect source_region,
                                    size_t destination_offset,
                                    std::string label) override;

  // |BlitPass|
  bool OnCopyBufferToTextureCommand(std::shared_ptr<DeviceBuffer> source,
                                    std::shared_ptr<Texture> destination,
                                    size_t source_offset,
                                    IPoint destination_origin,
                                    std::string label) override {
    return false;
  }

  // |BlitPass|
  bool OnOptimizeForGPUAccess(std::shared_ptr<Texture> texture,
                              std::string label) override;
  // |BlitPass|
  bool OnGenerateMipmapCommand(std::shared_ptr<Texture> texture,
                               std::string label) override;

  FML_DISALLOW_COPY_AND_ASSIGN(BlitPassVK);
};

}  // namespace impeller
