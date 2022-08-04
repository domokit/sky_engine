// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "impeller/entity/entity.h"

#include <optional>

#include "impeller/base/validation.h"
#include "impeller/entity/contents/content_context.h"
#include "impeller/entity/contents/filters/filter_contents.h"
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

  return contents_->GetCoverage(*this);
}

bool Entity::ShouldRender(const ISize& target_size) const {
  if (cover_whole_screen_) {
    return true;
  }
  return contents_->ShouldRender(*this, target_size);
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
  blend_mode_ = blend_mode;
  cover_whole_screen_ = BlendModeShouldCoverWholeScreen(blend_mode);
}

bool Entity::CoverWholeScreen() const {
  return cover_whole_screen_;
}

Entity::BlendMode Entity::GetBlendMode() const {
  return blend_mode_;
}

bool Entity::BlendModeShouldCoverWholeScreen(BlendMode blend_mode) {
  switch (blend_mode) {
    case BlendMode::kClear:
    case BlendMode::kSource:
    case BlendMode::kSourceIn:
    case BlendMode::kDestinationIn:
    case BlendMode::kSourceOut:
    case BlendMode::kDestinationOut:
    case BlendMode::kDestinationATop:
    case BlendMode::kXor:
    case BlendMode::kModulate:
      return true;
    default:
      return false;
  }
}

bool Entity::Render(const ContentContext& renderer,
                    RenderPass& parent_pass) const {
  if (!contents_) {
    return true;
  }

  return contents_->Render(renderer, *this, parent_pass);
}

}  // namespace impeller
