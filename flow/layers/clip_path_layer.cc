// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "flutter/flow/layers/clip_path_layer.h"

#if defined(OS_FUCHSIA)

#include "lib/ui/scenic/fidl_helpers.h"  // nogncheck

#endif  // defined(OS_FUCHSIA)

namespace flow {

ClipPathLayer::ClipPathLayer() {
  set_needs_system_composite(true);
}

ClipPathLayer::~ClipPathLayer() = default;

SkIRect ClipPathLayer::OnPreroll(PrerollContext* context,
                                 const SkMatrix& matrix,
                                 const SkIRect& device_clip) {
  SkIRect new_device_clip = ComputeDeviceIRect(matrix, clip_path_.getBounds());
  IntersectOrSetEmpty(new_device_clip, device_clip);

  SkRect child_paint_bounds = SkRect::MakeEmpty();
  PrerollChildren(context, matrix, &child_paint_bounds, new_device_clip);
  if (child_paint_bounds.intersect(clip_path_.getBounds())) {
    set_paint_bounds(child_paint_bounds);
  }

  return new_device_clip;
}

#if defined(OS_FUCHSIA)

void ClipPathLayer::UpdateScene(SceneUpdateContext& context) {
  FXL_DCHECK(needs_system_composite());

  // TODO(MZ-140): Must be able to specify paths as shapes to nodes.
  //               Treating the shape as a rectangle for now.
  auto bounds = clip_path_.getBounds();
  scenic_lib::Rectangle shape(context.session(),  // session
                              bounds.width(),     //  width
                              bounds.height()     //  height
  );

  SceneUpdateContext::Clip clip(context, shape, bounds);
  UpdateSceneChildren(context);
}

#endif  // defined(OS_FUCHSIA)

void ClipPathLayer::Paint(PaintContext& context) const {
  TRACE_EVENT0("flutter", "ClipPathLayer::Paint");
  FXL_DCHECK(needs_painting());

  SkAutoCanvasRestore save(&context.canvas, true);
  context.canvas.clipPath(clip_path_, true);
  PaintChildren(context);
}

}  // namespace flow
