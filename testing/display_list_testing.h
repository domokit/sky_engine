// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_TESTING_DISPLAY_LIST_TESTING_H_
#define FLUTTER_TESTING_DISPLAY_LIST_TESTING_H_

#include <ostream>

#include "flutter/display_list/display_list.h"
#include "flutter/display_list/dl_op_receiver.h"

namespace flutter {
namespace testing {

[[nodiscard]] bool DisplayListsEQ_Verbose(const DisplayList* a,
                                          const DisplayList* b);
[[nodiscard]] bool inline DisplayListsEQ_Verbose(const DisplayList& a,
                                                 const DisplayList& b) {
  return DisplayListsEQ_Verbose(&a, &b);
}
[[nodiscard]] bool inline DisplayListsEQ_Verbose(
    const sk_sp<const DisplayList>& a,
    const sk_sp<const DisplayList>& b) {
  return DisplayListsEQ_Verbose(a.get(), b.get());
}
[[nodiscard]] bool DisplayListsNE_Verbose(const DisplayList* a,
                                          const DisplayList* b);
[[nodiscard]] bool inline DisplayListsNE_Verbose(const DisplayList& a,
                                                 const DisplayList& b) {
  return DisplayListsNE_Verbose(&a, &b);
}
[[nodiscard]] bool inline DisplayListsNE_Verbose(
    const sk_sp<const DisplayList>& a,
    const sk_sp<const DisplayList>& b) {
  return DisplayListsNE_Verbose(a.get(), b.get());
}

}  // namespace testing
}  // namespace flutter

namespace std {

extern std::ostream& operator<<(std::ostream& os,
                                const flutter::DisplayList& display_list);
extern std::ostream& operator<<(std::ostream& os,
                                const flutter::DlPaint& paint);
extern std::ostream& operator<<(std::ostream& os,
                                const flutter::DlBlendMode& mode);
extern std::ostream& operator<<(std::ostream& os,
                                const flutter::DlCanvas::ClipOp& op);
extern std::ostream& operator<<(std::ostream& os,
                                const flutter::DlCanvas::PointMode& op);
extern std::ostream& operator<<(std::ostream& os,
                                const flutter::DlCanvas::SrcRectConstraint& op);
extern std::ostream& operator<<(std::ostream& os,
                                const flutter::DlStrokeCap& cap);
extern std::ostream& operator<<(std::ostream& os,
                                const flutter::DlStrokeJoin& join);
extern std::ostream& operator<<(std::ostream& os,
                                const flutter::DlDrawStyle& style);
extern std::ostream& operator<<(std::ostream& os,
                                const flutter::DlBlurStyle& style);
extern std::ostream& operator<<(std::ostream& os,
                                const flutter::DlFilterMode& mode);
extern std::ostream& operator<<(std::ostream& os,
                                const flutter::DlColor& color);
extern std::ostream& operator<<(std::ostream& os,
                                flutter::DlImageSampling sampling);
extern std::ostream& operator<<(std::ostream& os,
                                const flutter::DlVertexMode& mode);
extern std::ostream& operator<<(std::ostream& os,
                                const flutter::DlTileMode& mode);
extern std::ostream& operator<<(std::ostream& os,
                                const flutter::DlImage* image);
extern std::ostream& operator<<(std::ostream& os,
                                const flutter::SaveLayerOptions& image);
extern std::ostream& operator<<(std::ostream& os,
                                const flutter::DisplayListOpType& type);
extern std::ostream& operator<<(std::ostream& os,
                                const flutter::DisplayListOpCategory& category);

}  // namespace std

namespace flutter {
namespace testing {

class DisplayListStreamDispatcher final : public DlOpReceiver {
 public:
  explicit DisplayListStreamDispatcher(std::ostream& os,
                                       int cur_indent = 2,
                                       int indent = 2)
      : os_(os), cur_indent_(cur_indent), indent_(indent) {}

  void setAntiAlias(bool aa) override;
  void setDrawStyle(DlDrawStyle style) override;
  void setColor(DlColor color) override;
  void setStrokeWidth(SkScalar width) override;
  void setStrokeMiter(SkScalar limit) override;
  void setStrokeCap(DlStrokeCap cap) override;
  void setStrokeJoin(DlStrokeJoin join) override;
  void setColorSource(const DlColorSource* source) override;
  void setColorFilter(const DlColorFilter* filter) override;
  void setInvertColors(bool invert) override;
  void setBlendMode(DlBlendMode mode) override;
  void setMaskFilter(const DlMaskFilter* filter) override;
  void setImageFilter(const DlImageFilter* filter) override;

  void save() override;
  void saveLayer(const SkRect& bounds,
                 const SaveLayerOptions options,
                 const DlImageFilter* backdrop) override;
  void restore() override;

  void translate(SkScalar tx, SkScalar ty) override;
  void scale(SkScalar sx, SkScalar sy) override;
  void rotate(SkScalar degrees) override;
  void skew(SkScalar sx, SkScalar sy) override;
  // clang-format off
  void transform2DAffine(SkScalar mxx, SkScalar mxy, SkScalar mxt,
                                 SkScalar myx, SkScalar myy, SkScalar myt) override;
  void transformFullPerspective(
      SkScalar mxx, SkScalar mxy, SkScalar mxz, SkScalar mxt,
      SkScalar myx, SkScalar myy, SkScalar myz, SkScalar myt,
      SkScalar mzx, SkScalar mzy, SkScalar mzz, SkScalar mzt,
      SkScalar mwx, SkScalar mwy, SkScalar mwz, SkScalar mwt) override;
  // clang-format on
  void transformReset() override;

  void clipRect(const SkRect& rect, ClipOp clip_op, bool is_aa) override;
  void clipOval(const SkRect& bounds, ClipOp clip_op, bool is_aa) override;
  void clipRRect(const SkRRect& rrect, ClipOp clip_op, bool is_aa) override;
  void clipPath(const SkPath& path, ClipOp clip_op, bool is_aa) override;

  void drawColor(DlColor color, DlBlendMode mode) override;
  void drawPaint() override;
  void drawLine(const SkPoint& p0, const SkPoint& p1) override;
  void drawDashedLine(const DlPoint& p0,
                      const DlPoint& p1,
                      DlScalar on_length,
                      DlScalar off_length) override;
  void drawRect(const SkRect& rect) override;
  void drawOval(const SkRect& bounds) override;
  void drawCircle(const SkPoint& center, SkScalar radius) override;
  void drawRRect(const SkRRect& rrect) override;
  void drawDRRect(const SkRRect& outer, const SkRRect& inner) override;
  void drawPath(const SkPath& path) override;
  void drawArc(const SkRect& oval_bounds,
               SkScalar start_degrees,
               SkScalar sweep_degrees,
               bool use_center) override;
  void drawPoints(PointMode mode,
                  uint32_t count,
                  const SkPoint points[]) override;
  void drawVertices(const std::shared_ptr<DlVertices>& vertices,
                    DlBlendMode mode) override;
  void drawImage(const sk_sp<DlImage> image,
                 const SkPoint point,
                 DlImageSampling sampling,
                 bool render_with_attributes) override;
  void drawImageRect(const sk_sp<DlImage> image,
                     const SkRect& src,
                     const SkRect& dst,
                     DlImageSampling sampling,
                     bool render_with_attributes,
                     SrcRectConstraint constraint) override;
  void drawImageNine(const sk_sp<DlImage> image,
                     const SkIRect& center,
                     const SkRect& dst,
                     DlFilterMode filter,
                     bool render_with_attributes) override;
  void drawAtlas(const sk_sp<DlImage> atlas,
                 const SkRSXform xform[],
                 const SkRect tex[],
                 const DlColor colors[],
                 int count,
                 DlBlendMode mode,
                 DlImageSampling sampling,
                 const SkRect* cull_rect,
                 bool render_with_attributes) override;
  void drawDisplayList(const sk_sp<DisplayList> display_list,
                       SkScalar opacity) override;
  void drawTextBlob(const sk_sp<SkTextBlob> blob,
                    SkScalar x,
                    SkScalar y) override;
  void drawTextFrame(const std::shared_ptr<impeller::TextFrame>& text_frame,
                     SkScalar x,
                     SkScalar y) override;
  void drawShadow(const SkPath& path,
                  const DlColor color,
                  const SkScalar elevation,
                  bool transparent_occluder,
                  SkScalar dpr) override;

 private:
  std::ostream& os_;
  int cur_indent_;
  int indent_;

  void indent() { indent(indent_); }
  void outdent() { outdent(indent_); }
  void indent(int spaces) { cur_indent_ += spaces; }
  void outdent(int spaces) { cur_indent_ -= spaces; }

  template <class T>
  std::ostream& out_array(std::string name, int count, const T array[]);

  std::ostream& startl();

  void out(const DlColorFilter& filter);
  void out(const DlColorFilter* filter);
  void out(const DlImageFilter& filter);
  void out(const DlImageFilter* filter);
};

class DisplayListGeneralReceiver : public DlOpReceiver {
 public:
  DisplayListGeneralReceiver() {
    type_counts_.fill(0u);
    category_counts_.fill(0u);
  }

  void setAntiAlias(bool aa) override {
    RecordByType(DisplayListOpType::kSetAntiAlias);
  }
  void setInvertColors(bool invert) override {
    RecordByType(DisplayListOpType::kSetInvertColors);
  }
  void setStrokeCap(DlStrokeCap cap) override {
    RecordByType(DisplayListOpType::kSetStrokeCap);
  }
  void setStrokeJoin(DlStrokeJoin join) override {
    RecordByType(DisplayListOpType::kSetStrokeJoin);
  }
  void setDrawStyle(DlDrawStyle style) override {
    RecordByType(DisplayListOpType::kSetStyle);
  }
  void setStrokeWidth(float width) override {
    RecordByType(DisplayListOpType::kSetStrokeWidth);
  }
  void setStrokeMiter(float limit) override {
    RecordByType(DisplayListOpType::kSetStrokeMiter);
  }
  void setColor(DlColor color) override {
    RecordByType(DisplayListOpType::kSetColor);
  }
  void setBlendMode(DlBlendMode mode) override {
    RecordByType(DisplayListOpType::kSetBlendMode);
  }
  void setColorSource(const DlColorSource* source) override {
    if (source) {
      switch (source->type()) {
        case DlColorSourceType::kImage:
          RecordByType(DisplayListOpType::kSetImageColorSource);
          break;
        case DlColorSourceType::kRuntimeEffect:
          RecordByType(DisplayListOpType::kSetRuntimeEffectColorSource);
          break;
        case DlColorSourceType::kColor:
        case DlColorSourceType::kLinearGradient:
        case DlColorSourceType::kRadialGradient:
        case DlColorSourceType::kConicalGradient:
        case DlColorSourceType::kSweepGradient:
          RecordByType(DisplayListOpType::kSetPodColorSource);
          break;
#ifdef IMPELLER_ENABLE_3D
        case DlColorSourceType::kScene:
          RecordByType(DisplayListOpType::kSetSceneColorSource);
          break;
#endif  // IMPELLER_ENABLE_3D
      }
    } else {
      RecordByType(DisplayListOpType::kClearColorSource);
    }
  }
  void setImageFilter(const DlImageFilter* filter) override {
    if (filter) {
      switch (filter->type()) {
        case DlImageFilterType::kBlur:
        case DlImageFilterType::kDilate:
        case DlImageFilterType::kErode:
        case DlImageFilterType::kMatrix:
          RecordByType(DisplayListOpType::kSetPodImageFilter);
          break;
        case DlImageFilterType::kCompose:
        case DlImageFilterType::kLocalMatrix:
        case DlImageFilterType::kColorFilter:
          RecordByType(DisplayListOpType::kSetSharedImageFilter);
          break;
      }
    } else {
      RecordByType(DisplayListOpType::kClearImageFilter);
    }
  }
  void setColorFilter(const DlColorFilter* filter) override {
    if (filter) {
      switch (filter->type()) {
        case DlColorFilterType::kBlend:
        case DlColorFilterType::kMatrix:
        case DlColorFilterType::kLinearToSrgbGamma:
        case DlColorFilterType::kSrgbToLinearGamma:
          RecordByType(DisplayListOpType::kSetPodColorFilter);
          break;
      }
    } else {
      RecordByType(DisplayListOpType::kClearColorFilter);
    }
  }
  void setMaskFilter(const DlMaskFilter* filter) override {
    if (filter) {
      switch (filter->type()) {
        case DlMaskFilterType::kBlur:
          RecordByType(DisplayListOpType::kSetPodMaskFilter);
          break;
      }
    } else {
      RecordByType(DisplayListOpType::kClearMaskFilter);
    }
  }

  void translate(SkScalar tx, SkScalar ty) override {
    RecordByType(DisplayListOpType::kTranslate);
  }
  void scale(SkScalar sx, SkScalar sy) override {
    RecordByType(DisplayListOpType::kScale);
  }
  void rotate(SkScalar degrees) override {
    RecordByType(DisplayListOpType::kRotate);
  }
  void skew(SkScalar sx, SkScalar sy) override {
    RecordByType(DisplayListOpType::kSkew);
  }
  // clang-format off
  // 2x3 2D affine subset of a 4x4 transform in row major order
  void transform2DAffine(SkScalar mxx, SkScalar mxy, SkScalar mxt,
                         SkScalar myx, SkScalar myy, SkScalar myt) override {
    RecordByType(DisplayListOpType::kTransform2DAffine);
  }
  // full 4x4 transform in row major order
  void transformFullPerspective(
      SkScalar mxx, SkScalar mxy, SkScalar mxz, SkScalar mxt,
      SkScalar myx, SkScalar myy, SkScalar myz, SkScalar myt,
      SkScalar mzx, SkScalar mzy, SkScalar mzz, SkScalar mzt,
      SkScalar mwx, SkScalar mwy, SkScalar mwz, SkScalar mwt) override {
    RecordByType(DisplayListOpType::kTransformFullPerspective);
  }
  // clang-format on
  void transformReset() override {
    RecordByType(DisplayListOpType::kTransformReset);
  }

  void clipRect(const SkRect& rect,
                DlCanvas::ClipOp clip_op,
                bool is_aa) override {
    switch (clip_op) {
      case DlCanvas::ClipOp::kIntersect:
        RecordByType(DisplayListOpType::kClipIntersectRect);
        break;
      case DlCanvas::ClipOp::kDifference:
        RecordByType(DisplayListOpType::kClipDifferenceRect);
        break;
    }
  }
  void clipOval(const SkRect& bounds,
                DlCanvas::ClipOp clip_op,
                bool is_aa) override {
    switch (clip_op) {
      case DlCanvas::ClipOp::kIntersect:
        RecordByType(DisplayListOpType::kClipIntersectOval);
        break;
      case DlCanvas::ClipOp::kDifference:
        RecordByType(DisplayListOpType::kClipDifferenceOval);
        break;
    }
  }
  void clipRRect(const SkRRect& rrect,
                 DlCanvas::ClipOp clip_op,
                 bool is_aa) override {
    switch (clip_op) {
      case DlCanvas::ClipOp::kIntersect:
        RecordByType(DisplayListOpType::kClipIntersectRRect);
        break;
      case DlCanvas::ClipOp::kDifference:
        RecordByType(DisplayListOpType::kClipDifferenceRRect);
        break;
    }
  }
  void clipPath(const SkPath& path,
                DlCanvas::ClipOp clip_op,
                bool is_aa) override {
    switch (clip_op) {
      case DlCanvas::ClipOp::kIntersect:
        RecordByType(DisplayListOpType::kClipIntersectPath);
        break;
      case DlCanvas::ClipOp::kDifference:
        RecordByType(DisplayListOpType::kClipDifferencePath);
        break;
    }
  }

  void save() override { RecordByType(DisplayListOpType::kSave); }
  void saveLayer(const SkRect& bounds,
                 const SaveLayerOptions options,
                 const DlImageFilter* backdrop) override {
    if (backdrop) {
      RecordByType(DisplayListOpType::kSaveLayerBackdrop);
    } else {
      RecordByType(DisplayListOpType::kSaveLayer);
    }
  }
  void restore() override { RecordByType(DisplayListOpType::kRestore); }

  void drawColor(DlColor color, DlBlendMode mode) override {
    RecordByType(DisplayListOpType::kDrawColor);
  }
  void drawPaint() override { RecordByType(DisplayListOpType::kDrawPaint); }
  void drawLine(const SkPoint& p0, const SkPoint& p1) override {
    RecordByType(DisplayListOpType::kDrawLine);
  }
  void drawDashedLine(const DlPoint& p0,
                      const DlPoint& p1,
                      DlScalar on_length,
                      DlScalar off_length) override {
    RecordByType(DisplayListOpType::kDrawDashedLine);
  }
  void drawRect(const SkRect& rect) override {
    RecordByType(DisplayListOpType::kDrawRect);
  }
  void drawOval(const SkRect& bounds) override {
    RecordByType(DisplayListOpType::kDrawOval);
  }
  void drawCircle(const SkPoint& center, SkScalar radius) override {
    RecordByType(DisplayListOpType::kDrawCircle);
  }
  void drawRRect(const SkRRect& rrect) override {
    RecordByType(DisplayListOpType::kDrawRRect);
  }
  void drawDRRect(const SkRRect& outer, const SkRRect& inner) override {
    RecordByType(DisplayListOpType::kDrawDRRect);
  }
  void drawPath(const SkPath& path) override {
    RecordByType(DisplayListOpType::kDrawPath);
  }
  void drawArc(const SkRect& oval_bounds,
               SkScalar start_degrees,
               SkScalar sweep_degrees,
               bool use_center) override {
    RecordByType(DisplayListOpType::kDrawArc);
  }
  void drawPoints(DlCanvas::PointMode mode,
                  uint32_t count,
                  const SkPoint points[]) override {
    switch (mode) {
      case DlCanvas::PointMode::kPoints:
        RecordByType(DisplayListOpType::kDrawPoints);
        break;
      case DlCanvas::PointMode::kLines:
        RecordByType(DisplayListOpType::kDrawLines);
        break;
      case DlCanvas::PointMode::kPolygon:
        RecordByType(DisplayListOpType::kDrawPolygon);
        break;
    }
  }
  void drawVertices(const std::shared_ptr<DlVertices>& vertices,
                    DlBlendMode mode) override {
    RecordByType(DisplayListOpType::kDrawVertices);
  }
  void drawImage(const sk_sp<DlImage> image,
                 const SkPoint point,
                 DlImageSampling sampling,
                 bool render_with_attributes) override {
    if (render_with_attributes) {
      RecordByType(DisplayListOpType::kDrawImageWithAttr);
    } else {
      RecordByType(DisplayListOpType::kDrawImage);
    }
  }
  void drawImageRect(const sk_sp<DlImage> image,
                     const SkRect& src,
                     const SkRect& dst,
                     DlImageSampling sampling,
                     bool render_with_attributes,
                     SrcRectConstraint constraint) override {
    RecordByType(DisplayListOpType::kDrawImageRect);
  }
  void drawImageNine(const sk_sp<DlImage> image,
                     const SkIRect& center,
                     const SkRect& dst,
                     DlFilterMode filter,
                     bool render_with_attributes) override {
    if (render_with_attributes) {
      RecordByType(DisplayListOpType::kDrawImageNineWithAttr);
    } else {
      RecordByType(DisplayListOpType::kDrawImageNine);
    }
  }
  void drawAtlas(const sk_sp<DlImage> atlas,
                 const SkRSXform xform[],
                 const SkRect tex[],
                 const DlColor colors[],
                 int count,
                 DlBlendMode mode,
                 DlImageSampling sampling,
                 const SkRect* cull_rect,
                 bool render_with_attributes) override {
    if (cull_rect) {
      RecordByType(DisplayListOpType::kDrawAtlasCulled);
    } else {
      RecordByType(DisplayListOpType::kDrawAtlas);
    }
  }
  void drawDisplayList(const sk_sp<DisplayList> display_list,
                       SkScalar opacity) override {
    RecordByType(DisplayListOpType::kDrawDisplayList);
  }
  void drawTextBlob(const sk_sp<SkTextBlob> blob,
                    SkScalar x,
                    SkScalar y) override {
    RecordByType(DisplayListOpType::kDrawTextBlob);
  }
  void drawTextFrame(const std::shared_ptr<impeller::TextFrame>& text_frame,
                     SkScalar x,
                     SkScalar y) override {
    RecordByType(DisplayListOpType::kDrawTextFrame);
  }
  void drawShadow(const SkPath& path,
                  const DlColor color,
                  const SkScalar elevation,
                  bool transparent_occluder,
                  SkScalar dpr) override {
    if (transparent_occluder) {
      RecordByType(DisplayListOpType::kDrawShadowTransparentOccluder);
    } else {
      RecordByType(DisplayListOpType::kDrawShadow);
    }
  }

  uint32_t GetOpsReceived() { return op_count_; }
  uint32_t GetOpsReceived(DisplayListOpCategory category) {
    return category_counts_[static_cast<int>(category)];
  }
  uint32_t GetOpsReceived(DisplayListOpType type) {
    return type_counts_[static_cast<int>(type)];
  }

 protected:
  virtual void RecordByType(DisplayListOpType type) {
    type_counts_[static_cast<int>(type)]++;
    RecordByCategory(DisplayList::GetOpCategory(type));
  }

  virtual void RecordByCategory(DisplayListOpCategory category) {
    category_counts_[static_cast<int>(category)]++;
    switch (category) {
      case DisplayListOpCategory::kAttribute:
        RecordAttribute();
        break;
      case DisplayListOpCategory::kTransform:
        RecordTransform();
        break;
      case DisplayListOpCategory::kClip:
        RecordClip();
        break;
      case DisplayListOpCategory::kSave:
        RecordSave();
        break;
      case DisplayListOpCategory::kSaveLayer:
        RecordSaveLayer();
        break;
      case DisplayListOpCategory::kRestore:
        RecordRestore();
        break;
      case DisplayListOpCategory::kRendering:
        RecordRendering();
        break;
      case DisplayListOpCategory::kSubDisplayList:
        RecordSubDisplayList();
        break;
      case DisplayListOpCategory::kInvalidCategory:
        RecordInvalid();
        break;
    }
  }

  virtual void RecordAttribute() { RecordOp(); }
  virtual void RecordTransform() { RecordOp(); }
  virtual void RecordClip() { RecordOp(); }
  virtual void RecordSave() { RecordOp(); }
  virtual void RecordSaveLayer() { RecordOp(); }
  virtual void RecordRestore() { RecordOp(); }
  virtual void RecordRendering() { RecordOp(); }
  virtual void RecordSubDisplayList() { RecordOp(); }
  virtual void RecordInvalid() { RecordOp(); }

  virtual void RecordOp() { op_count_++; }

  static constexpr size_t kTypeCount =
      static_cast<size_t>(DisplayListOpType::kMaxOp) + 1;
  static constexpr size_t kCategoryCount =
      static_cast<size_t>(DisplayListOpCategory::kMaxCategory) + 1;

  std::array<uint32_t, kTypeCount> type_counts_;
  std::array<uint32_t, kCategoryCount> category_counts_;
  uint32_t op_count_ = 0u;
};

}  // namespace testing
}  // namespace flutter

#endif  // FLUTTER_TESTING_DISPLAY_LIST_TESTING_H_
