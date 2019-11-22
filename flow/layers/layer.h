// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_FLOW_LAYERS_LAYER_H_
#define FLUTTER_FLOW_LAYERS_LAYER_H_

#include <memory>
#include <vector>

#include "flutter/flow/embedded_views.h"
#include "flutter/flow/instrumentation.h"
#include "flutter/flow/raster_cache.h"
#include "flutter/flow/texture.h"
#include "flutter/fml/build_config.h"
#include "flutter/fml/compiler_specific.h"
#include "flutter/fml/logging.h"
#include "flutter/fml/macros.h"
#include "flutter/fml/trace_event.h"
#include "third_party/skia/include/core/SkCanvas.h"
#include "third_party/skia/include/core/SkColor.h"
#include "third_party/skia/include/core/SkColorFilter.h"
#include "third_party/skia/include/core/SkMatrix.h"
#include "third_party/skia/include/core/SkPath.h"
#include "third_party/skia/include/core/SkPicture.h"
#include "third_party/skia/include/core/SkRRect.h"
#include "third_party/skia/include/core/SkRect.h"
#include "third_party/skia/include/utils/SkNWayCanvas.h"

#if defined(OS_FUCHSIA)

#include "flutter/flow/scene_update_context.h"  //nogncheck
#include "lib/ui/scenic/cpp/resources.h"        //nogncheck
#include "lib/ui/scenic/cpp/session.h"          //nogncheck

#endif  // defined(OS_FUCHSIA)

namespace flutter {

static constexpr SkRect kGiantRect = SkRect::MakeLTRB(-1E9F, -1E9F, 1E9F, 1E9F);

// This should be an exact copy of the Clip enum in painting.dart.
enum Clip { none, hardEdge, antiAlias, antiAliasWithSaveLayer };

class ContainerLayer;

struct PrerollContext {
  RasterCache* raster_cache;
  GrContext* gr_context;
  ExternalViewEmbedder* view_embedder;
  MutatorsStack& mutators_stack;
  SkColorSpace* dst_color_space;
  SkRect cull_rect;

  // The following allows us to paint in the end of subtree preroll
  const Stopwatch& raster_time;
  const Stopwatch& ui_time;
  TextureRegistry& texture_registry;
  const bool checkerboard_offscreen_layers;
  float total_elevation = 0.0f;
  bool has_platform_view = false;
};

// Represents a single composited layer. Created on the UI thread but then
// subquently used on the Rasterizer thread.
class Layer {
 public:
  Layer();
  virtual ~Layer();

  virtual void Preroll(PrerollContext* context, const SkMatrix& matrix);

  struct PaintContext {
    // When splitting the scene into multiple canvases (e.g when embedding
    // a platform view on iOS) during the paint traversal we apply the non leaf
    // flow layers to all canvases, and leaf layers just to the "current"
    // canvas. Applying the non leaf layers to all canvases ensures that when
    // we switch a canvas (when painting a PlatformViewLayer) the next canvas
    // has the exact same state as the current canvas.
    // The internal_nodes_canvas is a SkNWayCanvas which is used by non leaf
    // and applies the operations to all canvases.
    // The leaf_nodes_canvas is the "current" canvas and is used by leaf
    // layers.
    SkCanvas* internal_nodes_canvas;
    SkCanvas* leaf_nodes_canvas;
    GrContext* gr_context;
    ExternalViewEmbedder* view_embedder;
    const Stopwatch& raster_time;
    const Stopwatch& ui_time;
    TextureRegistry& texture_registry;
    const RasterCache* raster_cache;
    const bool checkerboard_offscreen_layers;
  };

  // Calls SkCanvas::saveLayer and restores the layer upon destruction. Also
  // draws a checkerboard over the layer if that is enabled in the PaintContext.
  class AutoSaveLayer {
   public:
    FML_WARN_UNUSED_RESULT static AutoSaveLayer Create(
        const PaintContext& paint_context,
        const SkRect& bounds,
        const SkPaint* paint);

    FML_WARN_UNUSED_RESULT static AutoSaveLayer Create(
        const PaintContext& paint_context,
        const SkCanvas::SaveLayerRec& layer_rec);

    ~AutoSaveLayer();

   private:
    AutoSaveLayer(const PaintContext& paint_context,
                  const SkRect& bounds,
                  const SkPaint* paint);

    AutoSaveLayer(const PaintContext& paint_context,
                  const SkCanvas::SaveLayerRec& layer_rec);

    const PaintContext& paint_context_;
    const SkRect bounds_;
  };

  virtual void Paint(PaintContext& context) const = 0;

#if defined(OS_FUCHSIA)
  // Updates the system composited scene.
  virtual void UpdateScene(SceneUpdateContext& context);
#endif

  ContainerLayer* parent() const { return parent_; }

  void set_parent(ContainerLayer* parent) { parent_ = parent; }

  bool needs_system_composite() const { return needs_system_composite_; }
  void set_needs_system_composite(bool value) {
    needs_system_composite_ = value;
  }

  const SkRect& paint_bounds() const { return paint_bounds_; }

  // This must be set by the time Preroll() returns otherwise the layer will
  // be assumed to have empty paint bounds (paints no content).
  void set_paint_bounds(const SkRect& paint_bounds) {
    paint_bounds_ = paint_bounds;
  }

  bool needs_painting() const { return !paint_bounds_.isEmpty(); }

  // True iff the layer, or some descendant of the layer, performs an
  // operation which depends on (i.e. must read back from) the surface
  // on which it is rendered. This value has no setter as it is computed
  // from other flags and properties on the layer.
  // see Layer::update_screen_readback()
  // see Layer::set_layer_reads_surface()
  // see ContainerLayer::set_renders_to_save_layer()
  // see ContainerLayer::update_child_readback()
  bool tree_reads_surface() { return tree_reads_surface_; }

  uint64_t unique_id() const { return unique_id_; }

 protected:
  virtual bool compute_tree_reads_surface();

  // Compute a new value for tree_reads_surface_ and propagate it to
  // ancestors if it changes.
  void update_screen_readback();

  // True iff the layer itself (not a child or other descendant) performs
  // an operation which must read back from the surface on which it is
  // rendered.
  bool layer_reads_surface() { return layer_reads_surface_; }

  void set_layer_reads_surface(bool reads) {
    if (layer_reads_surface_ != reads) {
      layer_reads_surface_ = reads;
      update_screen_readback();
    }
  }

 private:
  ContainerLayer* parent_;
  bool needs_system_composite_;
  SkRect paint_bounds_;
  uint64_t unique_id_;

  bool tree_reads_surface_;
  bool layer_reads_surface_;

  static uint64_t NextUniqueID();

  FML_DISALLOW_COPY_AND_ASSIGN(Layer);
};

}  // namespace flutter

#endif  // FLUTTER_FLOW_LAYERS_LAYER_H_
