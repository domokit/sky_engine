// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "impeller/renderer/snapshot.h"

#include <optional>

namespace impeller {

std::optional<Rect> Snapshot::GetCoverage() const {
  if (!texture) {
    return std::nullopt;
  }
  return Rect(Size(texture->GetSize())).TransformBounds(transform);
}

std::optional<Matrix> Snapshot::GetUVTransform() const {
  if (!texture || texture->GetSize().IsZero()) {
    return std::nullopt;
  }
  return Matrix::MakeScale(1 / Vector2(texture->GetSize())) *
         transform.Invert();
}

// void foo() {
//   std::vector<Point> data(8);
//   auto points = source_rect.GetPoints();
//   for (auto i = 0u, j = 0u; i < 8; i += 2, j++) {
//     data[i] = points[j];
//     data[i + 1] = effect_transform * ((points[j] - texture_coverage.origin) /
//                                       texture_coverage.size);
//   }

// }

std::optional<std::array<Point, 4>> Snapshot::GetCoverageUVs(
    const Rect& coverage) const {
  auto uv_transform = GetUVTransform();
  if (!uv_transform.has_value()) {
    return std::nullopt;
  }
  return coverage.GetTransformedPoints(uv_transform.value());
}

}  // namespace impeller
