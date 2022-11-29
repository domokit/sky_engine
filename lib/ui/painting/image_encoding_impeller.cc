// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "flutter/lib/ui/painting/image.h"
#include "impeller/renderer/command_buffer.h"
#include "impeller/renderer/context.h"
#include "impeller/renderer/device_buffer.h"
#include "impeller/renderer/formats.h"

namespace flutter {
namespace {

std::optional<SkColorType> ToSkColorType(impeller::PixelFormat format) {
  switch (format) {
    case impeller::PixelFormat::kR8G8B8A8UNormInt:
      return SkColorType::kRGBA_8888_SkColorType;
    case impeller::PixelFormat::kB8G8R8A8UNormInt:
      return SkColorType::kBGRA_8888_SkColorType;
      break;
    default:
      return std::nullopt;
      break;
  }
}

sk_sp<SkImage> ConvertBufferToSkImage(
    const std::shared_ptr<impeller::DeviceBuffer>& buffer,
    impeller::PixelFormat format,
    SkISize dimensions) {
  auto buffer_view = buffer->AsBufferView();

  auto color_type = ToSkColorType(format);
  if (!color_type.has_value()) {
    FML_LOG(ERROR) << "Failed to get color type from pixel format.";
  }
  SkImageInfo image_info = SkImageInfo::Make(dimensions, color_type.value(),
                                             SkAlphaType::kPremul_SkAlphaType);

  SkBitmap bitmap;
  auto func = [](void* addr, void* context) {
    auto buffer =
        static_cast<std::shared_ptr<impeller::DeviceBuffer>*>(context);
    buffer->reset();
    delete buffer;
  };
  auto bytes_per_pixel = impeller::BytesPerPixelForPixelFormat(format);
  bitmap.installPixels(image_info, buffer_view.contents,
                       dimensions.width() * bytes_per_pixel, func,
                       new std::shared_ptr<impeller::DeviceBuffer>(buffer));
  bitmap.setImmutable();

  sk_sp<SkImage> raster_image = SkImage::MakeFromBitmap(bitmap);
  return raster_image;
}

void ConvertDlImageImpellerToSkImage(
    const sk_sp<DlImage>& dl_image,
    std::function<void(sk_sp<SkImage>)> encode_task,
    const std::shared_ptr<impeller::Context>& impeller_context) {
  auto texture = dl_image->impeller_texture();

  if (impeller_context == nullptr) {
    FML_LOG(ERROR) << "Impeller context was null.";
    encode_task(nullptr);
    return;
  }

  if (texture == nullptr) {
    FML_LOG(ERROR) << "Image was null.";
    encode_task(nullptr);
    return;
  }

  auto dimensions = dl_image->dimensions();
  auto format = texture->GetTextureDescriptor().format;

  if (dimensions.isEmpty()) {
    FML_LOG(ERROR) << "Image dimensions were empty.";
    encode_task(nullptr);
    return;
  }

  impeller::DeviceBufferDescriptor buffer_desc;
  buffer_desc.storage_mode = impeller::StorageMode::kHostVisible;
  buffer_desc.size =
      texture->GetTextureDescriptor().GetByteSizeOfBaseMipLevel();
  auto buffer =
      impeller_context->GetResourceAllocator()->CreateBuffer(buffer_desc);
  auto command_buffer = impeller_context->CreateCommandBuffer();
  command_buffer->SetLabel("BlitTextureToBuffer Command Buffer");
  auto pass = command_buffer->CreateBlitPass();
  pass->SetLabel("BlitTextureToBuffer Blit Pass");
  pass->AddCopy(texture, buffer);
  pass->EncodeCommands(impeller_context->GetResourceAllocator());
  auto completion = [buffer, format, dimensions,
                     encode_task = std::move(encode_task)](
                        impeller::CommandBuffer::Status status) {
    if (status != impeller::CommandBuffer::Status::kCompleted) {
      encode_task(nullptr);
      return;
    }
    auto sk_image = ConvertBufferToSkImage(buffer, format, dimensions);
    encode_task(sk_image);
  };

  if (!command_buffer->SubmitCommands()) {
    FML_LOG(ERROR) << "Failed to submit commands.";
  }
}

void DoConvertImageToRasterImpeller(
    const sk_sp<DlImage>& dl_image,
    std::function<void(sk_sp<SkImage>)> encode_task,
    const std::shared_ptr<const fml::SyncSwitch>& is_gpu_disabled_sync_switch,
    const std::shared_ptr<impeller::Context>& impeller_context) {
  is_gpu_disabled_sync_switch->Execute(
      fml::SyncSwitch::Handlers()
          .SetIfTrue([&encode_task] { encode_task(nullptr); })
          .SetIfFalse([&dl_image, &encode_task, &impeller_context] {
            ConvertDlImageImpellerToSkImage(dl_image, std::move(encode_task),
                                            impeller_context);
          }));
}

}  // namespace

void ConvertImageToRasterImpeller(
    const sk_sp<DlImage>& dl_image,
    std::function<void(sk_sp<SkImage>)> encode_task,
    const fml::RefPtr<fml::TaskRunner>& raster_task_runner,
    const fml::RefPtr<fml::TaskRunner>& io_task_runner,
    const std::shared_ptr<const fml::SyncSwitch>& is_gpu_disabled_sync_switch,
    const std::shared_ptr<impeller::Context>& impeller_context) {
  auto original_encode_task = std::move(encode_task);
  encode_task = [original_encode_task = std::move(original_encode_task),
                 io_task_runner](sk_sp<SkImage> image) mutable {
    fml::TaskRunner::RunNowOrPostTask(
        io_task_runner,
        [original_encode_task = std::move(original_encode_task),
         image = std::move(image)]() { original_encode_task(image); });
  };

  if (dl_image->owning_context() != DlImage::OwningContext::kRaster) {
    DoConvertImageToRasterImpeller(dl_image, std::move(encode_task),
                                   is_gpu_disabled_sync_switch,
                                   impeller_context);
    return;
  }

  raster_task_runner->PostTask([dl_image, encode_task = std::move(encode_task),
                                io_task_runner, is_gpu_disabled_sync_switch,
                                impeller_context]() mutable {
    DoConvertImageToRasterImpeller(dl_image, std::move(encode_task),
                                   is_gpu_disabled_sync_switch,
                                   impeller_context);
  });
}

}  // namespace flutter
