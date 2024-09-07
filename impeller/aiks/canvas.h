// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_IMPELLER_AIKS_CANVAS_H_
#define FLUTTER_IMPELLER_AIKS_CANVAS_H_

#include <deque>
#include <functional>
#include <memory>
#include <optional>
#include <vector>

#include "impeller/aiks/image_filter.h"
#include "impeller/aiks/paint.h"
#include "impeller/core/sampler_descriptor.h"
#include "impeller/entity/entity.h"
#include "impeller/entity/geometry/geometry.h"
#include "impeller/entity/geometry/vertices_geometry.h"
#include "impeller/geometry/matrix.h"
#include "impeller/geometry/path.h"
#include "impeller/geometry/point.h"
#include "impeller/geometry/vector.h"
#include "impeller/typographer/text_frame.h"

namespace impeller {

struct CanvasStackEntry {
  Matrix transform;
  uint32_t clip_depth = 0u;
  size_t clip_height = 0u;
  // The number of clips tracked for this canvas stack entry.
  size_t num_clips = 0u;
  Scalar distributed_opacity = 1.0f;
  Entity::RenderingMode rendering_mode = Entity::RenderingMode::kDirect;
  // Whether all entities in the current save should be skipped.
  bool skipping = false;
  // Whether subpass coverage was rounded out to pixel coverage, or if false
  // truncated.
  bool did_round_out = false;
};

enum class PointStyle {
  /// @brief Points are drawn as squares.
  kRound,

  /// @brief Points are drawn as circles.
  kSquare,
};

/// Controls the behavior of the source rectangle given to DrawImageRect.
enum class SourceRectConstraint {
  /// @brief Faster, but may sample outside the bounds of the source rectangle.
  kFast,

  /// @brief Sample only within the source rectangle. May be slower.
  kStrict,
};

/// Specifies how much to trust the bounds rectangle provided for a list
/// of contents. Used by both |EntityPass| and |Canvas::SaveLayer|.
enum class ContentBoundsPromise {
  /// @brief The caller makes no claims related to the size of the bounds.
  kUnknown,

  /// @brief The caller claims the bounds are a reasonably tight estimate
  ///        of the coverage of the contents and should contain all of the
  ///        contents.
  kContainsContents,

  /// @brief The caller claims the bounds are a subset of an estimate of
  ///        the reasonably tight bounds but likely clips off some of the
  ///        contents.
  kMayClipContents,
};

class Canvas {
 public:
  static constexpr uint32_t kMaxDepth = 1 << 24;

  using BackdropFilterProc = std::function<std::shared_ptr<FilterContents>(
      FilterInput::Ref,
      const Matrix& effect_transform,
      Entity::RenderingMode rendering_mode)>;

  Canvas();

  explicit Canvas(Rect cull_rect);

  explicit Canvas(IRect cull_rect);

  virtual ~Canvas();

  virtual void Save(uint32_t total_content_depth = kMaxDepth) = 0;

  virtual void SaveLayer(
      const Paint& paint,
      std::optional<Rect> bounds = std::nullopt,
      const std::shared_ptr<ImageFilter>& backdrop_filter = nullptr,
      ContentBoundsPromise bounds_promise = ContentBoundsPromise::kUnknown,
      uint32_t total_content_depth = kMaxDepth,
      bool can_distribute_opacity = false) = 0;

  virtual bool Restore() = 0;

  size_t GetSaveCount() const;

  void RestoreToCount(size_t count);

  const Matrix& GetCurrentTransform() const;

  void ResetTransform();

  void Transform(const Matrix& transform);

  void Concat(const Matrix& transform);

  void PreConcat(const Matrix& transform);

  void Translate(const Vector3& offset);

  void Scale(const Vector2& scale);

  void Scale(const Vector3& scale);

  void Skew(Scalar sx, Scalar sy);

  void Rotate(Radians radians);

  void DrawPath(const Path& path, const Paint& paint);

  void DrawPaint(const Paint& paint);

  void DrawLine(const Point& p0, const Point& p1, const Paint& paint);

  void DrawRect(const Rect& rect, const Paint& paint);

  void DrawOval(const Rect& rect, const Paint& paint);

  void DrawRRect(const Rect& rect,
                 const Size& corner_radii,
                 const Paint& paint);

  void DrawCircle(const Point& center, Scalar radius, const Paint& paint);

  void DrawPoints(std::vector<Point> points,
                  Scalar radius,
                  const Paint& paint,
                  PointStyle point_style);

  void DrawImage(const std::shared_ptr<Texture>& image,
                 Point offset,
                 const Paint& paint,
                 SamplerDescriptor sampler = {});

  void DrawImageRect(
      const std::shared_ptr<Texture>& image,
      Rect source,
      Rect dest,
      const Paint& paint,
      SamplerDescriptor sampler = {},
      SourceRectConstraint src_rect_constraint = SourceRectConstraint::kFast);

  void ClipPath(
      const Path& path,
      Entity::ClipOperation clip_op = Entity::ClipOperation::kIntersect);

  void ClipRect(
      const Rect& rect,
      Entity::ClipOperation clip_op = Entity::ClipOperation::kIntersect);

  void ClipOval(
      const Rect& bounds,
      Entity::ClipOperation clip_op = Entity::ClipOperation::kIntersect);

  void ClipRRect(
      const Rect& rect,
      const Size& corner_radii,
      Entity::ClipOperation clip_op = Entity::ClipOperation::kIntersect);

  virtual void DrawTextFrame(const std::shared_ptr<TextFrame>& text_frame,
                             Point position,
                             const Paint& paint) = 0;

  void DrawVertices(const std::shared_ptr<VerticesGeometry>& vertices,
                    BlendMode blend_mode,
                    const Paint& paint);

  void DrawAtlas(const std::shared_ptr<Texture>& atlas,
                 std::vector<Matrix> transforms,
                 std::vector<Rect> texture_coordinates,
                 std::vector<Color> colors,
                 BlendMode blend_mode,
                 SamplerDescriptor sampler,
                 std::optional<Rect> cull_rect,
                 const Paint& paint);

  uint64_t GetOpDepth() const { return current_depth_; }
  uint64_t GetMaxOpDepth() const { return transform_stack_.back().clip_depth; }

 protected:
  std::deque<CanvasStackEntry> transform_stack_;
  std::optional<Rect> initial_cull_rect_;
  uint64_t current_depth_ = 0u;

  size_t GetClipHeight() const;

  void Initialize(std::optional<Rect> cull_rect);

  void Reset();

 private:
  virtual void AddRenderEntityToCurrentPass(Entity entity,
                                            bool reuse_depth = false) = 0;
  virtual void AddClipEntityToCurrentPass(Entity entity) = 0;

  void ClipGeometry(const std::shared_ptr<Geometry>& geometry,
                    Entity::ClipOperation clip_op);

  void RestoreClip();

  bool AttemptDrawBlurredRRect(const Rect& rect,
                               Size corner_radii,
                               const Paint& paint);

  Canvas(const Canvas&) = delete;

  Canvas& operator=(const Canvas&) = delete;
};

}  // namespace impeller

#endif  // FLUTTER_IMPELLER_AIKS_CANVAS_H_
