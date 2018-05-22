// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_LIB_UI_PAINTING_PICTURE_H_
#define FLUTTER_LIB_UI_PAINTING_PICTURE_H_

#include "flutter/flow/skia_gpu_object.h"
#include "flutter/lib/ui/painting/image.h"
#include "lib/tonic/dart_wrappable.h"
#include "third_party/skia/include/core/SkPicture.h"

namespace tonic {
class DartLibraryNatives;
}  // namespace tonic

namespace blink {
class Canvas;

class Picture : public fxl::RefCountedThreadSafe<Picture>,
                public tonic::DartWrappable {
  DEFINE_WRAPPERTYPEINFO();
  FRIEND_MAKE_REF_COUNTED(Picture);

 public:
  ~Picture() override;
  static fxl::RefPtr<Picture> Create(flow::SkiaGPUObject<SkPicture> picture,
                                     bool scaled_to_device = false);

  sk_sp<SkPicture> picture() const { return picture_.get(); }

  fxl::RefPtr<CanvasImage> toImage(int width, int height);

  void dispose();

  virtual size_t GetAllocationSize() override;

  static void RegisterNatives(tonic::DartLibraryNatives* natives);

 private:
  explicit Picture(flow::SkiaGPUObject<SkPicture> picture, bool scaled_to_device = false);

  flow::SkiaGPUObject<SkPicture> picture_;
  bool scaled_to_device_;
};

}  // namespace blink

#endif  // FLUTTER_LIB_UI_PAINTING_PICTURE_H_
