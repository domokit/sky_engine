// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#pragma once

#include "impeller/entity/geometry/geometry.h"

namespace impeller {

struct PositionColorBufferResult {
  BufferView index_buffer;
  BufferView position_buffer;
  BufferView color_buffer;

  PrimitiveType type;
  size_t vertex_count;
  IndexType index_type;
  Matrix transform;
};

/// @brief A geometry that is created from a vertices object.
class VerticesGeometry : public Geometry {
 public:
  virtual PositionColorBufferResult GetPositionColorBuffer(
      const ContentContext& renderer,
      const Entity& entity,
      RenderPass& pass) = 0;

  virtual bool HasVertexColors() const = 0;

  virtual bool HasTextureCoordinates() const = 0;

  virtual std::optional<Rect> GetTextureCoordinateCoverge() const = 0;
};

}  // namespace impeller
