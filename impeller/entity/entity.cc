// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "impeller/entity/entity.h"

#include "impeller/base/validation.h"
#include "impeller/entity/contents/content_context.h"
#include "impeller/renderer/render_pass.h"

namespace impeller {

Entity::Entity() = default;

Entity::~Entity() = default;

const Matrix& Entity::GetTransformation() const {
  return transformation_;
}

void Entity::SetTransformation(const Matrix& transformation) {
  transformation_ = transformation;
}

const Path& Entity::GetPath() const {
  return path_;
}

void Entity::SetPath(Path path) {
  path_ = std::move(path);
}

Rect Entity::GetTransformedPathBounds() const {
  auto points = GetPath().GetBoundingBox()->GetPoints();

  const auto& transform = GetTransformation();
  for (uint i = 0; i < points.size(); i++) {
    points[i] = transform * points[i];
  }
  return Rect::MakePointBounds({points.begin(), points.end()});
}

void Entity::SetAddsToCoverage(bool adds) {
  adds_to_coverage_ = adds;
}

bool Entity::AddsToCoverage() const {
  return adds_to_coverage_;
}

std::optional<Rect> Entity::GetCoverage() const {
  if (!adds_to_coverage_ || !contents_) {
    return std::nullopt;
  }

  return contents_->GetBounds(*this);
}

void Entity::SetContents(std::shared_ptr<Contents> contents) {
  contents_ = std::move(contents);
}

const std::shared_ptr<Contents>& Entity::GetContents() const {
  return contents_;
}

void Entity::SetStencilDepth(uint32_t depth) {
  stencil_depth_ = depth;
}

uint32_t Entity::GetStencilDepth() const {
  return stencil_depth_;
}

void Entity::IncrementStencilDepth(uint32_t increment) {
  stencil_depth_ += increment;
}

void Entity::SetBlendMode(BlendMode blend_mode) {
  if (blend_mode_ > BlendMode::kLastPipelineBlendMode) {
    VALIDATION_LOG << "Non-pipeline blend modes are not supported by the "
                      "entity blend mode setting.";
  }
  blend_mode_ = blend_mode;
}

Entity::BlendMode Entity::GetBlendMode() const {
  return blend_mode_;
}

bool Entity::Render(const ContentContext& renderer,
                    RenderPass& parent_pass) const {
  if (!contents_) {
    return true;
  }

  return contents_->Render(renderer, *this, parent_pass);
}

}  // namespace impeller
