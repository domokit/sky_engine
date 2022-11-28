// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "flutter/shell/platform/darwin/macos/framework/Source/FlutterSurfaceManager_Internal.h"
#import "flutter/shell/platform/darwin/macos/framework/Source/FlutterSurface_Internal.h"

#import <Metal/Metal.h>
#include <algorithm>

// Cached back buffers will be released after kIdleDelay if there is no activity.
static const double kIdleDelay = 1.0;

@interface FlutterBackBufferCache () {
  NSMutableArray<FlutterSurface*>* _surfaces;
}

@end

@implementation FlutterBackBufferCache

- (instancetype)init {
  if (self = [super init]) {
    self->_surfaces = [[NSMutableArray alloc] init];
  }
  return self;
}

- (nullable FlutterSurface*)removeSurfaceForSize:(CGSize)size {
  @synchronized(self) {
    for (FlutterSurface* surface in _surfaces) {
      if (CGSizeEqualToSize(surface.size, size)) {
        // By default ARC doesn't retain enumeration iteration variables.
        FlutterSurface* res = surface;
        [_surfaces removeObject:surface];
        return res;
      }
    }
    return nil;
  }
}

- (void)replaceWith:(nonnull NSArray<FlutterSurface*>*)surfaces {
  @synchronized(self) {
    [_surfaces removeAllObjects];
    [_surfaces addObjectsFromArray:surfaces];
  }

  // performSelector:withObject:afterDelay needs to be performed on RunLoop thread
  [self performSelectorOnMainThread:@selector(reschedule) withObject:nil waitUntilDone:NO];
}

- (NSUInteger)count {
  @synchronized(self) {
    return _surfaces.count;
  }
}

- (void)onIdle {
  @synchronized(self) {
    [_surfaces removeAllObjects];
  }
}

- (void)reschedule {
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(onIdle) object:nil];
  [self performSelector:@selector(onIdle) withObject:nil afterDelay:kIdleDelay];
}

- (void)dealloc {
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(onIdle) object:nil];
}

@end

@implementation FlutterSurfacePresentInfo
@end

@interface FlutterSurfaceManager () {
  id<MTLDevice> _device;
  id<MTLCommandQueue> _commandQueue;
  CALayer* _containingLayer;
  __weak id<FlutterSurfaceManagerDelegate> _delegate;

  // Available (cached) back buffer surfaces. These will be cleared during
  // present and replaced by current frong surfaces.
  FlutterBackBufferCache* _backBufferCache;

  // Surfaces that currently obtained through surfaceForSize waiting to be
  // presented. This is used to keep the surface alive because the non compositor
  // codepath doesn't properly retain the surface.
  NSMutableArray<FlutterSurface*>* _borrowedSurfaces;

  // Surfaces currently used to back visible layers.
  NSMutableArray<FlutterSurface*>* _frontSurfaces;

  // Currently visible layers.
  NSMutableArray<CALayer*>* _layers;
}
@end

@implementation FlutterSurfaceManager

- (instancetype)initWithDevice:(id<MTLDevice>)device
                  commandQueue:(id<MTLCommandQueue>)commandQueue
                         layer:(CALayer*)containingLayer
                      delegate:(__weak id<FlutterSurfaceManagerDelegate>)delegate {
  if (self = [super init]) {
    _device = device;
    _commandQueue = commandQueue;
    _containingLayer = containingLayer;
    _delegate = delegate;

    _backBufferCache = [[FlutterBackBufferCache alloc] init];
    _borrowedSurfaces = [NSMutableArray array];
    _frontSurfaces = [NSMutableArray array];
    _layers = [NSMutableArray array];
  }
  return self;
}

- (FlutterBackBufferCache*)backBufferCache {
  return _backBufferCache;
}

- (NSArray*)borrowedSurfaces {
  return _borrowedSurfaces;
}

- (NSArray*)frontSurfaces {
  return _frontSurfaces;
}

- (NSArray*)layers {
  return _layers;
}

- (FlutterSurface*)lookupSurface:(nonnull const FlutterMetalTexture*)texture {
  for (FlutterSurface* surface in _borrowedSurfaces) {
    if (surface.textureId == texture->texture_id) {
      return surface;
    }
  }
  return nil;
}

- (FlutterSurface*)surfaceForSize:(CGSize)size {
  FlutterSurface* res = [_backBufferCache removeSurfaceForSize:size];
  if (res == nil) {
    res = [[FlutterSurface alloc] initWithSize:size device:_device];
  }
  [_borrowedSurfaces addObject:res];
  return res;
}

- (void)commit:(NSArray<FlutterSurfacePresentInfo*>*)surfaces {
  assert([NSThread isMainThread]);

  [_borrowedSurfaces removeAllObjects];

  // Release all unused back buffer surfaces and replace them with front surfaces.
  [_backBufferCache replaceWith:_frontSurfaces];

  // Front surfaces will be replaced by currently presented surfaces.
  [_frontSurfaces removeAllObjects];
  for (FlutterSurfacePresentInfo* info in surfaces) {
    [_frontSurfaces addObject:info.surface];
  }

  // Remove excess layers.
  while (_layers.count > _frontSurfaces.count) {
    [_layers.lastObject removeFromSuperlayer];
    [_layers removeLastObject];
  }

  // Add missing layers.
  while (_layers.count < _frontSurfaces.count) {
    CALayer* layer = [CALayer layer];
    [_containingLayer addSublayer:layer];
    [_layers addObject:layer];
  }

  // Update contents of surfaces.
  for (size_t i = 0; i < surfaces.count; ++i) {
    FlutterSurfacePresentInfo* info = surfaces[i];
    CALayer* layer = _layers[i];
    CGFloat scale = _containingLayer.contentsScale;
    layer.frame = CGRectMake(info.offset.x / scale, info.offset.y / scale,
                             info.surface.size.width / scale, info.surface.size.height / scale);
    layer.contents = (__bridge id)info.surface.ioSurface;
    layer.zPosition = info.zIndex;
  }
}

- (void)present:(NSArray<FlutterSurfacePresentInfo*>*)surfaces notify:(dispatch_block_t)notify {
  id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
  [commandBuffer commit];
  [commandBuffer waitUntilScheduled];

  // Get the actual dimensions of the frame (relevant for thread synchronizer).
  CGSize size = CGSizeZero;
  for (FlutterSurfacePresentInfo* info in surfaces) {
    size = CGSizeMake(std::max(size.width, info.offset.x + info.surface.size.width),
                      std::max(size.height, info.offset.y + info.surface.size.height));
  }

  [_delegate onPresent:size
             withBlock:^{
               [self commit:surfaces];
               if (notify != nil) {
                 notify();
               }
             }];
}

@end
