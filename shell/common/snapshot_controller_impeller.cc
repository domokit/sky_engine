// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "flutter/shell/common/snapshot_controller_impeller.h"

#include <algorithm>

#include "flutter/flow/surface.h"
#include "flutter/fml/trace_event.h"
#include "flutter/impeller/display_list/dl_dispatcher.h"
#include "flutter/impeller/display_list/dl_image_impeller.h"
#include "flutter/impeller/geometry/size.h"
#include "flutter/shell/common/snapshot_controller.h"

namespace flutter {

void SnapshotControllerImpeller::MakeRasterSnapshot(
    sk_sp<DisplayList> display_list,
    SkISize picture_size,
    std::function<void(sk_sp<DlImage>)> callback) {
  sk_sp<DlImage> result;
  GetDelegate().GetIsGpuDisabledSyncSwitch()->Execute(
      fml::SyncSwitch::Handlers()
          .SetIfTrue([&] {
            std::shared_ptr<impeller::AiksContext> context =
                GetDelegate().GetAiksContext();
            if (context) {
              context->GetContext()->StoreTaskForGPU(
                  [this /*not safe, don't commit*/,
                   display_list = std::move(display_list), picture_size,
                   callback = std::move(callback)] {
                    callback(
                        MakeRasterSnapshotSync(display_list, picture_size));
                  });
            } else {
              callback(nullptr);
            }
          })
          .SetIfFalse([&] {
            callback(DoMakeRasterSnapshot(display_list, picture_size));
          }));
}

sk_sp<DlImage> SnapshotControllerImpeller::MakeRasterSnapshotSync(
    sk_sp<DisplayList> display_list,
    SkISize picture_size) {
  sk_sp<DlImage> result;
  GetDelegate().GetIsGpuDisabledSyncSwitch()->Execute(
      fml::SyncSwitch::Handlers()
          .SetIfTrue([&] {
            // Do nothing.
          })
          .SetIfFalse([&] {
            result = DoMakeRasterSnapshot(display_list, picture_size);
          }));

  return result;
}

sk_sp<DlImage> SnapshotControllerImpeller::DoMakeRasterSnapshot(
    const sk_sp<DisplayList>& display_list,
    SkISize size) {
  TRACE_EVENT0("flutter", __FUNCTION__);
  impeller::DlDispatcher dispatcher;
  display_list->Dispatch(dispatcher);
  impeller::Picture picture = dispatcher.EndRecordingAsPicture();
  auto context = GetDelegate().GetAiksContext();
  if (context) {
    auto max_size = context->GetContext()
                        ->GetResourceAllocator()
                        ->GetMaxTextureSizeSupported();
    double scale_factor_x =
        static_cast<double>(max_size.width) / static_cast<double>(size.width());
    double scale_factor_y = static_cast<double>(max_size.height) /
                            static_cast<double>(size.height());
    double scale_factor =
        std::min(1.0, std::min(scale_factor_x, scale_factor_y));

    auto render_target_size = impeller::ISize(size.width(), size.height());

    // Scale down the render target size to the max supported by the
    // GPU if necessary. Exceeding the max would otherwise cause a
    // null result.
    if (scale_factor < 1.0) {
      render_target_size.width *= scale_factor;
      render_target_size.height *= scale_factor;
    }

    std::shared_ptr<impeller::Image> image =
        picture.ToImage(*context, render_target_size);
    if (image) {
      return impeller::DlImageImpeller::Make(image->GetTexture(),
                                             DlImage::OwningContext::kRaster);
    }
  }

  return nullptr;
}

void SnapshotControllerImpeller::CacheRuntimeStage(
    const std::shared_ptr<impeller::RuntimeStage>& runtime_stage) {
  impeller::RuntimeEffectContents runtime_effect;
  runtime_effect.SetRuntimeStage(runtime_stage);
  auto context = GetDelegate().GetAiksContext();
  if (!context) {
    return;
  }
  runtime_effect.BootstrapShader(context->GetContentContext());
}

sk_sp<SkImage> SnapshotControllerImpeller::ConvertToRasterImage(
    sk_sp<SkImage> image) {
  FML_UNREACHABLE();
}

}  // namespace flutter
