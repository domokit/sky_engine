// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "flutter/shell/platform/darwin/ios/ios_gl_context.h"

#include <UIKit/UIKit.h>

#include "flutter/fml/trace_event.h"
#include "third_party/skia/include/gpu/GrContextOptions.h"
#include "third_party/skia/include/gpu/gl/GrGLInterface.h"

namespace flutter {

IOSGLContext::IOSGLContext() : IOSGLContext(nullptr) {}

IOSGLContext::IOSGLContext(EAGLSharegroup* sharegroup)
    : weak_factory_(std::make_unique<fml::WeakPtrFactory<IOSGLContext>>(this)) {
  context_.reset([[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3
                                       sharegroup:sharegroup]);

  if (!context_) {
    context_.reset([[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2
                                         sharegroup:sharegroup]);
  }

  // TODO:
  // iOS displays are more variable than just P3 or sRGB.  Reading the display
  // gamut just tells us what color space it makes sense to render into.  We
  // should use iOS APIs to perform the final correction step based on the
  // device properties.  Ex: We can indicate that we have rendered in P3, and
  // the framework will do the final adjustment for us.
  color_space_ = SkColorSpace::MakeSRGB();
  if (@available(iOS 10, *)) {
    UIDisplayGamut displayGamut = [UIScreen mainScreen].traitCollection.displayGamut;
    switch (displayGamut) {
      case UIDisplayGamutP3:
        // Should we consider using more than 8-bits of precision given that
        // P3 specifies a wider range of colors?
        color_space_ = SkColorSpace::MakeRGB(SkNamedTransferFn::kSRGB, SkNamedGamut::kDCIP3);
        break;
      default:
        break;
    }
  }
}

fml::WeakPtr<IOSGLContext> IOSGLContext::GetWeakPtr() {
  return weak_factory_->GetWeakPtr();
}

bool IOSGLContext::BindRenderbufferStorage(NSUInteger target,
                                           fml::scoped_nsobject<CAEAGLLayer> layer) {
  return [context_.get() renderbufferStorage:GL_RENDERBUFFER fromDrawable:layer.get()];
}

IOSGLContext::~IOSGLContext() = default;

bool IOSGLContext::MakeCurrent() {
  return [EAGLContext setCurrentContext:context_.get()];
}

std::unique_ptr<IOSGLContext> IOSGLContext::MakeSharedContext() {
  return std::make_unique<IOSGLContext>(context_.get().sharegroup);
}

}  // namespace flutter
