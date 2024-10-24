// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "flutter/lib/ui/painting/image_filter.h"

#include "flutter/lib/ui/floating_point.h"
#include "flutter/lib/ui/painting/matrix.h"
#include "flutter/lib/ui/ui_dart_state.h"
#include "third_party/tonic/converter/dart_converter.h"
#include "third_party/tonic/dart_args.h"
#include "third_party/tonic/dart_binding_macros.h"
#include "third_party/tonic/dart_library_natives.h"

namespace flutter {

IMPLEMENT_WRAPPERTYPEINFO(ui, ImageFilter);

void ImageFilter::Create(Dart_Handle wrapper) {
  UIDartState::ThrowIfUIOperationsProhibited();
  auto res = fml::MakeRefCounted<ImageFilter>();
  res->AssociateWithDartWrapper(wrapper);
}

static const std::array<DlImageSampling, 4> kFilterQualities = {
    DlImageSampling::kNearestNeighbor,
    DlImageSampling::kLinear,
    DlImageSampling::kMipmapLinear,
    DlImageSampling::kCubic,
};

DlImageSampling ImageFilter::SamplingFromIndex(int filterQualityIndex) {
  if (filterQualityIndex < 0) {
    return kFilterQualities.front();
  } else if (static_cast<size_t>(filterQualityIndex) >=
             kFilterQualities.size()) {
    return kFilterQualities.back();
  } else {
    return kFilterQualities[filterQualityIndex];
  }
}

DlFilterMode ImageFilter::FilterModeFromIndex(int filterQualityIndex) {
  if (filterQualityIndex <= 0) {
    return DlFilterMode::kNearest;
  }
  return DlFilterMode::kLinear;
}

ImageFilter::ImageFilter() {}

ImageFilter::~ImageFilter() {}

const std::shared_ptr<const DlImageFilter> ImageFilter::filter(
    DlTileMode mode) const {
  if (dynamic_tile_mode_) {
    const DlBlurImageFilter* blur_filter = filter_->asBlur();
    FML_DCHECK(blur_filter != nullptr);
    if (blur_filter->tile_mode() != mode) {
      return DlBlurImageFilter::Make(blur_filter->sigma_x(),
                                     blur_filter->sigma_y(), mode);
    }
  }
  return filter_;
}

void ImageFilter::initBlur(double sigma_x,
                           double sigma_y,
                           int tile_mode_index) {
  DlTileMode tile_mode;
  if (tile_mode_index < 0) {
    dynamic_tile_mode_ = true;
    tile_mode = DlTileMode::kClamp;
  } else {
    dynamic_tile_mode_ = false;
    tile_mode = static_cast<DlTileMode>(tile_mode_index);
  }
  filter_ = DlBlurImageFilter::Make(SafeNarrow(sigma_x), SafeNarrow(sigma_y),
                                    tile_mode);
}

void ImageFilter::initDilate(double radius_x, double radius_y) {
  dynamic_tile_mode_ = false;
  filter_ =
      DlDilateImageFilter::Make(SafeNarrow(radius_x), SafeNarrow(radius_y));
}

void ImageFilter::initErode(double radius_x, double radius_y) {
  dynamic_tile_mode_ = false;
  filter_ =
      DlErodeImageFilter::Make(SafeNarrow(radius_x), SafeNarrow(radius_y));
}

void ImageFilter::initMatrix(const tonic::Float64List& matrix4,
                             int filterQualityIndex) {
  dynamic_tile_mode_ = false;
  auto sampling = ImageFilter::SamplingFromIndex(filterQualityIndex);
  filter_ = DlMatrixImageFilter::Make(ToSkMatrix(matrix4), sampling);
}

void ImageFilter::initColorFilter(ColorFilter* colorFilter) {
  FML_DCHECK(colorFilter);
  dynamic_tile_mode_ = false;
  filter_ = DlColorFilterImageFilter::Make(colorFilter->filter());
}

void ImageFilter::initComposeFilter(ImageFilter* outer, ImageFilter* inner) {
  FML_DCHECK(outer && inner);
  dynamic_tile_mode_ = false;
  filter_ = DlComposeImageFilter::Make(outer->filter(DlTileMode::kClamp),
                                       inner->filter(DlTileMode::kClamp));
}

}  // namespace flutter
