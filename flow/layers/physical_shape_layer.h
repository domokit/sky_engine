// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_FLOW_LAYERS_PHYSICAL_SHAPE_LAYER_H_
#define FLUTTER_FLOW_LAYERS_PHYSICAL_SHAPE_LAYER_H_

#include "flutter/flow/layers/container_layer.h"

namespace flutter {

#if defined(OS_FUCHSIA)
using PhysicalShapeLayerBase = FuchsiaSystemCompositedContainerLayer;
#else
class PhysicalShapeLayerBase : public ElevatedContainerLayer {
 public:
  static bool should_system_composite() { return false; }

  PhysicalShapeLayerBase(SkColor color, float elevation)
    : ElevatedContainerLayer(elevation),
      color_(color) {}

  SkColor color() const { return color_; }

 private:
  SkColor color_;
};
#endif

class PhysicalShapeLayer : public PhysicalShapeLayerBase {
 public:
  static void DrawShadow(SkCanvas* canvas,
                         const SkPath& path,
                         SkColor color,
                         float elevation,
                         bool transparentOccluder,
                         SkScalar dpr);

  PhysicalShapeLayer(SkColor color,
                     SkColor shadow_color,
                     float elevation,
                     const SkPath& path,
                     Clip clip_behavior);
  ~PhysicalShapeLayer() override = default;

  void Preroll(PrerollContext* context, const SkMatrix& matrix) override;
  void Paint(PaintContext& context) const override;

 private:
  SkColor shadow_color_;
  SkPath path_;
  Clip clip_behavior_;
};

}  // namespace flutter

#endif  // FLUTTER_FLOW_LAYERS_PHYSICAL_SHAPE_LAYER_H_
