// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_FLOW_RASTER_CACHE_H_
#define FLUTTER_FLOW_RASTER_CACHE_H_

#include <memory>
#include <unordered_map>

#include "flutter/display_list/display_list.h"
#include "flutter/display_list/display_list_complexity.h"
#include "flutter/flow/raster_cache_key.h"
#include "flutter/flow/raster_cache_util.h"
#include "flutter/fml/macros.h"
#include "flutter/fml/memory/weak_ptr.h"
#include "flutter/fml/trace_event.h"
#include "include/core/SkCanvas.h"
#include "include/core/SkMatrix.h"
#include "include/core/SkRect.h"
#include "third_party/skia/include/core/SkImage.h"
#include "third_party/skia/include/core/SkSize.h"

class SkColorSpace;

namespace flutter {

enum class RasterCacheLayerStrategy { kLayer, kLayerChildren };

class RasterCacheResult {
 public:
  RasterCacheResult(sk_sp<SkImage> image,
                    const SkRect& logical_rect,
                    const char* type);

  virtual ~RasterCacheResult() = default;

  virtual void draw(SkCanvas& canvas, const SkPaint* paint) const;

  virtual SkISize image_dimensions() const {
    return image_ ? image_->dimensions() : SkISize::Make(0, 0);
  };

  virtual int64_t image_bytes() const {
    return image_ ? image_->imageInfo().computeMinByteSize() : 0;
  };

 private:
  sk_sp<SkImage> image_;
  SkRect logical_rect_;
  fml::tracing::TraceFlow flow_;
};

class Layer;
class RasterCacheItem;
struct PrerollContext;
struct PaintContext;

struct RasterCacheMetrics {
  /**
   * The number of cache entries with images evicted in this frame.
   */
  size_t eviction_count = 0;

  /**
   * The size of all of the images evicted in this frame.
   */
  size_t eviction_bytes = 0;

  /**
   * The number of cache entries with images used in this frame.
   */
  size_t in_use_count = 0;

  /**
   * The size of all of the images used in this frame.
   */
  size_t in_use_bytes = 0;

  /**
   * The total cache entries that had images during this frame whether
   * they were used in the frame or held memory during the frame and then
   * were evicted after it ended.
   */
  size_t total_count() const { return in_use_count + eviction_count; }

  /**
   * The size of all of the cached images during this frame whether
   * they were used in the frame or held memory during the frame and then
   * were evicted after it ended.
   */
  size_t total_bytes() const { return in_use_bytes + eviction_bytes; }
};

class RasterCache {
 public:
  struct Context {
    GrDirectContext* gr_context;
    const SkColorSpace* dst_color_space;
    const SkMatrix& matrix;
    const SkRect& logical_rect;
    const char* flow_type;
  };

  std::unique_ptr<RasterCacheResult> Rasterize(
      const RasterCache::Context& context,
      const std::function<void(SkCanvas*)>& draw_function) const;

  explicit RasterCache(
      size_t access_threshold = 3,
      size_t picture_and_display_list_cache_limit_per_frame =
          RasterCacheUtil::kDefaultPictureAndDispLayListCacheLimitPerFrame);

  virtual ~RasterCache() = default;

  // Draws this item if it should be rendered from the cache and returns
  // true iff it was successfully drawn. Typically this should only fail
  // if the item was disabled due to conditions discovered during |Preroll|
  // or if the attempt to populate the entry failed due to bounds overflow
  // conditions.
  bool Draw(const RasterCacheKeyID& id,
            SkCanvas& canvas,
            const SkPaint* paint) const;

  bool Touch(const RasterCacheKeyID& id, const SkMatrix& matrix) const;

  bool HasEntry(const RasterCacheKeyID& id, const SkMatrix&) const;

  void PrepareNewFrame();

  void CleanupAfterFrame();

  void Clear();

  void SetCheckboardCacheImages(bool checkerboard);

  const RasterCacheMetrics& picture_metrics() const { return picture_metrics_; }
  const RasterCacheMetrics& layer_metrics() const { return layer_metrics_; }

  size_t GetCachedEntriesCount() const;

  /**
   * Return the number of map entries in the layer cache regardless of whether
   * the entries have been populated with an image.
   */
  size_t GetLayerCachedEntriesCount() const;

  /**
   * Return the number of map entries in the picture caches (SkPicture and
   * DisplayList) regardless of whether the entries have been populated with
   * an image.
   */
  size_t GetPictureCachedEntriesCount() const;

  /**
   * @brief Estimate how much memory is used by picture raster cache entries in
   * bytes, including cache entries in the SkPicture cache and the DisplayList
   * cache.
   *
   * Only SkImage's memory usage is counted as other objects are often much
   * smaller compared to SkImage. SkImageInfo::computeMinByteSize is used to
   * estimate the SkImage memory usage.
   */
  size_t EstimatePictureCacheByteSize() const;

  /**
   * @brief Estimate how much memory is used by layer raster cache entries in
   * bytes.
   *
   * Only SkImage's memory usage is counted as other objects are often much
   * smaller compared to SkImage. SkImageInfo::computeMinByteSize is used to
   * estimate the SkImage memory usage.
   */
  size_t EstimateLayerCacheByteSize() const;

  /**
   * @brief Return the number of frames that a picture must be prepared
   * before it will be cached. If the number is 0, then no picture will
   * ever be cached.
   *
   * If the number is one, then it must be prepared and drawn on 1 frame
   * and it will then be cached on the next frame if it is prepared.
   */
  int access_threshold() const { return access_threshold_; }

  bool GenerateNewCacheInThisFrame() const {
    // Disabling caching when access_threshold is zero is historic behavior.
    return access_threshold_ != 0 && display_list_cached_this_frame_ <
                                         display_list_cache_limit_per_frame_;
  }

  /**
   * @brief The entry which RasterCacheId is generated by RasterCacheKeyID and
   * matrix, that will be used by the current frame. If current frame doesn't
   * have this entry we will create a new entry.
   * @return the number of times the entry has been hit since it was created. If
   * a new entry that will be 1.
   */
  int MarkSeen(const RasterCacheKeyID& id, const SkMatrix& matrix) const;

  bool UpdateCacheEntry(
      const RasterCacheKeyID& id,
      const Context& raster_cache_context,
      const std::function<void(SkCanvas*)>& render_function) const;

 private:
  struct Entry {
    bool used_this_frame = false;
    size_t access_count = 0;
    std::unique_ptr<RasterCacheResult> image;
  };

  void SweepOneCacheAfterFrame(RasterCacheKey::Map<Entry>& cache,
                               RasterCacheMetrics& picture_metrics,
                               RasterCacheMetrics& layer_metrics);

  const size_t access_threshold_;
  const size_t display_list_cache_limit_per_frame_;
  mutable size_t display_list_cached_this_frame_ = 0;
  RasterCacheMetrics layer_metrics_;
  RasterCacheMetrics picture_metrics_;
  mutable RasterCacheKey::Map<Entry> cache_;
  bool checkerboard_images_;

  void TraceStatsToTimeline() const;

  friend class RasterCacheItem;
  friend class LayerRasterCacheItem;

  FML_DISALLOW_COPY_AND_ASSIGN(RasterCache);
};

}  // namespace flutter

#endif  // FLUTTER_FLOW_RASTER_CACHE_H_
