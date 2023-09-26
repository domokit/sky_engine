// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#pragma once

#include <functional>
#include <memory>
#include <vector>

#include "flutter/fml/macros.h"
#include "impeller/geometry/path.h"
#include "impeller/geometry/point.h"

struct TESStesselator;

namespace impeller {

void DestroyTessellator(TESStesselator* tessellator);

using CTessellator =
    std::unique_ptr<TESStesselator, decltype(&DestroyTessellator)>;

enum class WindingOrder {
  kClockwise,
  kCounterClockwise,
};

//------------------------------------------------------------------------------
/// @brief      A utility that generates triangles of the specified fill type
///             given a polyline. This happens on the CPU.
///
/// @bug        This should just be called a triangulator.
///
class Tessellator {
 public:
  enum class Result {
    kSuccess,
    kInputError,
    kTessellationError,
  };

  Tessellator();

  ~Tessellator();

  /// @brief A callback that returns the results of the tessellation.
  ///
  ///        The index buffer may not be populated, in which case [indices] will
  ///        be nullptr. The [vertices_size] is the size of the vertices array
  ///        and not the number of vertices, which is usually vertices_size / 2.
  ///        In cases where the indices is nullptr, vertex_or_index_count will
  ///        contain the count of indices.
  using BuilderCallback = std::function<bool(const float* vertices,
                                             size_t vertices_size,
                                             const uint16_t* indices,
                                             size_t vertex_or_index_count)>;

  //----------------------------------------------------------------------------
  /// @brief      Generates filled triangles from the polyline. A callback is
  ///             invoked once for the entire tessellation.
  ///
  /// @param[in]  fill_type The fill rule to use when filling.
  /// @param[in]  polyline  The polyline
  /// @param[in]  callback  The callback, return false to indicate failure.
  ///
  /// @return The result status of the tessellation.
  ///
  Tessellator::Result Tessellate(FillType fill_type,
                                 const Path::Polyline& polyline,
                                 const BuilderCallback& callback) const;

 private:
  CTessellator c_tessellator_;

  FML_DISALLOW_COPY_AND_ASSIGN(Tessellator);
};

}  // namespace impeller
