// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "base/mac/scoped_nsautorelease_pool.h"
#include "sky/engine/wtf/MakeUnique.h"
#include "sky/shell/platform/ios/platform_view_ios.h"

#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <OpenGLES/EAGL.h>
#import <QuartzCore/CAEAGLLayer.h>

namespace sky {
namespace shell {

struct GLintSize {
  GLint width;
  GLint height;

  GLintSize() : width(0), height(0) {}

  GLintSize(GLint w, GLint h) : width(w), height(h) {}

  GLintSize(CGSize size)
      : width(static_cast<GLint>(size.width)),
        height(static_cast<GLint>(size.height)) {}

  bool operator==(const GLintSize& other) const {
    return width == other.width && height == other.height;
  }
};

class IOSGLContext {
 public:
  IOSGLContext(PlatformView::SurfaceConfig config, CAEAGLLayer* layer)
      : layer_(layer),
        context_([[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2]),
        framebuffer_(GL_NONE),
        colorbuffer_(GL_NONE),
        depthbuffer_(GL_NONE),
        stencilbuffer_(GL_NONE),
        depth_stencil_packed_buffer_(GL_NONE) {
    CHECK(layer_ != nullptr);
    CHECK(context_ != nullptr);

    DCHECK(glGetError() == GL_NO_ERROR);

    // Generate the framebuffer

    glGenFramebuffers(1, &framebuffer_);
    DCHECK(framebuffer_ != GL_NONE);

    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer_);
    DCHECK(glGetError() == GL_NO_ERROR);

    // Setup color attachment

    glGenRenderbuffers(1, &colorbuffer_);
    DCHECK(colorbuffer_ != GL_NONE);

    glBindRenderbuffer(GL_RENDERBUFFER, colorbuffer_);
    DCHECK(glGetError() == GL_NO_ERROR);

    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                              GL_RENDERBUFFER, colorbuffer_);
    DCHECK(glGetError() == GL_NO_ERROR);

    // On iOS, if both depth and stencil attachments are requested, we are
    // required to create a single renderbuffer that acts as both.

    auto requires_packed =
        (config.depth_bits != 0) && (config.stencil_bits != 0);

    if (requires_packed) {
      glGenRenderbuffers(1, &depth_stencil_packed_buffer_);
      glBindRenderbuffer(GL_RENDERBUFFER, depth_stencil_packed_buffer_);
      DCHECK(depth_stencil_packed_buffer_ != GL_NONE);

      glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT,
                                GL_RENDERBUFFER, depth_stencil_packed_buffer_);
      glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT,
                                GL_RENDERBUFFER, depth_stencil_packed_buffer_);
      DCHECK(depth_stencil_packed_buffer_ != GL_NONE);
    } else {
      // Setup the depth attachment if necessary
      if (config.depth_bits != 0) {
        glGenRenderbuffers(1, &depthbuffer_);
        DCHECK(depthbuffer_ != GL_NONE);

        glBindRenderbuffer(GL_RENDERBUFFER, depthbuffer_);
        DCHECK(glGetError() == GL_NO_ERROR);

        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT,
                                  GL_RENDERBUFFER, depthbuffer_);
        DCHECK(glGetError() == GL_NO_ERROR);
      }

      // Setup the stencil attachment if necessary
      if (config.stencil_bits != 0) {
        glGenRenderbuffers(1, &stencilbuffer_);
        DCHECK(stencilbuffer_ != GL_NONE);

        glBindRenderbuffer(GL_RENDERBUFFER, stencilbuffer_);
        DCHECK(glGetError() == GL_NO_ERROR);

        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT,
                                  GL_RENDERBUFFER, stencilbuffer_);
        DCHECK(glGetError() == GL_NO_ERROR);
      }
    }

    // The default is RGBA
    NSString* drawableColorFormat = kEAGLColorFormatRGBA8;

    if (config.red_bits <= 5 && config.green_bits <= 6 &&
        config.blue_bits <= 5 && config.alpha_bits == 0) {
      drawableColorFormat = kEAGLColorFormatRGB565;
    }

    layer_.get().drawableProperties = @{
      kEAGLDrawablePropertyColorFormat : drawableColorFormat,
      kEAGLDrawablePropertyRetainedBacking : @(NO),
    };
  }

  ~IOSGLContext() {
    DCHECK(glGetError() == GL_NO_ERROR);

    // Deletes on GL_NONEs are ignored
    glDeleteFramebuffers(1, &framebuffer_);

    glDeleteRenderbuffers(1, &colorbuffer_);
    glDeleteRenderbuffers(1, &depthbuffer_);
    glDeleteRenderbuffers(1, &stencilbuffer_);
    glDeleteRenderbuffers(1, &depth_stencil_packed_buffer_);

    DCHECK(glGetError() == GL_NO_ERROR);
  }

  bool PresentRenderBuffer() const {
    const GLenum discards[] = {
        GL_DEPTH_ATTACHMENT, GL_STENCIL_ATTACHMENT,
    };

    glDiscardFramebufferEXT(GL_FRAMEBUFFER, sizeof(discards) / sizeof(GLenum),
                            discards);

    glBindRenderbuffer(GL_RENDERBUFFER, colorbuffer_);
    return [[EAGLContext currentContext] presentRenderbuffer:GL_RENDERBUFFER];
  }

  GLuint framebuffer() const { return framebuffer_; }

  bool MakeCurrent() {
    return UpdateStorageSizeIfNecessary() &&
           [EAGLContext setCurrentContext:context_.get()];
  }

 private:
  base::scoped_nsobject<CAEAGLLayer> layer_;
  base::scoped_nsobject<EAGLContext> context_;

  GLuint framebuffer_;
  GLuint colorbuffer_;
  GLuint depthbuffer_;
  GLuint stencilbuffer_;
  GLuint depth_stencil_packed_buffer_;

  GLintSize storage_size_;

  bool UpdateStorageSizeIfNecessary() {
    GLintSize size([layer_.get() bounds].size);

    if (size == storage_size_) {
      // Nothing to since the stoage size is already consistent with the layer.
      return true;
    }

    DCHECK(glGetError() == GL_NO_ERROR);

    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer_);

    glBindRenderbuffer(GL_RENDERBUFFER, colorbuffer_);
    DCHECK(glGetError() == GL_NO_ERROR);

    if (![context_.get() renderbufferStorage:GL_RENDERBUFFER
                                fromDrawable:layer_.get()]) {
      return false;
    }

    GLint width = 0;
    GLint height = 0;
    bool rebind_color_buffer = false;

    if (depthbuffer_ != GL_NONE || stencilbuffer_ != GL_NONE ||
        depth_stencil_packed_buffer_ != GL_NONE) {
      // Fetch the dimensions of the color buffer whose backing was just updated
      // so that backing of the attachments can be updated
      glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH,
                                   &width);
      DCHECK(glGetError() == GL_NO_ERROR);

      glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT,
                                   &height);
      DCHECK(glGetError() == GL_NO_ERROR);

      rebind_color_buffer = true;
    }

    if (depth_stencil_packed_buffer_ != GL_NONE) {
      glBindRenderbuffer(GL_RENDERBUFFER, depth_stencil_packed_buffer_);
      glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8_OES, width,
                            height);
      DCHECK(glGetError() == GL_NO_ERROR);
    }

    if (depthbuffer_ != GL_NONE) {
      glBindRenderbuffer(GL_RENDERBUFFER, depthbuffer_);
      glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, width,
                            height);
      DCHECK(glGetError() == GL_NO_ERROR);
    }

    if (stencilbuffer_ != GL_NONE) {
      glBindRenderbuffer(GL_RENDERBUFFER, stencilbuffer_);
      glRenderbufferStorage(GL_RENDERBUFFER, GL_STENCIL_INDEX8, width, height);
      DCHECK(glGetError() == GL_NO_ERROR);
    }

    if (rebind_color_buffer) {
      glBindRenderbuffer(GL_RENDERBUFFER, colorbuffer_);
      DCHECK(glGetError() == GL_NO_ERROR);
    }

    storage_size_ = GLintSize(width, height);
    DCHECK(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE);

    return true;
  }

  DISALLOW_COPY_AND_ASSIGN(IOSGLContext);
};

PlatformView* PlatformView::Create(const Config& config,
                                   SurfaceConfig surface_config) {
  return new PlatformViewIOS(config, surface_config);
}

PlatformViewIOS::PlatformViewIOS(const Config& config,
                                 SurfaceConfig surface_config)
    : PlatformView(config, surface_config), weak_factory_(this) {}

PlatformViewIOS::~PlatformViewIOS() {
  base::mac::ScopedNSAutoreleasePool pool;
  context_ = nullptr;

  weak_factory_.InvalidateWeakPtrs();
}

void PlatformViewIOS::SetEAGLLayer(CAEAGLLayer* layer) {
  base::mac::ScopedNSAutoreleasePool pool;
  context_ = WTF::MakeUnique<IOSGLContext>(surface_config_, layer);
}

base::WeakPtr<sky::shell::PlatformView> PlatformViewIOS::GetWeakViewPtr() {
  return weak_factory_.GetWeakPtr();
}

uint64_t PlatformViewIOS::DefaultFramebuffer() const {
  return context_ != nullptr ? context_->framebuffer() : GL_NONE;
}

bool PlatformViewIOS::ContextMakeCurrent() {
  return context_ != nullptr ? context_->MakeCurrent() : false;
}

bool PlatformViewIOS::SwapBuffers() {
  return context_ != nullptr ? context_->PresentRenderBuffer() : false;
}

}  // namespace shell
}  // namespace sky
