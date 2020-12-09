// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "flutter/shell/platform/darwin/macos/framework/Source/FlutterOpenGLRenderer.h"
#include "flutter/shell/platform/darwin/macos/framework/Source/FlutterView.h"
#include "flutter/shell/platform/embedder/embedder.h"

#import "flutter/shell/platform/darwin/macos/framework/Source/FlutterEngine_Internal.h"
#import "flutter/shell/platform/darwin/macos/framework/Source/FlutterExternalTextureGL.h"

#pragma mark - Static methods for openGL callbacks that require the engine.

static bool OnMakeCurrent(FlutterEngine* engine) {
  return [engine.openGLRenderer makeCurrent];
}

static bool OnClearCurrent(FlutterEngine* engine) {
  return [engine.openGLRenderer clearCurrent];
}

static bool OnPresent(FlutterEngine* engine) {
  return [engine.openGLRenderer glPresent];
}

static uint32_t OnFBO(FlutterEngine* engine, const FlutterFrameInfo* info) {
  return [engine.openGLRenderer fboForFrameInfo:info];
}

static bool OnMakeResourceCurrent(FlutterEngine* engine) {
  return [engine.openGLRenderer makeResourceCurrent];
}

static bool OnAcquireExternalTexture(FlutterEngine* engine,
                                     int64_t textureIdentifier,
                                     size_t width,
                                     size_t height,
                                     FlutterOpenGLTexture* openGlTexture) {
  return [engine.openGLRenderer populateTextureWithIdentifier:textureIdentifier
                                                openGLTexture:openGlTexture];
}

#pragma mark - FlutterOpenGLRenderer implementation.

@implementation FlutterOpenGLRenderer {
  FlutterView* _flutterView;

  // The context provided to the Flutter engine for rendering to the FlutterView. This is lazily
  // created during initialization of the FlutterView. This is used to render content into the
  // FlutterView.
  NSOpenGLContext* _openGLContext;

  // The context provided to the Flutter engine for resource loading.
  NSOpenGLContext* _resourceContext;

  // A mapping of textureID to internal FlutterExternalTextureGL adapter.
  NSMutableDictionary<NSNumber*, FlutterExternalTextureGL*>* _textures;

  FlutterEngine* _flutterEngine;
}

- (instancetype)initWithFlutterEngine:(FlutterEngine*)flutterEngine {
  self = [super init];
  if (self) {
    _flutterEngine = flutterEngine;
    _textures = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (void)attachToFlutterView:(FlutterView*)view {
  _flutterView = view;
}

- (BOOL)makeCurrent {
  if (!_openGLContext) {
    return false;
  }
  [_openGLContext makeCurrentContext];
  return true;
}

- (BOOL)clearCurrent {
  [NSOpenGLContext clearCurrentContext];
  return true;
}

- (BOOL)glPresent {
  if (!_openGLContext) {
    return false;
  }
  [_flutterView present];
  return true;
}

- (uint32_t)fboForFrameInfo:(const FlutterFrameInfo*)info {
  CGSize size = CGSizeMake(info->size.width, info->size.height);
  return [_flutterView frameBufferIDForSize:size];
}

- (NSOpenGLContext*)resourceContext {
  if (!_resourceContext) {
    NSOpenGLPixelFormatAttribute attributes[] = {
        NSOpenGLPFAColorSize, 24, NSOpenGLPFAAlphaSize, 8, 0,
    };
    NSOpenGLPixelFormat* pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
    _resourceContext = [[NSOpenGLContext alloc] initWithFormat:pixelFormat shareContext:nil];
  }
  return _resourceContext;
}

- (NSOpenGLContext*)openGLContext {
  if (!_openGLContext) {
    NSOpenGLContext* shareContext = [self resourceContext];
    _openGLContext = [[NSOpenGLContext alloc] initWithFormat:shareContext.pixelFormat
                                                shareContext:shareContext];
  }
  return _openGLContext;
}

- (BOOL)makeResourceCurrent {
  [self.resourceContext makeCurrentContext];
  return true;
}

- (void)clearResourceContext {
  _resourceContext = nil;
}

#pragma mark - FlutterTextureRegistrar

- (BOOL)populateTextureWithIdentifier:(int64_t)textureID
                        openGLTexture:(FlutterOpenGLTexture*)openGLTexture {
  return [_textures[@(textureID)] populateTexture:openGLTexture];
}

- (int64_t)registerTexture:(id<FlutterTexture>)texture {
  FlutterExternalTextureGL* externalTexture =
      [[FlutterExternalTextureGL alloc] initWithFlutterTexture:texture];
  int64_t textureID = [externalTexture textureID];
  bool success = [_flutterEngine registerTextureWithID:textureID];
  if (success) {
    _textures[@(textureID)] = externalTexture;
    return textureID;
  } else {
    NSLog(@"Unable to register the texture with id: %lld.", textureID);
    return 0;
  }
}

- (void)textureFrameAvailable:(int64_t)textureID {
  bool success = [_flutterEngine markTextureFrameAvailable:textureID];
  if (success) {
    NSLog(@"Unable to mark texture with id %lld as available.", textureID);
  }
}

- (void)unregisterTexture:(int64_t)textureID {
  bool success = [_flutterEngine unregisterTextureWithID:textureID];
  if (success) {
    [_textures removeObjectForKey:@(textureID)];
  } else {
    NSLog(@"Unable to unregister texture with id: %lld.", textureID);
  }
}

#pragma mark - Private methods

- (FlutterRendererConfig)createRendererConfig {
  const FlutterRendererConfig rendererConfig = {
      .type = kOpenGL,
      .open_gl.struct_size = sizeof(FlutterOpenGLRendererConfig),
      .open_gl.make_current = reinterpret_cast<BoolCallback>(OnMakeCurrent),
      .open_gl.clear_current = reinterpret_cast<BoolCallback>(OnClearCurrent),
      .open_gl.present = reinterpret_cast<BoolCallback>(OnPresent),
      .open_gl.fbo_with_frame_info_callback = reinterpret_cast<UIntFrameInfoCallback>(OnFBO),
      .open_gl.fbo_reset_after_present = true,
      .open_gl.make_resource_current = reinterpret_cast<BoolCallback>(OnMakeResourceCurrent),
      .open_gl.gl_external_texture_frame_callback =
          reinterpret_cast<TextureFrameCallback>(OnAcquireExternalTexture),
  };
  return rendererConfig;
}

@end
