// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_FLOW_LAYERS_CONTAINER_LAYER_H_
#define FLUTTER_FLOW_LAYERS_CONTAINER_LAYER_H_

#include <vector>
#include "flutter/flow/layers/layer.h"

namespace flow {

class ContainerLayer : public Layer {
 public:
  ContainerLayer();
  ~ContainerLayer() override;

  void Add(std::unique_ptr<Layer> layer);

  void Preroll(PrerollContext* context, const SkMatrix& matrix) override;

  void UpdateScene(SystemCompositorContext& context) override;

  const std::vector<std::unique_ptr<Layer>>& layers() const { return layers_; }

 protected:
  void PrerollChildren(PrerollContext* context,
                       const SkMatrix& child_matrix,
                       SkRect* child_paint_bounds);
  void PaintChildren(PaintContext& context) const;

  void UpdateSceneChildren(SystemCompositorContext& context);

 private:
  std::vector<std::unique_ptr<Layer>> layers_;

  FXL_DISALLOW_COPY_AND_ASSIGN(ContainerLayer);
};

}  // namespace flow

#endif  // FLUTTER_FLOW_LAYERS_CONTAINER_LAYER_H_
