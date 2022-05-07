// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_FLOW_LAYERS_CACHEABLE_LAYER_H_
#define FLUTTER_FLOW_LAYERS_CACHEABLE_LAYER_H_

#include <memory>

#include "flutter/flow/display_list_raster_cache_item.h"
#include "flutter/flow/layer_raster_cache_item.h"
#include "flutter/flow/layers/container_layer.h"
#include "flutter/flow/picture_raster_cache_item.h"
namespace flutter {

class AutoCache {
 public:
  AutoCache(RasterCacheItem* raster_cache_item,
            PrerollContext* context,
            const SkMatrix& matrix);

  ~AutoCache();

 private:
  int current_index_;
  RasterCacheItem* raster_cache_item_ = nullptr;
  PrerollContext* context_ = nullptr;
  const SkMatrix& matrix_;
};

class CacheableContainerLayer : public ContainerLayer {
 public:
  explicit CacheableContainerLayer(int layer_cached_threshold = 1,
                                   bool can_cache_children = false);

  const LayerRasterCacheItem* raster_cache_item() const {
    return layer_raster_cache_item_.get();
  }

 protected:
  std::unique_ptr<LayerRasterCacheItem> layer_raster_cache_item_;
};

}  // namespace flutter

#endif  // FLUTTER_FLOW_LAYERS_CACHEABLE_LAYER_H_
