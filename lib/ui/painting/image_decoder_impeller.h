// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_LIB_UI_PAINTING_IMAGE_DECODER_IMPELLER_H_
#define FLUTTER_LIB_UI_PAINTING_IMAGE_DECODER_IMPELLER_H_

#include <future>

#include "flutter/fml/macros.h"
#include "flutter/lib/ui/painting/image_decoder.h"
#include "impeller/geometry/size.h"
#include "third_party/skia/include/core/SkBitmap.h"

namespace impeller {
class Context;
class Allocator;
class DeviceBuffer;
}  // namespace impeller

namespace flutter {

class ImpellerAllocator : public SkBitmap::Allocator {
 public:
  explicit ImpellerAllocator(std::shared_ptr<impeller::Allocator> allocator);

  ~ImpellerAllocator() = default;

  // |Allocator|
  bool allocPixelRef(SkBitmap* bitmap) override;

  std::optional<std::shared_ptr<impeller::DeviceBuffer>> GetDeviceBuffer()
      const;

 private:
  std::shared_ptr<impeller::Allocator> allocator_;
  std::optional<std::shared_ptr<impeller::DeviceBuffer>> buffer_;
};

struct DecompressResult {
  std::shared_ptr<impeller::DeviceBuffer> device_buffer;
  SkImageInfo image_info;
};

class ImageDecoderImpeller final : public ImageDecoder {
 public:
  ImageDecoderImpeller(
      const TaskRunners& runners,
      std::shared_ptr<fml::ConcurrentTaskRunner> concurrent_task_runner,
      const fml::WeakPtr<IOManager>& io_manager,
      bool supports_wide_gamut);

  ~ImageDecoderImpeller() override;

  // |ImageDecoder|
  void Decode(fml::RefPtr<ImageDescriptor> descriptor,
              uint32_t target_width,
              uint32_t target_height,
              const ImageResult& result) override;

  static std::optional<DecompressResult> DecompressTexture(
      ImageDescriptor* descriptor,
      SkISize target_size,
      impeller::ISize max_texture_size,
      bool supports_wide_gamut,
      const std::shared_ptr<impeller::Context>& context);

  static sk_sp<DlImage> UploadTexture(
      const std::shared_ptr<impeller::Context>& context,
      std::shared_ptr<impeller::DeviceBuffer> buffer,
      const SkImageInfo& image_info);

  static sk_sp<DlImage> UploadTexture(
      const std::shared_ptr<impeller::Context>& context,
      std::shared_ptr<SkBitmap> bitmap);

 private:
  using FutureContext = std::shared_future<std::shared_ptr<impeller::Context>>;
  FutureContext context_;
  const bool supports_wide_gamut_;

  FML_DISALLOW_COPY_AND_ASSIGN(ImageDecoderImpeller);
};

}  // namespace flutter

#endif  // FLUTTER_LIB_UI_PAINTING_IMAGE_DECODER_IMPELLER_H_
