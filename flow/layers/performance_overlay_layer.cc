// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <iomanip>
#include <iostream>
#include <string>

#include "flutter/flow/layers/performance_overlay_layer.h"
#include "third_party/skia/include/core/SkFont.h"

namespace flow {
namespace {

void DrawStatisticsText(SkCanvas& canvas,
                        const std::string& string,
                        int x,
                        int y) {
  SkFont font;
  font.setSize(15);
  font.setLinearMetrics(false);
  SkPaint paint;
  paint.setColor(SK_ColorGRAY);
  canvas.drawSimpleText(string.c_str(), string.size(), kUTF8_SkTextEncoding, x,
                        y, font, paint);
}

void VisualizeStopWatch(SkCanvas& canvas,
                        const Stopwatch& stopwatch,
                        SkScalar x,
                        SkScalar y,
                        SkScalar width,
                        SkScalar height,
                        bool show_graph,
                        bool show_labels,
                        const std::string& label_prefix) {
  const int label_x = 8;    // distance from x
  const int label_y = -10;  // distance from y+height

  if (show_graph) {
    SkRect visualization_rect = SkRect::MakeXYWH(x, y, width, height);
    stopwatch.Visualize(canvas, visualization_rect);
  }

  if (show_labels) {
    double max_ms_per_frame = stopwatch.MaxDelta().ToMillisecondsF();
    double average_ms_per_frame = stopwatch.AverageDelta().ToMillisecondsF();
    std::stringstream stream;
    stream.setf(std::ios::fixed | std::ios::showpoint);
    stream << std::setprecision(1);
    stream << label_prefix << "  "
           << "max " << max_ms_per_frame << " ms/frame, "
           << "avg " << average_ms_per_frame << " ms/frame";
    DrawStatisticsText(canvas, stream.str(), x + label_x, y + height + label_y);
  }
}

}  // namespace

// To get the size of kMockedTimes in compile time.
template <class T, std::size_t N>
constexpr int size(const T (&array)[N]) noexcept {
  return N;
}

// We don't care too much about the efficiency of generating this mock stopwatch
// since it's only used in our golden test.
static inline std::unique_ptr<Stopwatch> GenMockStopwatch(bool mock_enabled) {
  std::unique_ptr<Stopwatch> mock_stopwatch;
  if (mock_enabled) {
    mock_stopwatch = std::make_unique<Stopwatch>();
    constexpr int kMockedTimes[] = {17, 1,  4,  24, 4,  25, 30, 4,  13, 34,
                                    14, 0,  18, 9,  32, 36, 26, 23, 5,  8,
                                    32, 18, 29, 16, 29, 18, 0,  36, 33, 10};
    for (int i = 0; i < size(kMockedTimes); ++i) {
      mock_stopwatch->SetLapTime(
          fml::TimeDelta::FromMilliseconds(kMockedTimes[i]));
    }
  }
  return mock_stopwatch;
}

PerformanceOverlayLayer::PerformanceOverlayLayer(uint64_t options)
    : options_(options) {}

void PerformanceOverlayLayer::Paint(PaintContext& context) const {
  const int padding = 8;

  if (!options_)
    return;

  std::unique_ptr<Stopwatch> mock_stopwatch =
      GenMockStopwatch(options_ & kMockStatistics);

  TRACE_EVENT0("flutter", "PerformanceOverlayLayer::Paint");
  SkScalar x = paint_bounds().x() + padding;
  SkScalar y = paint_bounds().y() + padding;
  SkScalar width = paint_bounds().width() - (padding * 2);
  SkScalar height = paint_bounds().height() / 2;
  SkAutoCanvasRestore save(context.leaf_nodes_canvas, true);

  VisualizeStopWatch(*context.leaf_nodes_canvas,
                     mock_stopwatch ? *mock_stopwatch : context.frame_time, x,
                     y, width, height - padding,
                     options_ & kVisualizeRasterizerStatistics,
                     options_ & kDisplayRasterizerStatistics, "GPU");

  VisualizeStopWatch(*context.leaf_nodes_canvas,
                     mock_stopwatch ? *mock_stopwatch : context.engine_time, x,
                     y + height, width, height - padding,
                     options_ & kVisualizeEngineStatistics,
                     options_ & kDisplayEngineStatistics, "UI");
}

}  // namespace flow
