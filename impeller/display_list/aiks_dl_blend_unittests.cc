// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <memory>

#include "display_list/display_list.h"
#include "display_list/dl_sampling_options.h"
#include "display_list/dl_tile_mode.h"
#include "display_list/effects/dl_color_filter.h"
#include "display_list/effects/dl_color_source.h"
#include "display_list/effects/dl_mask_filter.h"
#include "flutter/impeller/aiks/aiks_unittests.h"

#include "flutter/display_list/dl_blend_mode.h"
#include "flutter/display_list/dl_builder.h"
#include "flutter/display_list/dl_color.h"
#include "flutter/display_list/dl_paint.h"
#include "flutter/impeller/display_list/dl_image_impeller.h"
#include "flutter/impeller/geometry/scalar.h"
#include "include/core/SkMatrix.h"

////////////////////////////////////////////////////////////////////////////////
// This is for tests of Canvas that are interested the results of rendering
// blends.
////////////////////////////////////////////////////////////////////////////////

namespace impeller {
namespace testing {

using namespace flutter;

#define BLEND_MODE_TUPLE(blend_mode) {#blend_mode, BlendMode::k##blend_mode},

struct BlendModeSelection {
  std::vector<const char*> blend_mode_names;
  std::vector<BlendMode> blend_mode_values;
};

static BlendModeSelection GetBlendModeSelection() {
  std::vector<const char*> blend_mode_names;
  std::vector<BlendMode> blend_mode_values;
  {
    const std::vector<std::tuple<const char*, BlendMode>> blends = {
        IMPELLER_FOR_EACH_BLEND_MODE(BLEND_MODE_TUPLE)};
    assert(blends.size() ==
           static_cast<size_t>(Entity::kLastAdvancedBlendMode) + 1);
    for (const auto& [name, mode] : blends) {
      blend_mode_names.push_back(name);
      blend_mode_values.push_back(mode);
    }
  }

  return {blend_mode_names, blend_mode_values};
}

TEST_P(AiksTest, CanRenderAdvancedBlendColorFilterWithSaveLayer) {
  DisplayListBuilder builder;

  SkRect layer_rect = SkRect::MakeXYWH(0, 0, 500, 500);
  builder.ClipRect(layer_rect);

  DlPaint save_paint;
  save_paint.setColorFilter(DlBlendColorFilter::Make(
      DlColor::RGBA(0, 1, 0, 0.5), DlBlendMode::kDifference));
  builder.SaveLayer(&layer_rect, &save_paint);

  DlPaint paint;
  paint.setColor(DlColor::kBlack());
  builder.DrawPaint(paint);
  paint.setColor(DlColor::kWhite());
  builder.DrawRect(SkRect::MakeXYWH(100, 100, 300, 300), paint);
  builder.Restore();

  ASSERT_TRUE(OpenPlaygroundHere(builder.Build()));
}

TEST_P(AiksTest, BlendModeShouldCoverWholeScreen) {
  DisplayListBuilder builder;
  DlPaint paint;

  paint.setColor(DlColor::kRed());
  builder.DrawPaint(paint);

  paint.setBlendMode(DlBlendMode::kSrcOver);
  builder.SaveLayer(nullptr, &paint);

  paint.setColor(DlColor::kWhite());
  builder.DrawRect(SkRect::MakeXYWH(100, 100, 400, 400), paint);

  paint.setBlendMode(DlBlendMode::kSrc);
  builder.SaveLayer(nullptr, &paint);

  paint.setColor(DlColor::kBlue());
  builder.DrawRect(SkRect::MakeXYWH(200, 200, 200, 200), paint);

  builder.Restore();
  builder.Restore();

  ASSERT_TRUE(OpenPlaygroundHere(builder.Build()));
}

TEST_P(AiksTest, CanDrawPaintWithAdvancedBlend) {
  DisplayListBuilder builder;

  builder.Scale(0.2, 0.2);
  DlPaint paint;
  paint.setColor(DlColor::RGBA(
      Color::MediumTurquoise().red, Color::MediumTurquoise().green,
      Color::MediumTurquoise().blue, Color::MediumTurquoise().alpha));
  builder.DrawPaint(paint);

  paint.setColor(DlColor::RGBA(Color::OrangeRed().red, Color::OrangeRed().green,
                               Color::OrangeRed().blue, 0.5));
  paint.setBlendMode(DlBlendMode::kHue);
  builder.DrawPaint(paint);

  ASSERT_TRUE(OpenPlaygroundHere(builder.Build()));
}

TEST_P(AiksTest, DrawPaintWithAdvancedBlendOverFilter) {
  DlPaint paint;
  paint.setColor(DlColor::kBlack());
  paint.setMaskFilter(DlBlurMaskFilter::Make(DlBlurStyle::kNormal, 60));

  DisplayListBuilder builder;
  paint.setColor(DlColor::kWhite());
  builder.DrawPaint(paint);
  paint.setColor(DlColor::kBlack());
  builder.DrawCircle({300, 300}, 200, paint);
  paint.setColor(DlColor::kGreen());
  paint.setBlendMode(DlBlendMode::kScreen);
  builder.DrawPaint(paint);

  ASSERT_TRUE(OpenPlaygroundHere(builder.Build()));
}

TEST_P(AiksTest, DrawAdvancedBlendPartlyOffscreen) {
  DisplayListBuilder builder;

  DlPaint draw_paint;
  draw_paint.setColor(DlColor::kBlue());
  builder.DrawPaint(draw_paint);
  builder.Scale(2, 2);
  builder.ClipRect(SkRect::MakeLTRB(0, 0, 200, 200));

  std::vector<DlColor> colors = {DlColor::RGBA(0.9568, 0.2627, 0.2118, 1.0),
                                 DlColor::RGBA(0.1294, 0.5882, 0.9529, 1.0)};
  std::vector<Scalar> stops = {0.0, 1.0};

  DlPaint paint;
  SkMatrix matrix = SkMatrix::Scale(0.3, 0.3);
  paint.setColorSource(DlColorSource::MakeLinear(
      /*start_point=*/{0, 0},             //
      /*end_point=*/{100, 100},           //
      /*stop_count=*/colors.size(),       //
      /*colors=*/colors.data(),           //
      /*stops=*/stops.data(),             //
      /*tile_mode=*/DlTileMode::kRepeat,  //
      /*matrix=*/&matrix                  //
      ));
  paint.setBlendMode(DlBlendMode::kLighten);

  builder.DrawCircle({100, 100}, 100, paint);
  ASSERT_TRUE(OpenPlaygroundHere(builder.Build()));
}

TEST_P(AiksTest, PaintBlendModeIsRespected) {
  DlPaint paint;
  DisplayListBuilder builder;
  // Default is kSourceOver.

  paint.setColor(DlColor::RGBA(1, 0, 0, 0.5));
  builder.DrawCircle({150, 200}, 100, paint);

  paint.setColor(DlColor::RGBA(0, 1, 0, 0.5));
  builder.DrawCircle({250, 200}, 100, paint);

  paint.setBlendMode(DlBlendMode::kPlus);

  paint.setColor(DlColor::kRed());
  builder.DrawCircle({450, 250}, 100, paint);

  paint.setColor(DlColor::kGreen());
  builder.DrawCircle({550, 250}, 100, paint);

  paint.setColor(DlColor::kBlue());
  builder.DrawCircle({500, 150}, 100, paint);

  ASSERT_TRUE(OpenPlaygroundHere(builder.Build()));
}

// Bug: https://github.com/flutter/flutter/issues/142549
TEST_P(AiksTest, BlendModePlusAlphaWideGamut) {
  EXPECT_EQ(GetContext()->GetCapabilities()->GetDefaultColorFormat(),
            PixelFormat::kB10G10R10A10XR);
  auto texture = CreateTextureForFixture("airplane.jpg",
                                         /*enable_mipmapping=*/true);

  DisplayListBuilder builder;
  DlPaint paint;
  builder.Scale(GetContentScale().x, GetContentScale().y);

  paint.setColor(DlColor::RGBA(0.9, 1, 0.9, 1.0));
  builder.DrawPaint(paint);
  builder.SaveLayer(nullptr);

  paint.setBlendMode(DlBlendMode::kPlus);
  paint.setColor(DlColor::kRed());

  builder.DrawRect(SkRect::MakeXYWH(100, 100, 400, 400), paint);
  paint.setColor(DlColor::kWhite());

  auto rect = Rect::MakeXYWH(100, 100, 400, 400).Expand(-100, -100);
  builder.DrawImageRect(
      DlImageImpeller::Make(texture),
      SkRect::MakeSize(
          SkSize::Make(texture->GetSize().width, texture->GetSize().height)),
      SkRect::MakeLTRB(rect.GetLeft(), rect.GetTop(), rect.GetRight(),
                       rect.GetBottom()),
      DlImageSampling::kMipmapLinear, &paint);
  builder.Restore();
  ASSERT_TRUE(OpenPlaygroundHere(builder.Build()));
}

// Bug: https://github.com/flutter/flutter/issues/142549
TEST_P(AiksTest, BlendModePlusAlphaColorFilterWideGamut) {
  EXPECT_EQ(GetContext()->GetCapabilities()->GetDefaultColorFormat(),
            PixelFormat::kB10G10R10A10XR);
  auto texture = CreateTextureForFixture("airplane.jpg",
                                         /*enable_mipmapping=*/true);

  DisplayListBuilder builder;
  builder.Scale(GetContentScale().x, GetContentScale().y);

  DlPaint paint;
  paint.setColor(DlColor::RGBA(0.1, 0.2, 0.1, 1.0));
  builder.DrawPaint(paint);

  DlPaint save_paint;
  save_paint.setColorFilter(
      DlBlendColorFilter::Make(DlColor::RGBA(1, 0, 0, 1), DlBlendMode::kPlus));
  builder.SaveLayer(nullptr, &save_paint);

  paint.setColor(DlColor::kRed());
  builder.DrawRect(SkRect::MakeXYWH(100, 100, 400, 400), paint);

  paint.setColor(DlColor::kWhite());

  auto rect = Rect::MakeXYWH(100, 100, 400, 400).Expand(-100, -100);
  builder.DrawImageRect(
      DlImageImpeller::Make(texture),
      SkRect::MakeSize(
          SkSize::Make(texture->GetSize().width, texture->GetSize().height)),
      SkRect::MakeLTRB(rect.GetLeft(), rect.GetTop(), rect.GetRight(),
                       rect.GetBottom()),
      DlImageSampling::kMipmapLinear, &paint);
  builder.Restore();

  ASSERT_TRUE(OpenPlaygroundHere(builder.Build()));
}

TEST_P(AiksTest, ForegroundBlendSubpassCollapseOptimization) {
  DisplayListBuilder builder;

  DlPaint save_paint;
  save_paint.setColorFilter(
      DlBlendColorFilter::Make(DlColor::kRed(), DlBlendMode::kColorDodge));
  builder.SaveLayer(nullptr, &save_paint);

  builder.Translate(500, 300);
  builder.Rotate(120);

  DlPaint paint;
  paint.setColor(DlColor::kBlue());
  builder.DrawRect(SkRect::MakeXYWH(100, 100, 200, 200), paint);

  ASSERT_TRUE(OpenPlaygroundHere(builder.Build()));
}

TEST_P(AiksTest, ClearBlend) {
  DisplayListBuilder builder;

  DlPaint blue;
  blue.setColor(DlColor::kBlue());
  builder.DrawRect(SkRect::MakeXYWH(0, 0, 600.0, 600.0), blue);

  DlPaint clear;
  clear.setBlendMode(DlBlendMode::kClear);

  builder.DrawCircle({300.0, 300.0}, 200.0, clear);

  ASSERT_TRUE(OpenPlaygroundHere(builder.Build()));
}

static sk_sp<DisplayList> BlendModeTest(Vector2 content_scale,
                                        BlendMode blend_mode,
                                        const sk_sp<DlImageImpeller>& src_image,
                                        const sk_sp<DlImageImpeller>& dst_image,
                                        Scalar src_alpha) {
  if (AiksTest::ImGuiBegin("Controls", nullptr,
                           ImGuiWindowFlags_AlwaysAutoResize)) {
    ImGui::SliderFloat("Source alpha", &src_alpha, 0, 1);
    ImGui::End();
  }

  Color destination_color = Color::CornflowerBlue().WithAlpha(0.75);
  auto source_colors = std::vector<Color>({Color::White().WithAlpha(0.75),
                                           Color::LimeGreen().WithAlpha(0.75),
                                           Color::Black().WithAlpha(0.75)});

  DisplayListBuilder builder;
  {
    DlPaint paint;
    paint.setColor(DlColor::kBlack());
    builder.DrawPaint(paint);
  }
  // TODO(bdero): Why does this cause the left image to double scale on high DPI
  //              displays.
  // builder.Scale(content_scale);

  //----------------------------------------------------------------------------
  /// 1. Save layer blending (top squares).
  ///

  builder.Save();
  for (const auto& color : source_colors) {
    builder.Save();
    {
      builder.ClipRect(SkRect::MakeXYWH(25, 25, 100, 100));
      // Perform the blend in a SaveLayer so that the initial backdrop color is
      // fully transparent black. SourceOver blend the result onto the parent
      // pass.
      builder.SaveLayer({});
      {
        DlPaint draw_paint;
        draw_paint.setColor(
            DlColor::RGBA(destination_color.red, destination_color.green,
                          destination_color.blue, destination_color.alpha));
        builder.DrawPaint(draw_paint);

        // Draw the source color in an offscreen pass and blend it to the parent
        // pass.
        DlPaint save_paint;
        save_paint.setBlendMode(static_cast<DlBlendMode>(blend_mode));
        builder.SaveLayer(nullptr, &save_paint);
        {  //
          DlPaint paint;
          paint.setColor(
              DlColor::RGBA(color.red, color.green, color.blue, color.alpha));
          builder.DrawRect(SkRect::MakeXYWH(25, 25, 100, 100), paint);
        }
        builder.Restore();
      }
      builder.Restore();
    }
    builder.Restore();
    builder.Translate(100, 0);
  }
  builder.RestoreToCount(0);

  //----------------------------------------------------------------------------
  /// 2. CPU blend modes (bottom squares).
  ///

  builder.Save();
  builder.Translate(0, 100);
  // Perform the blend in a SaveLayer so that the initial backdrop color is
  // fully transparent black. SourceOver blend the result onto the parent pass.
  builder.SaveLayer({});
  for (const auto& color : source_colors) {
    // Simply write the CPU blended color to the pass.
    DlPaint paint;
    auto dest = destination_color.Blend(color, blend_mode);
    paint.setColor(DlColor::RGBA(dest.red, dest.green, dest.blue, dest.alpha));
    paint.setBlendMode(DlBlendMode::kSrcOver);
    builder.DrawRect(SkRect::MakeXYWH(25, 25, 100, 100), paint);
    builder.Translate(100, 0);
  }
  builder.Restore();
  builder.Restore();

  //----------------------------------------------------------------------------
  /// 3. Image blending (bottom images).
  ///
  /// Compare these results with the images in the Flutter blend mode
  /// documentation: https://api.flutter.dev/flutter/dart-ui/BlendMode.html
  ///

  builder.Translate(0, 250);

  // Draw grid behind the images.
  {
    DlPaint paint;
    paint.setColor(DlColor::RGBA(41 / 255.0, 41 / 255.0, 41 / 255.0, 255));
    builder.DrawRect(SkRect::MakeLTRB(0, 0, 800, 400), paint);
  }

  DlPaint square_paint;
  square_paint.setColor(DlColor::RGBA(15 / 255.0, 15 / 255.0, 15 / 255.0, 1));
  for (int y = 0; y < 400 / 8; y++) {
    for (int x = 0; x < 800 / 16; x++) {
      builder.DrawRect(SkRect::MakeXYWH(x * 16 + (y % 2) * 8, y * 8, 8, 8),
                       square_paint);
    }
  }

  // Uploaded image source (left image).
  DlPaint paint;
  paint.setBlendMode(DlBlendMode::kSrcOver);
  builder.Save();
  builder.SaveLayer(nullptr, &paint);
  {
    builder.DrawImage(dst_image, {0, 0}, DlImageSampling::kMipmapLinear,
                      &paint);

    paint.setColor(DlColor::kWhite().withAlpha(src_alpha * 255));
    paint.setBlendMode(static_cast<DlBlendMode>(blend_mode));
    builder.DrawImage(src_image, {0, 0}, DlImageSampling::kMipmapLinear,
                      &paint);
  }
  builder.Restore();
  builder.Restore();

  // Rendered image source (right image).
  builder.Save();

  DlPaint save_paint;
  builder.SaveLayer(nullptr, &save_paint);
  {
    builder.DrawImage(dst_image, {400, 0}, DlImageSampling::kMipmapLinear,
                      nullptr);

    DlPaint save_paint;
    save_paint.setColor(DlColor::kWhite().withAlpha(src_alpha * 255));
    save_paint.setBlendMode(static_cast<DlBlendMode>(blend_mode));
    builder.SaveLayer(nullptr, &save_paint);
    {
      builder.DrawImage(src_image, {400, 0}, DlImageSampling::kMipmapLinear,
                        nullptr);
    }
    builder.Restore();
  }
  builder.Restore();
  builder.Restore();

  return builder.Build();
}

#define BLEND_MODE_TEST(blend_mode)                                           \
  TEST_P(AiksTest, BlendMode##blend_mode) {                                   \
    auto src_image =                                                          \
        DlImageImpeller::Make(CreateTextureForFixture("blend_mode_src.png")); \
    auto dst_image =                                                          \
        DlImageImpeller::Make(CreateTextureForFixture("blend_mode_dst.png")); \
    auto callback = [&]() -> sk_sp<DisplayList> {                             \
      return BlendModeTest(GetContentScale(), BlendMode::k##blend_mode,       \
                           src_image, dst_image, /*src_alpha=*/1.0);          \
    };                                                                        \
    OpenPlaygroundHere(callback);                                             \
  }
IMPELLER_FOR_EACH_BLEND_MODE(BLEND_MODE_TEST)

#define BLEND_MODE_SRC_ALPHA_TEST(blend_mode)                                 \
  TEST_P(AiksTest, BlendModeSrcAlpha##blend_mode) {                           \
    auto src_image =                                                          \
        DlImageImpeller::Make(CreateTextureForFixture("blend_mode_src.png")); \
    auto dst_image =                                                          \
        DlImageImpeller::Make(CreateTextureForFixture("blend_mode_dst.png")); \
    auto callback = [&]() -> sk_sp<DisplayList> {                             \
      return BlendModeTest(GetContentScale(), BlendMode::k##blend_mode,       \
                           src_image, dst_image, /*src_alpha=*/0.5);          \
    };                                                                        \
    OpenPlaygroundHere(callback);                                             \
  }
IMPELLER_FOR_EACH_BLEND_MODE(BLEND_MODE_SRC_ALPHA_TEST)

TEST_P(AiksTest, CanDrawPaintMultipleTimesInteractive) {
  auto modes = GetBlendModeSelection();

  auto callback = [&]() -> sk_sp<DisplayList> {
    static Color background = Color::MediumTurquoise();
    static Color foreground = Color::Color::OrangeRed().WithAlpha(0.5);
    static int current_blend_index = 3;

    if (AiksTest::ImGuiBegin("Controls", nullptr,
                             ImGuiWindowFlags_AlwaysAutoResize)) {
      ImGui::ColorEdit4("Background", reinterpret_cast<float*>(&background));
      ImGui::ColorEdit4("Foreground", reinterpret_cast<float*>(&foreground));
      ImGui::ListBox("Blend mode", &current_blend_index,
                     modes.blend_mode_names.data(),
                     modes.blend_mode_names.size());
      ImGui::End();
    }

    DisplayListBuilder builder;
    builder.Scale(0.2, 0.2);
    DlPaint paint;
    paint.setColor(DlColor(background.ToARGB()));
    builder.DrawPaint(paint);

    paint.setColor(DlColor(foreground.ToARGB()));
    paint.setBlendMode(static_cast<DlBlendMode>(current_blend_index));
    builder.DrawPaint(paint);
    return builder.Build();
  };
  ASSERT_TRUE(OpenPlaygroundHere(callback));
}

TEST_P(AiksTest, ForegroundPipelineBlendAppliesTransformCorrectly) {
  auto texture = CreateTextureForFixture("airplane.jpg",
                                         /*enable_mipmapping=*/true);

  DisplayListBuilder builder;
  builder.Rotate(30);

  DlPaint image_paint;
  image_paint.setColorFilter(DlBlendColorFilter::Make(
      DlColor::RGBA(255.0f / 255.0f, 165.0f / 255.0f, 0.0f / 255.0f, 1.0f),
      DlBlendMode::kSrcIn));

  builder.DrawImage(DlImageImpeller::Make(texture), {200, 200},
                    DlImageSampling::kMipmapLinear, &image_paint);

  ASSERT_TRUE(OpenPlaygroundHere(builder.Build()));
}

TEST_P(AiksTest, ForegroundAdvancedBlendAppliesTransformCorrectly) {
  auto texture = CreateTextureForFixture("airplane.jpg",
                                         /*enable_mipmapping=*/true);

  DisplayListBuilder builder;
  builder.Rotate(30);

  DlPaint image_paint;
  image_paint.setColorFilter(DlBlendColorFilter::Make(
      DlColor::RGBA(255.0f / 255.0f, 165.0f / 255.0f, 0.0f / 255.0f, 1.0f),
      DlBlendMode::kColorDodge));

  builder.DrawImage(DlImageImpeller::Make(texture), {200, 200},
                    DlImageSampling::kMipmapLinear, &image_paint);

  ASSERT_TRUE(OpenPlaygroundHere(builder.Build()));
}

TEST_P(AiksTest, FramebufferAdvancedBlendCoverage) {
  auto texture = CreateTextureForFixture("airplane.jpg",
                                         /*enable_mipmapping=*/true);

  // Draw with an advanced blend that can use FramebufferBlendContents and
  // verify that the scale transform is correctly applied to the image.
  DisplayListBuilder builder;

  DlPaint paint;
  paint.setColor(
      DlColor::RGBA(169.0f / 255.0f, 169.0f / 255.0f, 169.0f / 255.0f, 1.0f));
  builder.DrawPaint(paint);
  builder.Scale(0.4, 0.4);

  DlPaint image_paint;
  image_paint.setBlendMode(DlBlendMode::kMultiply);

  builder.DrawImage(DlImageImpeller::Make(texture), {20, 20},
                    DlImageSampling::kMipmapLinear, &image_paint);

  ASSERT_TRUE(OpenPlaygroundHere(builder.Build()));
}

}  // namespace testing
}  // namespace impeller
