// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_SHELL_PLATFORM_DARWIN_IOS_IOS_SURFACE_GL_H_
#define FLUTTER_SHELL_PLATFORM_DARWIN_IOS_IOS_SURFACE_GL_H_

#include "flutter/fml/macros.h"
#include "flutter/fml/platform/darwin/scoped_nsobject.h"
#include "flutter/shell/gpu/gpu_surface_gl.h"
#include "flutter/shell/platform/darwin/ios/ios_context.h"
#include "flutter/shell/platform/darwin/ios/ios_render_target_gl.h"
#include "flutter/shell/platform/darwin/ios/ios_surface.h"

@class CALayer;

namespace flutter {

class IOSSurfaceGL final : public IOSSurface, public GPUSurfaceGLDelegate {
 public:
  IOSSurfaceGL(fml::scoped_nsobject<CALayer> layer,
               std::shared_ptr<IOSContext> context,
               FlutterPlatformViewsController* platform_views_controller = nullptr);

  ~IOSSurfaceGL() override;

  // |IOSSurface|
  bool IsValid() const override;

  // |IOSSurface|
  void UpdateStorageSizeIfNecessary() override;

  // |IOSSurface|
  std::unique_ptr<Surface> CreateGPUSurface(GrContext* gr_context) override;

  // |GPUSurfaceGLDelegate|
  bool GLContextMakeCurrent() override;

  // |GPUSurfaceGLDelegate|
  bool GLContextClearCurrent() override;

  // |GPUSurfaceGLDelegate|
  bool GLContextPresent() override;

  // |GPUSurfaceGLDelegate|
  intptr_t GLContextFBO() const override;

  // |GPUSurfaceGLDelegate|
  bool SurfaceSupportsReadback() const override;

  // |GPUSurfaceGLDelegate|
  ExternalViewEmbedder* GetExternalViewEmbedder() override;

 private:
  std::unique_ptr<IOSRenderTargetGL> render_target_;

  FML_DISALLOW_COPY_AND_ASSIGN(IOSSurfaceGL);
};

}  // namespace flutter

#endif  // FLUTTER_SHELL_PLATFORM_DARWIN_IOS_IOS_SURFACE_GL_H_
