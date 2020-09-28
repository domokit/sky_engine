// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "surface.h"

#include <fcntl.h>
#include <lib/fdio/watcher.h>
#include <lib/zx/time.h>
#include <unistd.h>

#include "flutter/fml/unique_fd.h"

namespace flutter_runner {

Surface::Surface(std::string debug_label,
                 flutter::ExternalViewEmbedder* view_embedder,
                 GrDirectContext* gr_context)
    : debug_label_(std::move(debug_label)),
      view_embedder_(view_embedder),
      gr_context_(gr_context) {}

Surface::~Surface() = default;

// |flutter::Surface|
bool Surface::IsValid() {
  return true;
}

// |flutter::Surface|
std::unique_ptr<flutter::SurfaceFrame> Surface::AcquireFrame(
    const SkISize& size) {
  flutter::SurfaceFrame::FramebufferInfo framebuffer_info;
  framebuffer_info.supports_readback = true;
  return std::make_unique<flutter::SurfaceFrame>(
      nullptr, std::move(framebuffer_info),
      [](const flutter::SurfaceFrame& surface_frame, SkCanvas* canvas) {
        return true;
      });
}

// |flutter::Surface|
GrDirectContext* Surface::GetContext() {
  return gr_context_;
}

// |flutter::Surface|
SkMatrix Surface::GetRootTransformation() const {
  // This backend does not support delegating to the underlying platform to
  // query for root surface transformations. Just return identity.
  SkMatrix matrix;
  matrix.reset();
  return matrix;
}

// |flutter::GetViewEmbedder|
flutter::ExternalViewEmbedder* Surface::GetExternalViewEmbedder() {
  return view_embedder_;
}

}  // namespace flutter_runner
