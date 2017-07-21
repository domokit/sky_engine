// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_SHELL_PLATFORM_ANDROID_ANDROID_CONTEXT_GL_H_
#define FLUTTER_SHELL_PLATFORM_ANDROID_ANDROID_CONTEXT_GL_H_

#include "flutter/shell/common/platform_view.h"
#include "flutter/shell/platform/android/android_environment_gl.h"
#include "flutter/shell/platform/android/android_native_window.h"
#include "lib/ftl/macros.h"
#include "lib/ftl/memory/ref_counted.h"
#include "lib/ftl/memory/ref_ptr.h"
#include "third_party/skia/include/core/SkSize.h"

namespace shell {

class AndroidContextGL : public ftl::RefCountedThreadSafe<AndroidContextGL> {
 public:
  bool CreateWindowSurface(ftl::RefPtr<AndroidNativeWindow> window,
                           const SkISize& size);

  bool CreateWindowSurface(ftl::RefPtr<AndroidNativeWindow> window);

  bool CreatePBufferSurface();

  ftl::RefPtr<AndroidEnvironmentGL> Environment() const;

  bool IsValid() const;

  bool MakeCurrent();

  bool ClearCurrent();

  bool SwapBuffers();

  SkISize GetSize();

  bool Resize(const SkISize& size);

  bool SupportsSRGB() const;

 private:
  ftl::RefPtr<AndroidEnvironmentGL> environment_;
  ftl::RefPtr<AndroidNativeWindow> window_;
  EGLConfig config_;
  EGLSurface surface_;
  EGLContext context_;
  bool srgb_support_;
  bool valid_;

  AndroidContextGL(ftl::RefPtr<AndroidEnvironmentGL> env,
                   PlatformView::SurfaceConfig config,
                   const AndroidContextGL* share_context = nullptr);

  ~AndroidContextGL();

  FRIEND_MAKE_REF_COUNTED(AndroidContextGL);
  FRIEND_REF_COUNTED_THREAD_SAFE(AndroidContextGL);
  FTL_DISALLOW_COPY_AND_ASSIGN(AndroidContextGL);
};

}  // namespace shell

#endif  // FLUTTER_SHELL_PLATFORM_ANDROID_ANDROID_CONTEXT_GL_H_
