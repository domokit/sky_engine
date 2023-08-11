// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_FLOW_DISPLAY_LIST_RASTER_CACHE_ITEM_H_
#define FLUTTER_FLOW_DISPLAY_LIST_RASTER_CACHE_ITEM_H_

#include <memory>
#include <optional>

#include "flutter/display_list/display_list.h"
#include "flutter/flow/embedded_views.h"
#include "flutter/flow/raster_cache_item.h"

namespace flutter {

class DisplayListRasterCacheItem : public RasterCacheItem {
 public:
  DisplayListRasterCacheItem(const sk_sp<DisplayList>& display_list,
                             const DlFPoint& offset,
                             bool is_complex = true,
                             bool will_change = false);

  static std::unique_ptr<DisplayListRasterCacheItem> Make(
      const sk_sp<DisplayList>&,
      const DlFPoint& offset,
      bool is_complex,
      bool will_change);

  void PrerollSetup(PrerollContext* context,
                    const DlTransform& matrix) override;

  void PrerollFinalize(PrerollContext* context,
                       const DlTransform& matrix) override;

  bool Draw(const PaintContext& context, const DlPaint* paint) const override;

  bool Draw(const PaintContext& context,
            DlCanvas* canvas,
            const DlPaint* paint) const override;

  bool TryToPrepareRasterCache(const PaintContext& context,
                               bool parent_cached = false) const override;

  void ModifyMatrix(DlFPoint offset) const {
    matrix_ = matrix_.TranslateOuter(offset.x(), offset.y());
  }

  const DisplayList* display_list() const { return display_list_.get(); }

 private:
  DlTransform transformation_matrix_;
  sk_sp<DisplayList> display_list_;
  DlFPoint offset_;
  bool is_complex_;
  bool will_change_;
};

}  // namespace flutter

#endif  // FLUTTER_FLOW_DISPLAY_LIST_RASTER_CACHE_ITEM_H_
