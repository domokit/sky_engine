// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "flutter/testing/testing.h"
#include "fml/status_or.h"
#include "gmock/gmock.h"
#include "impeller/entity/contents/filters/gaussian_blur_filter_contents.h"
#include "impeller/entity/entity_playground.h"
#include "impeller/geometry/geometry_asserts.h"
#include "impeller/renderer/testing/mocks.h"

namespace impeller {
namespace testing {

namespace {

Scalar CalculateSigmaForBlurRadius(Scalar blur_radius) {
  // See Sigma.h
  return (blur_radius / kKernelRadiusPerSigma) + 0.5;
}

}  // namespace

using GaussianBlurFilterContentsTest = EntityPlayground;
INSTANTIATE_PLAYGROUND_SUITE(GaussianBlurFilterContentsTest);

TEST(GaussianBlurFilterContentsTest, Create) {
  GaussianBlurFilterContents contents;
  ASSERT_EQ(contents.GetSigma(), 0.0);
}

TEST(GaussianBlurFilterContentsTest, CoverageEmpty) {
  GaussianBlurFilterContents contents;
  FilterInput::Vector inputs = {};
  Entity entity;
  std::optional<Rect> coverage =
      contents.GetFilterCoverage(inputs, entity, /*effect_transform=*/Matrix());
  ASSERT_FALSE(coverage.has_value());
}

TEST(GaussianBlurFilterContentsTest, CoverageSimple) {
  GaussianBlurFilterContents contents;
  FilterInput::Vector inputs = {
      FilterInput::Make(Rect::MakeLTRB(10, 10, 110, 110))};
  Entity entity;
  std::optional<Rect> coverage =
      contents.GetFilterCoverage(inputs, entity, /*effect_transform=*/Matrix());
  ASSERT_EQ(coverage, Rect::MakeLTRB(10, 10, 110, 110));
}

TEST(GaussianBlurFilterContentsTest, CoverageWithSigma) {
  Scalar sigma_radius_1 = CalculateSigmaForBlurRadius(1.0);
  GaussianBlurFilterContents contents(/*sigma=*/sigma_radius_1);
  FilterInput::Vector inputs = {
      FilterInput::Make(Rect::MakeLTRB(100, 100, 200, 200))};
  Entity entity;
  std::optional<Rect> coverage =
      contents.GetFilterCoverage(inputs, entity, /*effect_transform=*/Matrix());
  ASSERT_EQ(coverage, Rect::MakeLTRB(99, 99, 201, 201));
}

TEST_P(GaussianBlurFilterContentsTest, CoverageWithTexture) {
  TextureDescriptor desc = {
      .format = PixelFormat::kB8G8R8A8UNormInt,
      .size = ISize(100, 100),
  };
  Scalar sigma_radius_1 = CalculateSigmaForBlurRadius(1.0);
  GaussianBlurFilterContents contents(/*sigma=*/sigma_radius_1);
  std::shared_ptr<Texture> texture =
      GetContentContext()->GetContext()->GetResourceAllocator()->CreateTexture(
          desc);
  FilterInput::Vector inputs = {FilterInput::Make(texture)};
  Entity entity;
  entity.SetTransformation(Matrix::MakeTranslation({100, 100, 0}));
  std::optional<Rect> coverage =
      contents.GetFilterCoverage(inputs, entity, /*effect_transform=*/Matrix());
  ASSERT_EQ(coverage, Rect::MakeLTRB(99, 99, 201, 201));
}

TEST_P(GaussianBlurFilterContentsTest, CoverageWithEffectTransform) {
  TextureDescriptor desc = {
      .format = PixelFormat::kB8G8R8A8UNormInt,
      .size = ISize(100, 100),
  };
  Scalar sigma_radius_1 = CalculateSigmaForBlurRadius(1.0);
  GaussianBlurFilterContents contents(/*sigma=*/sigma_radius_1);
  std::shared_ptr<Texture> texture =
      GetContentContext()->GetContext()->GetResourceAllocator()->CreateTexture(
          desc);
  FilterInput::Vector inputs = {FilterInput::Make(texture)};
  Entity entity;
  entity.SetTransformation(Matrix::MakeTranslation({100, 100, 0}));
  std::optional<Rect> coverage = contents.GetFilterCoverage(
      inputs, entity, /*effect_transform=*/Matrix::MakeScale({2.0, 2.0, 1.0}));
  ASSERT_EQ(coverage, Rect::MakeLTRB(100 - 2, 100 - 2, 200 + 2, 200 + 2));
}

TEST(GaussianBlurFilterContentsTest, FilterSourceCoverage) {
  Scalar sigma_radius_1 = CalculateSigmaForBlurRadius(1.0);
  auto contents = std::make_unique<GaussianBlurFilterContents>(sigma_radius_1);
  std::optional<Rect> coverage = contents->GetFilterSourceCoverage(
      /*effect_transform=*/Matrix::MakeScale({2.0, 2.0, 1.0}),
      /*output_limit=*/Rect::MakeLTRB(100, 100, 200, 200));
  ASSERT_EQ(coverage, Rect::MakeLTRB(100 - 2, 100 - 2, 200 + 2, 200 + 2));
}

TEST_P(GaussianBlurFilterContentsTest, RenderCoverageMatchesGetCoverage) {
  TextureDescriptor desc = {
      .format = PixelFormat::kB8G8R8A8UNormInt,
      .size = ISize(100, 100),
  };
  std::shared_ptr<Texture> texture =
      GetContentContext()->GetContext()->GetResourceAllocator()->CreateTexture(
          desc);
  Scalar sigma_radius_1 = CalculateSigmaForBlurRadius(1.0);
  auto contents = std::make_unique<GaussianBlurFilterContents>(sigma_radius_1);
  contents->SetInputs({FilterInput::Make(texture)});
  std::shared_ptr<ContentContext> renderer = GetContentContext();

  Entity entity;
  std::optional<Entity> result =
      contents->GetEntity(*renderer, entity, /*coverage_hint=*/{});
  EXPECT_TRUE(result.has_value());
  if (result.has_value()) {
    EXPECT_EQ(result.value().GetBlendMode(), BlendMode::kSourceOver);
    std::optional<Rect> result_coverage = result.value().GetCoverage();
    std::optional<Rect> contents_coverage = contents->GetCoverage(entity);
    EXPECT_TRUE(result_coverage.has_value());
    EXPECT_TRUE(contents_coverage.has_value());
    if (result_coverage.has_value() && contents_coverage.has_value()) {
      // TODO(gaaclarke): This test won't pass until the blur_radius is used to
      //                  expand the coverage. See note inside of
      //                  gaussian_blur_filter_contents.cc.
      // EXPECT_TRUE(RectNear(result_coverage.value(),
      //                      contents_coverage.value()));
    }
  }
}

TEST_P(GaussianBlurFilterContentsTest,
       RenderCoverageMatchesGetCoverageTranslate) {
  TextureDescriptor desc = {
      .format = PixelFormat::kB8G8R8A8UNormInt,
      .size = ISize(100, 100),
  };
  std::shared_ptr<Texture> texture =
      GetContentContext()->GetContext()->GetResourceAllocator()->CreateTexture(
          desc);
  Scalar sigma_radius_1 = CalculateSigmaForBlurRadius(1.0);
  auto contents = std::make_unique<GaussianBlurFilterContents>(sigma_radius_1);
  contents->SetInputs({FilterInput::Make(texture)});
  std::shared_ptr<ContentContext> renderer = GetContentContext();

  Entity entity;
  entity.SetTransformation(Matrix::MakeTranslation({100, 200, 0}));
  std::optional<Entity> result =
      contents->GetEntity(*renderer, entity, /*coverage_hint=*/{});
  EXPECT_TRUE(result.has_value());
  if (result.has_value()) {
    EXPECT_EQ(result.value().GetBlendMode(), BlendMode::kSourceOver);
    std::optional<Rect> result_coverage = result.value().GetCoverage();
    std::optional<Rect> contents_coverage = contents->GetCoverage(entity);
    EXPECT_TRUE(result_coverage.has_value());
    EXPECT_TRUE(contents_coverage.has_value());
    if (result_coverage.has_value() && contents_coverage.has_value()) {
      // TODO(gaaclarke): This test won't pass until the blur_radius is used to
      //                  expand the coverage. See note inside of
      //                  gaussian_blur_filter_contents.cc.
      // EXPECT_TRUE(RectNear(result_coverage.value(),
      //                      contents_coverage.value()));
      // EXPECT_TRUE(RectNear(result_coverage.value(),
      //                      Rect::MakeLTRB(99, 199, 201, 301)));
    }
  }
}

}  // namespace testing
}  // namespace impeller
