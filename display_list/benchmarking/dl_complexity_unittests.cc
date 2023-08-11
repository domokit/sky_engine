// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "flutter/display_list/benchmarking/dl_complexity.h"
#include "flutter/display_list/benchmarking/dl_complexity_gl.h"
#include "flutter/display_list/benchmarking/dl_complexity_metal.h"
#include "flutter/display_list/display_list.h"
#include "flutter/display_list/dl_builder.h"
#include "flutter/display_list/dl_sampling_options.h"
#include "flutter/display_list/testing/dl_test_snippets.h"
#include "flutter/testing/testing.h"

#include "third_party/skia/include/core/SkBitmap.h"
#include "third_party/skia/include/core/SkImage.h"

namespace flutter {
namespace testing {

namespace {

std::vector<DisplayListComplexityCalculator*> Calculators() {
  return {DisplayListMetalComplexityCalculator::GetInstance(),
          DisplayListGLComplexityCalculator::GetInstance(),
          DisplayListNaiveComplexityCalculator::GetInstance()};
}

std::vector<DisplayListComplexityCalculator*> AccumulatorCalculators() {
  return {DisplayListMetalComplexityCalculator::GetInstance(),
          DisplayListGLComplexityCalculator::GetInstance()};
}

std::vector<DlFPoint> GetTestPoints() {
  std::vector<DlFPoint> points;
  points.push_back(DlFPoint(0, 0));
  points.push_back(DlFPoint(10, 0));
  points.push_back(DlFPoint(10, 10));
  points.push_back(DlFPoint(20, 10));
  points.push_back(DlFPoint(20, 20));

  return points;
}

}  // namespace

TEST(DisplayListComplexity, EmptyDisplayList) {
  auto display_list = GetSampleDisplayList(0);

  auto calculators = Calculators();
  for (auto calculator : calculators) {
    ASSERT_EQ(calculator->Compute(display_list.get()), 0u);
  }
}

TEST(DisplayListComplexity, DisplayListCeiling) {
  auto display_list = GetSampleDisplayList();

  auto calculators = AccumulatorCalculators();
  for (auto calculator : calculators) {
    calculator->SetComplexityCeiling(10u);
    ASSERT_EQ(calculator->Compute(display_list.get()), 10u);
    calculator->SetComplexityCeiling(std::numeric_limits<unsigned int>::max());
  }
}

TEST(DisplayListComplexity, NestedDisplayList) {
  auto display_list = GetSampleNestedDisplayList();

  auto calculators = Calculators();
  for (auto calculator : calculators) {
    // There's only one draw call in the "outer" DisplayList, which calls
    // drawDisplayList with the "inner" DisplayList. To ensure we are
    // recursing correctly into the inner DisplayList, check that we aren't
    // returning 0 (if the function is a no-op) or 1 (as the op_count is 1)
    ASSERT_GT(calculator->Compute(display_list.get()), 1u);
  }
}

TEST(DisplayListComplexity, AntiAliasing) {
  DisplayListBuilder builder_no_aa;
  builder_no_aa.DrawLine(DlFPoint(0, 0), DlFPoint(100, 100),
                         DlPaint());
  auto display_list_no_aa = builder_no_aa.Build();

  DisplayListBuilder builder_aa;
  builder_aa.DrawLine(DlFPoint(0, 0), DlFPoint(100, 100),
                      DlPaint().setAntiAlias(true));
  auto display_list_aa = builder_aa.Build();

  auto calculators = AccumulatorCalculators();
  for (auto calculator : calculators) {
    ASSERT_NE(calculator->Compute(display_list_no_aa.get()),
              calculator->Compute(display_list_aa.get()));
  }
}

TEST(DisplayListComplexity, StrokeWidth) {
  DisplayListBuilder builder_stroke_0;
  builder_stroke_0.DrawLine(DlFPoint(0, 0), DlFPoint(100, 100),
                            DlPaint().setStrokeWidth(0.0f));
  auto display_list_stroke_0 = builder_stroke_0.Build();

  DisplayListBuilder builder_stroke_1;
  builder_stroke_0.DrawLine(DlFPoint(0, 0), DlFPoint(100, 100),
                            DlPaint().setStrokeWidth(1.0f));
  auto display_list_stroke_1 = builder_stroke_1.Build();

  auto calculators = AccumulatorCalculators();
  for (auto calculator : calculators) {
    ASSERT_NE(calculator->Compute(display_list_stroke_0.get()),
              calculator->Compute(display_list_stroke_1.get()));
  }
}

TEST(DisplayListComplexity, Style) {
  DisplayListBuilder builder_filled;
  builder_filled.DrawRect(DlFRect::MakeXYWH(10, 10, 80, 80),
                          DlPaint().setDrawStyle(DlDrawStyle::kFill));
  auto display_list_filled = builder_filled.Build();

  DisplayListBuilder builder_stroked;
  builder_stroked.DrawRect(DlFRect::MakeXYWH(10, 10, 80, 80),
                           DlPaint().setDrawStyle(DlDrawStyle::kStroke));
  auto display_list_stroked = builder_stroked.Build();

  auto calculators = AccumulatorCalculators();
  for (auto calculator : calculators) {
    ASSERT_NE(calculator->Compute(display_list_filled.get()),
              calculator->Compute(display_list_stroked.get()));
  }
}

TEST(DisplayListComplexity, SaveLayers) {
  DisplayListBuilder builder;
  builder.SaveLayer(nullptr, nullptr);
  auto display_list = builder.Build();

  auto calculators = AccumulatorCalculators();
  for (auto calculator : calculators) {
    ASSERT_NE(calculator->Compute(display_list.get()), 0u);
  }
}

TEST(DisplayListComplexity, DrawPath) {
  DisplayListBuilder builder_line;
  DlPath line_path;
  line_path.MoveTo(0, 0);
  line_path.LineTo(10, 10);
  line_path.Close();
  builder_line.DrawPath(line_path, DlPaint());
  auto display_list_line = builder_line.Build();

  DisplayListBuilder builder_quad;
  DlPath quad_path;
  quad_path.MoveTo(0, 0);
  quad_path.QuadTo(10, 10, 10, 20);
  quad_path.Close();
  builder_quad.DrawPath(quad_path, DlPaint());
  auto display_list_quad = builder_quad.Build();

  DisplayListBuilder builder_conic;
  DlPath conic_path;
  conic_path.MoveTo(0, 0);
  conic_path.ConicTo(10, 10, 10, 20, 1.5f);
  conic_path.Close();
  builder_conic.DrawPath(conic_path, DlPaint());
  auto display_list_conic = builder_conic.Build();

  DisplayListBuilder builder_cubic;
  DlPath cubic_path;
  cubic_path.MoveTo(0, 0);
  cubic_path.CubicTo(10, 10, 10, 20, 20, 20);
  builder_cubic.DrawPath(cubic_path, DlPaint());
  auto display_list_cubic = builder_cubic.Build();

  auto calculators = AccumulatorCalculators();
  for (auto calculator : calculators) {
    ASSERT_NE(calculator->Compute(display_list_line.get()), 0u);
    ASSERT_NE(calculator->Compute(display_list_quad.get()), 0u);
    ASSERT_NE(calculator->Compute(display_list_conic.get()), 0u);
    ASSERT_NE(calculator->Compute(display_list_cubic.get()), 0u);
  }
}

TEST(DisplayListComplexity, DrawShadow) {
  DisplayListBuilder builder_line;
  DlPath line_path;
  line_path.MoveTo(0, 0);
  line_path.LineTo(10, 10);
  line_path.Close();
  builder_line.DrawShadow(line_path, SK_ColorRED, 10.0f, false, 1.0f);
  auto display_list_line = builder_line.Build();

  DisplayListBuilder builder_quad;
  DlPath quad_path;
  quad_path.MoveTo(0, 0);
  quad_path.QuadTo(10, 10, 10, 20);
  quad_path.Close();
  builder_quad.DrawShadow(quad_path, SK_ColorRED, 10.0f, false, 1.0f);
  auto display_list_quad = builder_quad.Build();

  DisplayListBuilder builder_conic;
  DlPath conic_path;
  conic_path.MoveTo(0, 0);
  conic_path.ConicTo(10, 10, 10, 20, 1.5f);
  conic_path.Close();
  builder_conic.DrawShadow(conic_path, SK_ColorRED, 10.0f, false, 1.0f);
  auto display_list_conic = builder_conic.Build();

  DisplayListBuilder builder_cubic;
  DlPath cubic_path;
  cubic_path.MoveTo(0, 0);
  cubic_path.CubicTo(10, 10, 10, 20, 20, 20);
  builder_cubic.DrawShadow(cubic_path, SK_ColorRED, 10.0f, false, 1.0f);
  auto display_list_cubic = builder_cubic.Build();

  auto calculators = AccumulatorCalculators();
  for (auto calculator : calculators) {
    ASSERT_NE(calculator->Compute(display_list_line.get()), 0u);
    ASSERT_NE(calculator->Compute(display_list_quad.get()), 0u);
    ASSERT_NE(calculator->Compute(display_list_conic.get()), 0u);
    ASSERT_NE(calculator->Compute(display_list_cubic.get()), 0u);
  }
}

TEST(DisplayListComplexity, DrawOval) {
  DisplayListBuilder builder;
  builder.DrawOval(DlFRect::MakeXYWH(10, 10, 100, 80), DlPaint());
  auto display_list = builder.Build();

  auto calculators = AccumulatorCalculators();
  for (auto calculator : calculators) {
    ASSERT_NE(calculator->Compute(display_list.get()), 0u);
  }
}

TEST(DisplayListComplexity, DrawCircle) {
  DisplayListBuilder builder;
  builder.DrawCircle(DlFPoint(50, 50), 10.0f, DlPaint());
  auto display_list = builder.Build();

  auto calculators = AccumulatorCalculators();
  for (auto calculator : calculators) {
    ASSERT_NE(calculator->Compute(display_list.get()), 0u);
  }
}

TEST(DisplayListComplexity, DrawRRect) {
  DisplayListBuilder builder;
  builder.DrawRRect(
      DlFRRect::MakeRectXY(DlFRect::MakeXYWH(10, 10, 80, 80), 2.0f, 3.0f),
      DlPaint());
  auto display_list = builder.Build();

  auto calculators = AccumulatorCalculators();
  for (auto calculator : calculators) {
    ASSERT_NE(calculator->Compute(display_list.get()), 0u);
  }
}

TEST(DisplayListComplexity, DrawDRRect) {
  DisplayListBuilder builder;
  DlFRRect outer =
      DlFRRect::MakeRectXY(DlFRect::MakeXYWH(10, 10, 80, 80), 2.0f, 3.0f);
  DlFRRect inner =
      DlFRRect::MakeRectXY(DlFRect::MakeXYWH(15, 15, 70, 70), 1.5f, 1.5f);
  builder.DrawDRRect(outer, inner, DlPaint());
  auto display_list = builder.Build();

  auto calculators = AccumulatorCalculators();
  for (auto calculator : calculators) {
    ASSERT_NE(calculator->Compute(display_list.get()), 0u);
  }
}

TEST(DisplayListComplexity, DrawArc) {
  DisplayListBuilder builder;
  builder.DrawArc(DlFRect::MakeXYWH(10, 10, 100, 80), 0.0f, 10.0f, true,
                  DlPaint());
  auto display_list = builder.Build();

  auto calculators = AccumulatorCalculators();
  for (auto calculator : calculators) {
    ASSERT_NE(calculator->Compute(display_list.get()), 0u);
  }
}

TEST(DisplayListComplexity, DrawVertices) {
  auto points = GetTestPoints();
  auto vertices = DlVertices::Make(DlVertexMode::kTriangles, points.size(),
                                   points.data(), nullptr, nullptr);
  DisplayListBuilder builder;
  builder.DrawVertices(vertices.get(), DlBlendMode::kSrc, DlPaint());
  auto display_list = builder.Build();

  auto calculators = AccumulatorCalculators();
  for (auto calculator : calculators) {
    ASSERT_NE(calculator->Compute(display_list.get()), 0u);
  }
}

TEST(DisplayListComplexity, DrawTextBlob) {
  auto text_blob = SkTextBlob::MakeFromString(
      "The quick brown fox jumps over the lazy dog.", SkFont());

  DisplayListBuilder builder;
  builder.DrawTextBlob(text_blob, 0.0f, 0.0f, DlPaint());
  auto display_list = builder.Build();

  DisplayListBuilder builder_multiple;
  builder_multiple.DrawTextBlob(text_blob, 0.0f, 0.0f, DlPaint());
  builder_multiple.DrawTextBlob(text_blob, 0.0f, 0.0f, DlPaint());
  auto display_list_multiple = builder_multiple.Build();

  auto calculators = AccumulatorCalculators();
  for (auto calculator : calculators) {
    ASSERT_NE(calculator->Compute(display_list.get()), 0u);
    ASSERT_GT(calculator->Compute(display_list_multiple.get()),
              calculator->Compute(display_list.get()));
  }
}

TEST(DisplayListComplexity, DrawPoints) {
  auto points = GetTestPoints();
  DisplayListBuilder builder_lines;
  builder_lines.DrawPoints(DlCanvas::PointMode::kLines, points.size(),
                           points.data(), DlPaint());
  auto display_list_lines = builder_lines.Build();

  DisplayListBuilder builder_points;
  builder_points.DrawPoints(DlCanvas::PointMode::kPoints, points.size(),
                            points.data(), DlPaint());
  auto display_list_points = builder_points.Build();

  DisplayListBuilder builder_polygon;
  builder_polygon.DrawPoints(DlCanvas::PointMode::kPolygon, points.size(),
                             points.data(), DlPaint());
  auto display_list_polygon = builder_polygon.Build();

  auto calculators = AccumulatorCalculators();
  for (auto calculator : calculators) {
    ASSERT_NE(calculator->Compute(display_list_lines.get()), 0u);
    ASSERT_NE(calculator->Compute(display_list_points.get()), 0u);
    ASSERT_NE(calculator->Compute(display_list_polygon.get()), 0u);
  }
}

TEST(DisplayListComplexity, DrawImage) {
  SkImageInfo info =
      SkImageInfo::Make(50, 50, SkColorType::kRGBA_8888_SkColorType,
                        SkAlphaType::kPremul_SkAlphaType);
  SkBitmap bitmap;
  bitmap.allocPixels(info, 0);
  auto image = SkImages::RasterFromBitmap(bitmap);

  DisplayListBuilder builder;
  builder.DrawImage(DlImage::Make(image), DlFPoint(0, 0),
                    DlImageSampling::kNearestNeighbor, nullptr);
  auto display_list = builder.Build();

  auto calculators = AccumulatorCalculators();
  for (auto calculator : calculators) {
    ASSERT_NE(calculator->Compute(display_list.get()), 0u);
  }
}

TEST(DisplayListComplexity, DrawImageNine) {
  SkImageInfo info =
      SkImageInfo::Make(50, 50, SkColorType::kRGBA_8888_SkColorType,
                        SkAlphaType::kPremul_SkAlphaType);
  SkBitmap bitmap;
  bitmap.allocPixels(info, 0);
  auto image = SkImages::RasterFromBitmap(bitmap);

  DlIRect center = DlIRect::MakeXYWH(5, 5, 20, 20);
  DlFRect dest = DlFRect::MakeXYWH(0, 0, 50, 50);

  DisplayListBuilder builder;
  builder.DrawImageNine(DlImage::Make(image), center, dest,
                        DlFilterMode::kNearest, nullptr);
  auto display_list = builder.Build();

  auto calculators = AccumulatorCalculators();
  for (auto calculator : calculators) {
    ASSERT_NE(calculator->Compute(display_list.get()), 0u);
  }
}

TEST(DisplayListComplexity, DrawImageRect) {
  SkImageInfo info =
      SkImageInfo::Make(50, 50, SkColorType::kRGBA_8888_SkColorType,
                        SkAlphaType::kPremul_SkAlphaType);
  SkBitmap bitmap;
  bitmap.allocPixels(info, 0);
  auto image = SkImages::RasterFromBitmap(bitmap);

  DlFRect src = DlFRect::MakeXYWH(0, 0, 50, 50);
  DlFRect dest = DlFRect::MakeXYWH(0, 0, 50, 50);

  DisplayListBuilder builder;
  builder.DrawImageRect(DlImage::Make(image), src, dest,
                        DlImageSampling::kNearestNeighbor, nullptr);
  auto display_list = builder.Build();

  auto calculators = AccumulatorCalculators();
  for (auto calculator : calculators) {
    ASSERT_NE(calculator->Compute(display_list.get()), 0u);
  }
}

TEST(DisplayListComplexity, DrawAtlas) {
  SkImageInfo info =
      SkImageInfo::Make(50, 50, SkColorType::kRGBA_8888_SkColorType,
                        SkAlphaType::kPremul_SkAlphaType);
  SkBitmap bitmap;
  bitmap.allocPixels(info, 0);
  auto image = SkImages::RasterFromBitmap(bitmap);

  std::vector<DlFRect> rects;
  std::vector<DlRSTransform> xforms;
  for (int i = 0; i < 10; i++) {
    rects.push_back(DlFRect::MakeWH(10, 10));
    xforms.push_back(DlRSTransform::MakeScaledCosSinXY(1, 0, 0, 0));
  }

  DisplayListBuilder builder;
  builder.DrawAtlas(DlImage::Make(image), xforms.data(), rects.data(), nullptr,
                    10, DlBlendMode::kSrc, DlImageSampling::kNearestNeighbor,
                    nullptr, nullptr);
  auto display_list = builder.Build();

  auto calculators = AccumulatorCalculators();
  for (auto calculator : calculators) {
    ASSERT_NE(calculator->Compute(display_list.get()), 0u);
  }
}

}  // namespace testing
}  // namespace flutter
