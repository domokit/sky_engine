// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "shell/platform/darwin/ios/framework/Source/platform_views_controller.h"

#include "flutter/display_list/effects/image_filters/dl_blur_image_filter.h"
#include "flutter/flow/surface_frame.h"
#include "flutter/flow/view_slicer.h"
#include "flutter/fml/make_copyable.h"
#include "flutter/fml/synchronization/count_down_latch.h"

#import "flutter/shell/platform/darwin/ios/framework/Source/FlutterOverlayView.h"
#import "flutter/shell/platform/darwin/ios/framework/Source/FlutterView.h"
#import "flutter/shell/platform/darwin/ios/ios_surface.h"

namespace {

// The number of frames the rasterizer task runner will continue
// to run on the platform thread after no platform view is rendered.
//
// Note: this is an arbitrary number.
static const int kDefaultMergedLeaseDuration = 10;

static constexpr NSUInteger kFlutterClippingMaskViewPoolCapacity = 5;

// Converts a SkMatrix to CATransform3D.
//
// Certain fields are ignored in CATransform3D since SkMatrix is 3x3 and CATransform3D is 4x4.
CATransform3D GetCATransform3DFromSkMatrix(const SkMatrix& matrix) {
  // Skia only supports 2D transform so we don't map z.
  CATransform3D transform = CATransform3DIdentity;
  transform.m11 = matrix.getScaleX();
  transform.m21 = matrix.getSkewX();
  transform.m41 = matrix.getTranslateX();
  transform.m14 = matrix.getPerspX();

  transform.m12 = matrix.getSkewY();
  transform.m22 = matrix.getScaleY();
  transform.m42 = matrix.getTranslateY();
  transform.m24 = matrix.getPerspY();
  return transform;
}

// Reset the anchor of `layer` to match the transform operation from flow.
//
// The position of the `layer` should be unchanged after resetting the anchor.
void ResetAnchor(CALayer* layer) {
  // Flow uses (0, 0) to apply transform matrix so we need to match that in Quartz.
  layer.anchorPoint = CGPointZero;
  layer.position = CGPointZero;
}

CGRect GetCGRectFromSkRect(const SkRect& clipSkRect) {
  return CGRectMake(clipSkRect.fLeft, clipSkRect.fTop, clipSkRect.fRight - clipSkRect.fLeft,
                    clipSkRect.fBottom - clipSkRect.fTop);
}

// Determines if the `clip_rect` from a clipRect mutator contains the
// `platformview_boundingrect`.
//
// `clip_rect` is in its own coordinate space. The rect needs to be transformed by
// `transform_matrix` to be in the coordinate space where the PlatformView is displayed.
//
// `platformview_boundingrect` is the final bounding rect of the PlatformView in the coordinate
// space where the PlatformView is displayed.
bool ClipRectContainsPlatformViewBoundingRect(const SkRect& clip_rect,
                                              const SkRect& platformview_boundingrect,
                                              const SkMatrix& transform_matrix) {
  SkRect transformed_rect = transform_matrix.mapRect(clip_rect);
  return transformed_rect.contains(platformview_boundingrect);
}

// Determines if the `clipRRect` from a clipRRect mutator contains the
// `platformview_boundingrect`.
//
// `clip_rrect` is in its own coordinate space. The rrect needs to be transformed by
// `transform_matrix` to be in the coordinate space where the PlatformView is displayed.
//
// `platformview_boundingrect` is the final bounding rect of the PlatformView in the coordinate
// space where the PlatformView is displayed.
bool ClipRRectContainsPlatformViewBoundingRect(const SkRRect& clip_rrect,
                                               const SkRect& platformview_boundingrect,
                                               const SkMatrix& transform_matrix) {
  SkVector upper_left = clip_rrect.radii(SkRRect::Corner::kUpperLeft_Corner);
  SkVector upper_right = clip_rrect.radii(SkRRect::Corner::kUpperRight_Corner);
  SkVector lower_right = clip_rrect.radii(SkRRect::Corner::kLowerRight_Corner);
  SkVector lower_left = clip_rrect.radii(SkRRect::Corner::kLowerLeft_Corner);
  SkScalar transformed_upper_left_x = transform_matrix.mapRadius(upper_left.x());
  SkScalar transformed_upper_left_y = transform_matrix.mapRadius(upper_left.y());
  SkScalar transformed_upper_right_x = transform_matrix.mapRadius(upper_right.x());
  SkScalar transformed_upper_right_y = transform_matrix.mapRadius(upper_right.y());
  SkScalar transformed_lower_right_x = transform_matrix.mapRadius(lower_right.x());
  SkScalar transformed_lower_right_y = transform_matrix.mapRadius(lower_right.y());
  SkScalar transformed_lower_left_x = transform_matrix.mapRadius(lower_left.x());
  SkScalar transformed_lower_left_y = transform_matrix.mapRadius(lower_left.y());
  SkRect transformed_clip_rect = transform_matrix.mapRect(clip_rrect.rect());
  SkRRect transformed_rrect;
  SkVector corners[] = {{transformed_upper_left_x, transformed_upper_left_y},
                        {transformed_upper_right_x, transformed_upper_right_y},
                        {transformed_lower_right_x, transformed_lower_right_y},
                        {transformed_lower_left_x, transformed_lower_left_y}};
  transformed_rrect.setRectRadii(transformed_clip_rect, corners);
  return transformed_rrect.contains(platformview_boundingrect);
}

struct LayerData {
  SkRect rect;
  int64_t view_id;
  int64_t overlay_id;
  std::shared_ptr<flutter::OverlayLayer> layer;
};

using LayersMap = std::unordered_map<int64_t, LayerData>;

/// Each of the following structs stores part of the platform view hierarchy according to its
/// ID.
///
/// This data must only be accessed on the platform thread.
struct PlatformViewData {
  NSObject<FlutterPlatformView>* view;
  FlutterTouchInterceptingView* touch_interceptor;
  UIView* root_view;
};

}  // namespace

namespace flutter {

/// @brief Composites Flutter UI and overlay layers alongside embedded UIViews.
class PlatformViewsController {
 public:
  PlatformViewsController();

  ~PlatformViewsController() = default;

  /// @brief Returns the platform view id if the platform view (or any of its descendant view) is
  /// the first responder.
  ///
  /// Returns -1 if no such platform view is found.
  long FindFirstResponderPlatformViewId();

  /// @brief Pushes backdrop filter mutation to the mutator stack of each visited platform view.
  void PushFilterToVisitedPlatformViews(const std::shared_ptr<DlImageFilter>& filter,
                                        const SkRect& filter_rect);

  /// @brief Pushes the view id of a visted platform view to the list of visied platform views.
  void PushVisitedPlatformView(int64_t view_id) { visited_platform_views_.push_back(view_id); }

  // visible for testing.
  size_t EmbeddedViewCount() const;

  // Visible for testing.
  void CompositeWithParams(int64_t view_id, const EmbeddedViewParams& params);

  // Visible for testing.
  const EmbeddedViewParams& GetCompositionParams(int64_t view_id) const {
    return current_composition_params_.find(view_id)->second;
  }

  // TODO(cbracken): Hack to make contents visible to Obj-C wrapper.
  // private:
  PlatformViewsController(const PlatformViewsController&) = delete;
  PlatformViewsController& operator=(const PlatformViewsController&) = delete;

  // Update the buffers and mutate the platform views in CATransaction.
  //
  // Runs on the platform thread.
  void PerformSubmit(const LayersMap& platform_view_layers,
                     std::unordered_map<int64_t, EmbeddedViewParams>& current_composition_params,
                     const std::unordered_set<int64_t>& views_to_recomposite,
                     const std::vector<int64_t>& composition_order,
                     const std::vector<std::shared_ptr<OverlayLayer>>& unused_layers,
                     const std::vector<std::unique_ptr<SurfaceFrame>>& surface_frames);

  /// @brief Populate any missing overlay layers.
  ///
  /// This requires posting a task to the platform thread and blocking on its completion.
  void CreateMissingOverlays(GrDirectContext* gr_context,
                             const std::shared_ptr<IOSContext>& ios_context,
                             size_t required_overlay_layers);

  /// @brief Return all views to be disposed on the platform thread.
  std::vector<UIView*> GetViewsToDispose();

  void ClipViewSetMaskView(UIView* clipView) __attribute__((cf_audited_transfer));

  // Applies the mutators in the mutators_stack to the UIView chain that was constructed by
  // `ReconstructClipViewsChain`
  //
  // Clips are applied to the `embedded_view`'s super view(|ChildClippingView|) using a
  // |FlutterClippingMaskView|. Transforms are applied to `embedded_view`
  //
  // The `bounding_rect` is the final bounding rect of the PlatformView
  // (EmbeddedViewParams::finalBoundingRect). If a clip mutator's rect contains the final bounding
  // rect of the PlatformView, the clip mutator is not applied for performance optimization.
  void ApplyMutators(const MutatorsStack& mutators_stack,
                     UIView* embedded_view,
                     const SkRect& bounding_rect) __attribute__((cf_audited_transfer));

  std::shared_ptr<OverlayLayer> GetExistingLayer();

  // Runs on the platform thread.
  void CreateLayer(GrDirectContext* gr_context,
                   const std::shared_ptr<IOSContext>& ios_context,
                   MTLPixelFormat pixel_format);

  // Removes overlay views and platform views that aren't needed in the current frame.
  // Must run on the platform thread.
  void RemoveUnusedLayers(const std::vector<std::shared_ptr<OverlayLayer>>& unused_layers,
                          const std::vector<int64_t>& composition_order);

  // Appends the overlay views and platform view and sets their z index based on the composition
  // order.
  void BringLayersIntoView(const LayersMap& layer_map,
                           const std::vector<int64_t>& composition_order);

  // Resets the state of the frame.
  void ResetFrameState();

  // The pool of reusable view layers. The pool allows to recycle layer in each frame.
  std::unique_ptr<OverlayLayerPool> layer_pool_;

  // The platform view's |EmbedderViewSlice| keyed off the view id, which contains any subsequent
  // operation until the next platform view or the end of the last leaf node in the layer tree.
  //
  // The Slices are deleted by the PlatformViewsController.reset().
  std::unordered_map<int64_t, std::unique_ptr<EmbedderViewSlice>> slices_;

  UIView* flutter_view_;
  UIViewController<FlutterViewResponder>* flutter_view_controller_;
  FlutterClippingMaskViewPool* mask_view_pool_;
  std::unordered_map<std::string, NSObject<FlutterPlatformViewFactory>*> factories_;

  // The FlutterPlatformViewGestureRecognizersBlockingPolicy for each type of platform view.
  std::unordered_map<std::string, FlutterPlatformViewGestureRecognizersBlockingPolicy>
      gesture_recognizers_blocking_policies_;

  /// The size of the current onscreen surface in physical pixels.
  SkISize frame_size_;

  /// The task runner for posting tasks to the platform thread.
  fml::RefPtr<fml::TaskRunner> platform_task_runner_;

  /// This data must only be accessed on the platform thread.
  std::unordered_map<int64_t, PlatformViewData> platform_views_;

  /// The composition parameters for each platform view.
  ///
  /// This state is only modified on the raster thread.
  std::unordered_map<int64_t, EmbeddedViewParams> current_composition_params_;

  /// Method channel `OnDispose` calls adds the views to be disposed to this set to be disposed on
  /// the next frame.
  ///
  /// This state is modified on both the platform and raster thread.
  std::unordered_set<int64_t> views_to_dispose_;

  /// view IDs in composition order.
  ///
  /// This state is only modified on the raster thread.
  std::vector<int64_t> composition_order_;

  /// platform view IDs visited during layer tree composition.
  ///
  /// This state is only modified on the raster thread.
  std::vector<int64_t> visited_platform_views_;

  /// Only composite platform views in this set.
  ///
  /// This state is only modified on the raster thread.
  std::unordered_set<int64_t> views_to_recomposite_;

#if FLUTTER_RUNTIME_MODE == FLUTTER_RUNTIME_MODE_DEBUG
  /// A set to keep track of embedded views that do not have (0, 0) origin.
  /// An insertion triggers a warning message about non-zero origin logged on the debug console.
  /// See https://github.com/flutter/flutter/issues/109700 for details.
  std::unordered_set<int64_t> non_zero_origin_views_;
#endif

  /// @brief The composition order from the previous thread.
  ///
  /// Only accessed from the platform thread.
  std::vector<int64_t> previous_composition_order_;

  /// Whether the previous frame had any platform views in active composition order.
  ///
  /// This state is tracked so that the first frame after removing the last platform view
  /// runs through the platform view rendering code path, giving us a chance to remove the
  /// platform view from the UIView hierarchy.
  ///
  /// Only accessed from the raster thread.
  bool had_platform_views_ = false;
};

// Becomes NO if Apple's API changes and blurred backdrop filters cannot be applied.
BOOL canApplyBlurBackdrop = YES;

PlatformViewsController::PlatformViewsController()
    : layer_pool_(std::make_unique<OverlayLayerPool>()) {
  mask_view_pool_ =
      [[FlutterClippingMaskViewPool alloc] initWithCapacity:kFlutterClippingMaskViewPoolCapacity];
};

void PlatformViewsController::PushFilterToVisitedPlatformViews(
    const std::shared_ptr<DlImageFilter>& filter,
    const SkRect& filter_rect) {
  for (int64_t id : visited_platform_views_) {
    EmbeddedViewParams params = current_composition_params_[id];
    params.PushImageFilter(filter, filter_rect);
    current_composition_params_[id] = params;
  }
}

size_t PlatformViewsController::EmbeddedViewCount() const {
  return composition_order_.size();
}

long PlatformViewsController::FindFirstResponderPlatformViewId() {
  for (auto const& [id, platform_view_data] : platform_views_) {
    UIView* root_view = platform_view_data.root_view;
    if (root_view.flt_hasFirstResponderInViewHierarchySubtree) {
      return id;
    }
  }
  return -1;
}

void PlatformViewsController::ClipViewSetMaskView(UIView* clipView) {
  FML_DCHECK([[NSThread currentThread] isMainThread]);
  if (clipView.maskView) {
    return;
  }
  CGRect frame =
      CGRectMake(-clipView.frame.origin.x, -clipView.frame.origin.y,
                 CGRectGetWidth(flutter_view_.bounds), CGRectGetHeight(flutter_view_.bounds));
  clipView.maskView = [mask_view_pool_ getMaskViewWithFrame:frame];
}

// This method is only called when the `embedded_view` needs to be re-composited at the current
// frame. See: `CompositeWithParams` for details.
void PlatformViewsController::ApplyMutators(const MutatorsStack& mutators_stack,
                                            UIView* embedded_view,
                                            const SkRect& bounding_rect) {
  if (flutter_view_ == nullptr) {
    return;
  }

  ResetAnchor(embedded_view.layer);
  ChildClippingView* clipView = (ChildClippingView*)embedded_view.superview;

  SkMatrix transformMatrix;
  NSMutableArray* blurFilters = [[NSMutableArray alloc] init];
  FML_DCHECK(!clipView.maskView ||
             [clipView.maskView isKindOfClass:[FlutterClippingMaskView class]]);
  if (clipView.maskView) {
    [mask_view_pool_ insertViewToPoolIfNeeded:(FlutterClippingMaskView*)(clipView.maskView)];
    clipView.maskView = nil;
  }
  CGFloat screenScale = [UIScreen mainScreen].scale;
  auto iter = mutators_stack.Begin();
  while (iter != mutators_stack.End()) {
    switch ((*iter)->GetType()) {
      case kTransform: {
        transformMatrix.preConcat((*iter)->GetMatrix());
        break;
      }
      case kClipRect: {
        if (ClipRectContainsPlatformViewBoundingRect((*iter)->GetRect(), bounding_rect,
                                                     transformMatrix)) {
          break;
        }
        ClipViewSetMaskView(clipView);
        [(FlutterClippingMaskView*)clipView.maskView clipRect:(*iter)->GetRect()
                                                       matrix:transformMatrix];
        break;
      }
      case kClipRRect: {
        if (ClipRRectContainsPlatformViewBoundingRect((*iter)->GetRRect(), bounding_rect,
                                                      transformMatrix)) {
          break;
        }
        ClipViewSetMaskView(clipView);
        [(FlutterClippingMaskView*)clipView.maskView clipRRect:(*iter)->GetRRect()
                                                        matrix:transformMatrix];
        break;
      }
      case kClipPath: {
        // TODO(cyanglaz): Find a way to pre-determine if path contains the PlatformView boudning
        // rect. See `ClipRRectContainsPlatformViewBoundingRect`.
        // https://github.com/flutter/flutter/issues/118650
        ClipViewSetMaskView(clipView);
        [(FlutterClippingMaskView*)clipView.maskView clipPath:(*iter)->GetPath()
                                                       matrix:transformMatrix];
        break;
      }
      case kOpacity:
        embedded_view.alpha = (*iter)->GetAlphaFloat() * embedded_view.alpha;
        break;
      case kBackdropFilter: {
        // Only support DlBlurImageFilter for BackdropFilter.
        if (!canApplyBlurBackdrop || !(*iter)->GetFilterMutation().GetFilter().asBlur()) {
          break;
        }
        CGRect filterRect = GetCGRectFromSkRect((*iter)->GetFilterMutation().GetFilterRect());
        // `filterRect` is in global coordinates. We need to convert to local space.
        filterRect = CGRectApplyAffineTransform(
            filterRect, CGAffineTransformMakeScale(1 / screenScale, 1 / screenScale));
        // `filterRect` reprents the rect that should be filtered inside the `flutter_view_`.
        // The `PlatformViewFilter` needs the frame inside the `clipView` that needs to be
        // filtered.
        if (CGRectIsNull(CGRectIntersection(filterRect, clipView.frame))) {
          break;
        }
        CGRect intersection = CGRectIntersection(filterRect, clipView.frame);
        CGRect frameInClipView = [flutter_view_ convertRect:intersection toView:clipView];
        // sigma_x is arbitrarily chosen as the radius value because Quartz sets
        // sigma_x and sigma_y equal to each other. DlBlurImageFilter's Tile Mode
        // is not supported in Quartz's gaussianBlur CAFilter, so it is not used
        // to blur the PlatformView.
        CGFloat blurRadius = (*iter)->GetFilterMutation().GetFilter().asBlur()->sigma_x();
        UIVisualEffectView* visualEffectView = [[UIVisualEffectView alloc]
            initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
        PlatformViewFilter* filter = [[PlatformViewFilter alloc] initWithFrame:frameInClipView
                                                                    blurRadius:blurRadius
                                                              visualEffectView:visualEffectView];
        if (!filter) {
          canApplyBlurBackdrop = NO;
        } else {
          [blurFilters addObject:filter];
        }
        break;
      }
    }
    ++iter;
  }

  if (canApplyBlurBackdrop) {
    [clipView applyBlurBackdropFilters:blurFilters];
  }

  // The UIKit frame is set based on the logical resolution (points) instead of physical.
  // (https://developer.apple.com/library/archive/documentation/DeviceInformation/Reference/iOSDeviceCompatibility/Displays/Displays.html).
  // However, flow is based on the physical resolution. For example, 1000 pixels in flow equals
  // 500 points in UIKit for devices that has screenScale of 2. We need to scale the transformMatrix
  // down to the logical resoltion before applying it to the layer of PlatformView.
  transformMatrix.postScale(1 / screenScale, 1 / screenScale);

  // Reverse the offset of the clipView.
  // The clipView's frame includes the final translate of the final transform matrix.
  // Thus, this translate needs to be reversed so the platform view can layout at the correct
  // offset.
  //
  // Note that the transforms are not applied to the clipping paths because clipping paths happen on
  // the mask view, whose origin is always (0,0) to the flutter_view.
  transformMatrix.postTranslate(-clipView.frame.origin.x, -clipView.frame.origin.y);

  embedded_view.layer.transform = GetCATransform3DFromSkMatrix(transformMatrix);
}

// Composite the PlatformView with `view_id`.
//
// Every frame, during the paint traversal of the layer tree, this method is called for all
// the PlatformViews in `views_to_recomposite_`.
//
// Note that `views_to_recomposite_` does not represent all the views in the view hierarchy,
// if a PlatformView does not change its composition parameter from last frame, it is not
// included in the `views_to_recomposite_`.
void PlatformViewsController::CompositeWithParams(int64_t view_id,
                                                  const EmbeddedViewParams& params) {
  CGRect frame = CGRectMake(0, 0, params.sizePoints().width(), params.sizePoints().height());
  FlutterTouchInterceptingView* touchInterceptor = platform_views_[view_id].touch_interceptor;
#if FLUTTER_RUNTIME_MODE == FLUTTER_RUNTIME_MODE_DEBUG
  FML_DCHECK(CGPointEqualToPoint([touchInterceptor embeddedView].frame.origin, CGPointZero));
  if (non_zero_origin_views_.find(view_id) == non_zero_origin_views_.end() &&
      !CGPointEqualToPoint([touchInterceptor embeddedView].frame.origin, CGPointZero)) {
    non_zero_origin_views_.insert(view_id);
    NSLog(
        @"A Embedded PlatformView's origin is not CGPointZero.\n"
         "  View id: %@\n"
         "  View info: \n %@ \n"
         "A non-zero origin might cause undefined behavior.\n"
         "See https://github.com/flutter/flutter/issues/109700 for more details.\n"
         "If you are the author of the PlatformView, please update the implementation of the "
         "PlatformView to have a (0, 0) origin.\n"
         "If you have a valid case of using a non-zero origin, "
         "please leave a comment at https://github.com/flutter/flutter/issues/109700 with details.",
        @(view_id), [touchInterceptor embeddedView]);
  }
#endif
  touchInterceptor.layer.transform = CATransform3DIdentity;
  touchInterceptor.frame = frame;
  touchInterceptor.alpha = 1;

  const MutatorsStack& mutatorStack = params.mutatorsStack();
  UIView* clippingView = platform_views_[view_id].root_view;
  // The frame of the clipping view should be the final bounding rect.
  // Because the translate matrix in the Mutator Stack also includes the offset,
  // when we apply the transforms matrix in |ApplyMutators|, we need
  // to remember to do a reverse translate.
  const SkRect& rect = params.finalBoundingRect();
  CGFloat screenScale = [UIScreen mainScreen].scale;
  clippingView.frame = CGRectMake(rect.x() / screenScale, rect.y() / screenScale,
                                  rect.width() / screenScale, rect.height() / screenScale);
  ApplyMutators(mutatorStack, touchInterceptor, rect);
}

void PlatformViewsController::CreateMissingOverlays(GrDirectContext* gr_context,
                                                    const std::shared_ptr<IOSContext>& ios_context,
                                                    size_t required_overlay_layers) {
  TRACE_EVENT0("flutter", "PlatformViewsController::CreateMissingLayers");

  if (required_overlay_layers <= layer_pool_->size()) {
    return;
  }
  auto missing_layer_count = required_overlay_layers - layer_pool_->size();

  // If the raster thread isn't merged, create layers on the platform thread and block until
  // complete.
  auto latch = std::make_shared<fml::CountDownLatch>(1u);
  fml::TaskRunner::RunNowOrPostTask(platform_task_runner_, [&]() {
    for (auto i = 0u; i < missing_layer_count; i++) {
      CreateLayer(gr_context,                                //
                  ios_context,                               //
                  ((FlutterView*)flutter_view_).pixelFormat  //
      );
    }
    latch->CountDown();
  });
  if (![[NSThread currentThread] isMainThread]) {
    latch->Wait();
  }
}

/// Update the buffers and mutate the platform views in CATransaction on the platform thread.
void PlatformViewsController::PerformSubmit(
    const LayersMap& platform_view_layers,
    std::unordered_map<int64_t, EmbeddedViewParams>& current_composition_params,
    const std::unordered_set<int64_t>& views_to_recomposite,
    const std::vector<int64_t>& composition_order,
    const std::vector<std::shared_ptr<OverlayLayer>>& unused_layers,
    const std::vector<std::unique_ptr<SurfaceFrame>>& surface_frames) {
  TRACE_EVENT0("flutter", "PlatformViewsController::PerformSubmit");
  FML_DCHECK([[NSThread currentThread] isMainThread]);

  [CATransaction begin];

  // Configure Flutter overlay views.
  for (const auto& [view_id, layer_data] : platform_view_layers) {
    layer_data.layer->UpdateViewState(flutter_view_,         //
                                      layer_data.rect,       //
                                      layer_data.view_id,    //
                                      layer_data.overlay_id  //
    );
  }

  // Dispose unused Flutter Views.
  for (auto& view : GetViewsToDispose()) {
    [view removeFromSuperview];
  }

  // Composite Platform Views.
  for (int64_t view_id : views_to_recomposite) {
    CompositeWithParams(view_id, current_composition_params[view_id]);
  }

  // Present callbacks.
  for (const auto& frame : surface_frames) {
    frame->Submit();
  }

  // If a layer was allocated in the previous frame, but it's not used in the current frame,
  // then it can be removed from the scene.
  RemoveUnusedLayers(unused_layers, composition_order);

  // Organize the layers by their z indexes.
  BringLayersIntoView(platform_view_layers, composition_order);

  [CATransaction commit];
}

void PlatformViewsController::BringLayersIntoView(const LayersMap& layer_map,
                                                  const std::vector<int64_t>& composition_order) {
  FML_DCHECK(flutter_view_);
  UIView* flutter_view = flutter_view_;

  previous_composition_order_.clear();
  NSMutableArray* desired_platform_subviews = [NSMutableArray array];
  for (int64_t platform_view_id : composition_order) {
    previous_composition_order_.push_back(platform_view_id);
    UIView* platform_view_root = platform_views_[platform_view_id].root_view;
    if (platform_view_root != nil) {
      [desired_platform_subviews addObject:platform_view_root];
    }

    auto maybe_layer_data = layer_map.find(platform_view_id);
    if (maybe_layer_data != layer_map.end()) {
      auto view = maybe_layer_data->second.layer->overlay_view_wrapper;
      if (view != nil) {
        [desired_platform_subviews addObject:view];
      }
    }
  }

  NSSet* desired_platform_subviews_set = [NSSet setWithArray:desired_platform_subviews];
  NSArray* existing_platform_subviews = [flutter_view.subviews
      filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id object,
                                                                        NSDictionary* bindings) {
        return [desired_platform_subviews_set containsObject:object];
      }]];

  // Manipulate view hierarchy only if needed, to address a performance issue where
  // `BringLayersIntoView` is called even when view hierarchy stays the same.
  // See: https://github.com/flutter/flutter/issues/121833
  // TODO(hellohuanlin): investigate if it is possible to skip unnecessary BringLayersIntoView.
  if (![desired_platform_subviews isEqualToArray:existing_platform_subviews]) {
    for (UIView* subview in desired_platform_subviews) {
      // `addSubview` will automatically reorder subview if it is already added.
      [flutter_view addSubview:subview];
    }
  }
}

std::shared_ptr<OverlayLayer> PlatformViewsController::GetExistingLayer() {
  return layer_pool_->GetNextLayer();
}

void PlatformViewsController::CreateLayer(GrDirectContext* gr_context,
                                          const std::shared_ptr<IOSContext>& ios_context,
                                          MTLPixelFormat pixel_format) {
  layer_pool_->CreateLayer(gr_context, ios_context, pixel_format);
}

void PlatformViewsController::RemoveUnusedLayers(
    const std::vector<std::shared_ptr<OverlayLayer>>& unused_layers,
    const std::vector<int64_t>& composition_order) {
  for (const std::shared_ptr<OverlayLayer>& layer : unused_layers) {
    [layer->overlay_view_wrapper removeFromSuperview];
  }

  std::unordered_set<int64_t> composition_order_set;
  for (int64_t view_id : composition_order) {
    composition_order_set.insert(view_id);
  }
  // Remove unused platform views.
  for (int64_t view_id : previous_composition_order_) {
    if (composition_order_set.find(view_id) == composition_order_set.end()) {
      UIView* platform_view_root = platform_views_[view_id].root_view;
      [platform_view_root removeFromSuperview];
    }
  }
}

std::vector<UIView*> PlatformViewsController::GetViewsToDispose() {
  std::vector<UIView*> views;
  if (views_to_dispose_.empty()) {
    return views;
  }

  std::unordered_set<int64_t> views_to_composite(composition_order_.begin(),
                                                 composition_order_.end());
  std::unordered_set<int64_t> views_to_delay_dispose;
  for (int64_t viewId : views_to_dispose_) {
    if (views_to_composite.count(viewId)) {
      views_to_delay_dispose.insert(viewId);
      continue;
    }
    UIView* root_view = platform_views_[viewId].root_view;
    views.push_back(root_view);
    current_composition_params_.erase(viewId);
    views_to_recomposite_.erase(viewId);
    platform_views_.erase(viewId);
  }
  views_to_dispose_ = std::move(views_to_delay_dispose);
  return views;
}

void PlatformViewsController::ResetFrameState() {
  slices_.clear();
  composition_order_.clear();
  visited_platform_views_.clear();
}

}  // namespace flutter

@interface FlutterPlatformViewsController ()

// TODO(cbracken): Migrate all fields to Obj-C properties, then delete.
@property(nonatomic, readonly) std::unique_ptr<flutter::PlatformViewsController>& instance;

- (void)onCreate:(FlutterMethodCall*)call result:(FlutterResult)result;
- (void)onDispose:(FlutterMethodCall*)call result:(FlutterResult)result;
- (void)onAcceptGesture:(FlutterMethodCall*)call result:(FlutterResult)result;
- (void)onRejectGesture:(FlutterMethodCall*)call result:(FlutterResult)result;
@end

@implementation FlutterPlatformViewsController

// TODO(cbracken): once implementation has been migrated, synthesize ivars.
@dynamic taskRunner;
@dynamic flutterView;
@dynamic flutterViewController;

- (id)init {
  if (self = [super init]) {
    _instance = std::make_unique<flutter::PlatformViewsController>();
  }
  return self;
}

- (const fml::RefPtr<fml::TaskRunner>&)taskRunner {
  return self.instance->platform_task_runner_;
}

- (void)setTaskRunner:(const fml::RefPtr<fml::TaskRunner>&)platformTaskRunner {
  self.instance->platform_task_runner_ = platformTaskRunner;
}

- (UIView*)flutterView {
  return self.instance->flutter_view_;
}

- (void)setFlutterView:(UIView*)view {
  self.instance->flutter_view_ = view;
}

- (void)setFlutterViewController:(UIViewController<FlutterViewResponder>*)viewController {
  self.instance->flutter_view_controller_ = viewController;
}

- (UIViewController<FlutterViewResponder>*)flutterViewController {
  return self.instance->flutter_view_controller_;
}

- (void)registerViewFactory:(NSObject<FlutterPlatformViewFactory>*)factory
                              withId:(NSString*)factoryId
    gestureRecognizersBlockingPolicy:
        (FlutterPlatformViewGestureRecognizersBlockingPolicy)gestureRecognizerBlockingPolicy {
  std::string idString([factoryId UTF8String]);
  FML_CHECK(self.instance->factories_.count(idString) == 0);
  self.instance->factories_[idString] = factory;
  self.instance->gesture_recognizers_blocking_policies_[idString] = gestureRecognizerBlockingPolicy;
}

- (void)beginFrameWithSize:(SkISize)frameSize {
  self.instance->ResetFrameState();
  self.instance->frame_size_ = frameSize;
}

- (void)cancelFrame {
  self.instance->ResetFrameState();
}

- (void)prerollCompositeEmbeddedView:(int64_t)viewId
                          withParams:(std::unique_ptr<flutter::EmbeddedViewParams>)params {
  SkRect view_bounds = SkRect::Make(self.instance->frame_size_);
  std::unique_ptr<flutter::EmbedderViewSlice> view;
  view = std::make_unique<flutter::DisplayListEmbedderViewSlice>(view_bounds);
  self.instance->slices_.insert_or_assign(viewId, std::move(view));

  self.instance->composition_order_.push_back(viewId);

  if (self.instance->current_composition_params_.count(viewId) == 1 &&
      self.instance->current_composition_params_[viewId] == *params.get()) {
    // Do nothing if the params didn't change.
    return;
  }
  self.instance->current_composition_params_[viewId] = flutter::EmbeddedViewParams(*params.get());
  self.instance->views_to_recomposite_.insert(viewId);
}

- (FlutterTouchInterceptingView*)flutterTouchInterceptingViewForId:(int64_t)viewId {
  if (self.instance->platform_views_.empty()) {
    return nil;
  }
  return self.instance->platform_views_[viewId].touch_interceptor;
}

- (flutter::PostPrerollResult)postPrerollActionWithThreadMerger:
                                  (const fml::RefPtr<fml::RasterThreadMerger>&)rasterThreadMerger
                                                impellerEnabled:(BOOL)impellerEnabled {
  // TODO(jonahwilliams): remove this once Software backend is removed for iOS Sim.
#ifdef FML_OS_IOS_SIMULATOR
  const bool mergeThreads = true;
#else
  const bool mergeThreads = !impellerEnabled;
#endif  // FML_OS_IOS_SIMULATOR

  if (mergeThreads) {
    if (self.instance->composition_order_.empty()) {
      return flutter::PostPrerollResult::kSuccess;
    }
    if (!rasterThreadMerger->IsMerged()) {
      // The raster thread merger may be disabled if the rasterizer is being
      // created or teared down.
      //
      // In such cases, the current frame is dropped, and a new frame is attempted
      // with the same layer tree.
      //
      // Eventually, the frame is submitted once this method returns `kSuccess`.
      // At that point, the raster tasks are handled on the platform thread.
      [self cancelFrame];
      return flutter::PostPrerollResult::kSkipAndRetryFrame;
    }
    // If the post preroll action is successful, we will display platform views in the current
    // frame. In order to sync the rendering of the platform views (quartz) with skia's rendering,
    // We need to begin an explicit CATransaction. This transaction needs to be submitted
    // after the current frame is submitted.
    rasterThreadMerger->ExtendLeaseTo(kDefaultMergedLeaseDuration);
  }
  return flutter::PostPrerollResult::kSuccess;
}

- (void)endFrameWithResubmit:(BOOL)shouldResubmitFrame
                threadMerger:(const fml::RefPtr<fml::RasterThreadMerger>&)rasterThreadMerger
             impellerEnabled:(BOOL)impellerEnabled {
#if FML_OS_IOS_SIMULATOR
  BOOL runCheck = YES;
#else
  BOOL runCheck = !impellerEnabled;
#endif  // FML_OS_IOS_SIMULATOR
  if (runCheck && shouldResubmitFrame) {
    rasterThreadMerger->MergeWithLease(kDefaultMergedLeaseDuration);
  }
}

- (flutter::DlCanvas*)compositeEmbeddedViewWithId:(int64_t)viewId {
  return self.instance->slices_[viewId]->canvas();
}

- (void)reset {
  // Reset will only be called from the raster thread or a merged raster/platform thread.
  // platform_views_ must only be modified on the platform thread, and any operations that
  // read or modify platform views should occur there.
  fml::TaskRunner::RunNowOrPostTask(self.instance->platform_task_runner_,
                                    [&, composition_order = self.instance->composition_order_]() {
                                      for (int64_t view_id : self.instance->composition_order_) {
                                        [self.instance->platform_views_[view_id].root_view removeFromSuperview];
                                      }
                                      self.instance->platform_views_.clear();
                                    });

  self.instance->composition_order_.clear();
  self.instance->slices_.clear();
  self.instance->current_composition_params_.clear();
  self.instance->views_to_recomposite_.clear();
  self.instance->layer_pool_->RecycleLayers();
  self.instance->visited_platform_views_.clear();
}

- (BOOL)submitFrame:(std::unique_ptr<flutter::SurfaceFrame>)background_frame
     withIosContext:(const std::shared_ptr<flutter::IOSContext>&)ios_context
          grContext:(GrDirectContext*)gr_context {
  TRACE_EVENT0("flutter", "PlatformViewsController::SubmitFrame");

  // No platform views to render; we're done.
  if (self.instance->flutter_view_ == nullptr || (self.instance->composition_order_.empty() &&
    !self.instance->had_platform_views_)) {
    self.instance->had_platform_views_ = false;
    return background_frame->Submit();
  }
  self.instance->had_platform_views_ = !self.instance->composition_order_.empty();

  bool did_encode = true;
  LayersMap platform_view_layers;
  std::vector<std::unique_ptr<flutter::SurfaceFrame>> surface_frames;
  surface_frames.reserve(self.instance->composition_order_.size());
  std::unordered_map<int64_t, SkRect> view_rects;

  for (int64_t view_id : self.instance->composition_order_) {
    view_rects[view_id] = self.instance->current_composition_params_[view_id].finalBoundingRect();
  }

  std::unordered_map<int64_t, SkRect> overlay_layers =
      SliceViews(background_frame->Canvas(), self.instance->composition_order_, self.instance->slices_, view_rects);

  size_t required_overlay_layers = 0;
  for (int64_t view_id : self.instance->composition_order_) {
    std::unordered_map<int64_t, SkRect>::const_iterator overlay = overlay_layers.find(view_id);
    if (overlay == overlay_layers.end()) {
      continue;
    }
    required_overlay_layers++;
  }

  // If there are not sufficient overlay layers, we must construct them on the platform
  // thread, at least until we've refactored iOS surface creation to use IOSurfaces
  // instead of CALayers.
  self.instance->CreateMissingOverlays(gr_context, ios_context, required_overlay_layers);

  int64_t overlay_id = 0;
  for (int64_t view_id : self.instance->composition_order_) {
    std::unordered_map<int64_t, SkRect>::const_iterator overlay = overlay_layers.find(view_id);
    if (overlay == overlay_layers.end()) {
      continue;
    }
    std::shared_ptr<flutter::OverlayLayer> layer = self.instance->GetExistingLayer();
    if (!layer) {
      continue;
    }

    std::unique_ptr<flutter::SurfaceFrame> frame = layer->surface->AcquireFrame(self.instance->frame_size_);
    // If frame is null, AcquireFrame already printed out an error message.
    if (!frame) {
      continue;
    }
    flutter::DlCanvas* overlay_canvas = frame->Canvas();
    int restore_count = overlay_canvas->GetSaveCount();
    overlay_canvas->Save();
    overlay_canvas->ClipRect(overlay->second);
    overlay_canvas->Clear(flutter::DlColor::kTransparent());
    self.instance->slices_[view_id]->render_into(overlay_canvas);
    overlay_canvas->RestoreToCount(restore_count);

    // This flutter view is never the last in a frame, since we always submit the
    // underlay view last.
    frame->set_submit_info({.frame_boundary = false, .present_with_transaction = true});
    layer->did_submit_last_frame = frame->Encode();

    did_encode &= layer->did_submit_last_frame;
    platform_view_layers[view_id] = LayerData{
        .rect = overlay->second,   //
        .view_id = view_id,        //
        .overlay_id = overlay_id,  //
        .layer = layer             //
    };
    surface_frames.push_back(std::move(frame));
    overlay_id++;
  }

  auto previous_submit_info = background_frame->submit_info();
  background_frame->set_submit_info({
      .frame_damage = previous_submit_info.frame_damage,
      .buffer_damage = previous_submit_info.buffer_damage,
      .present_with_transaction = true,
  });
  background_frame->Encode();
  surface_frames.push_back(std::move(background_frame));

  // Mark all layers as available, so they can be used in the next frame.
  std::vector<std::shared_ptr<flutter::OverlayLayer>> unused_layers = self.instance->layer_pool_->RemoveUnusedLayers();
  self.instance->layer_pool_->RecycleLayers();

  auto task = [&,                                                         //
               platform_view_layers = std::move(platform_view_layers),    //
               current_composition_params = self.instance->current_composition_params_,  //
               views_to_recomposite = self.instance->views_to_recomposite_,              //
               composition_order = self.instance->composition_order_,                    //
               unused_layers = std::move(unused_layers),                  //
               surface_frames = std::move(surface_frames)                 //
  ]() mutable {
    self.instance->PerformSubmit(platform_view_layers,        //
                  current_composition_params,  //
                  views_to_recomposite,        //
                  composition_order,           //
                  unused_layers,               //
                  surface_frames               //
    );
  };

  fml::TaskRunner::RunNowOrPostTask(self.instance->platform_task_runner_, fml::MakeCopyable(std::move(task)));

  return did_encode;
}

- (long)firstResponderPlatformViewId {
  return self.instance->FindFirstResponderPlatformViewId();
}

- (void)pushFilterToVisitedPlatformViews:(const std::shared_ptr<flutter::DlImageFilter>&)filter
                                withRect:(const SkRect&)filterRect {
  return self.instance->PushFilterToVisitedPlatformViews(filter, filterRect);
}

- (void)pushVisitedPlatformViewId:(int64_t)viewId {
  return self.instance->PushVisitedPlatformView(viewId);
}

- (size_t)embeddedViewCount {
  return self.instance->EmbeddedViewCount();
}

- (UIView*)platformViewForId:(int64_t)viewId {
  return [self flutterTouchInterceptingViewForId:viewId].embeddedView;
}

- (void)compositeView:(int64_t)viewId withParams:(const flutter::EmbeddedViewParams&)params {
  return self.instance->CompositeWithParams(viewId, params);
}

- (const flutter::EmbeddedViewParams&)compositionParamsForView:(int64_t)viewId {
  return self.instance->current_composition_params_.find(viewId)->second;
}

- (void)onMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([[call method] isEqualToString:@"create"]) {
    [self onCreate:call result:result];
  } else if ([[call method] isEqualToString:@"dispose"]) {
    [self onDispose:call result:result];
  } else if ([[call method] isEqualToString:@"acceptGesture"]) {
    [self onAcceptGesture:call result:result];
  } else if ([[call method] isEqualToString:@"rejectGesture"]) {
    [self onRejectGesture:call result:result];
  } else {
    result(FlutterMethodNotImplemented);
  }
}

- (void)onCreate:(FlutterMethodCall*)call result:(FlutterResult)result {
  NSDictionary<NSString*, id>* args = [call arguments];

  int64_t viewId = [args[@"id"] longLongValue];
  NSString* viewTypeString = args[@"viewType"];
  std::string viewType(viewTypeString.UTF8String);

  if (self.instance->platform_views_.count(viewId) != 0) {
    result([FlutterError errorWithCode:@"recreating_view"
                               message:@"trying to create an already created view"
                               details:[NSString stringWithFormat:@"view id: '%lld'", viewId]]);
    return;
  }

  NSObject<FlutterPlatformViewFactory>* factory = self.instance->factories_[viewType];
  if (factory == nil) {
    result([FlutterError
        errorWithCode:@"unregistered_view_type"
              message:[NSString stringWithFormat:@"A UIKitView widget is trying to create a "
                                                 @"PlatformView with an unregistered type: < %@ >",
                                                 viewTypeString]
              details:@"If you are the author of the PlatformView, make sure `registerViewFactory` "
                      @"is invoked.\n"
                      @"See: "
                      @"https://docs.flutter.dev/development/platform-integration/"
                      @"platform-views#on-the-platform-side-1 for more details.\n"
                      @"If you are not the author of the PlatformView, make sure to call "
                      @"`GeneratedPluginRegistrant.register`."]);
    return;
  }

  id params = nil;
  if ([factory respondsToSelector:@selector(createArgsCodec)]) {
    NSObject<FlutterMessageCodec>* codec = [factory createArgsCodec];
    if (codec != nil && args[@"params"] != nil) {
      FlutterStandardTypedData* paramsData = args[@"params"];
      params = [codec decode:paramsData.data];
    }
  }

  NSObject<FlutterPlatformView>* embedded_view = [factory createWithFrame:CGRectZero
                                                           viewIdentifier:viewId
                                                                arguments:params];
  UIView* platform_view = [embedded_view view];
  // Set a unique view identifier, so the platform view can be identified in unit tests.
  platform_view.accessibilityIdentifier =
      [NSString stringWithFormat:@"platform_view[%lld]", viewId];

  FlutterTouchInterceptingView* touch_interceptor = [[FlutterTouchInterceptingView alloc]
                  initWithEmbeddedView:platform_view
               platformViewsController:self
      gestureRecognizersBlockingPolicy:self.instance
                                           ->gesture_recognizers_blocking_policies_[viewType]];

  ChildClippingView* clipping_view = [[ChildClippingView alloc] initWithFrame:CGRectZero];
  [clipping_view addSubview:touch_interceptor];

  self.instance->platform_views_.emplace(viewId, PlatformViewData{
                                                     .view = embedded_view,                   //
                                                     .touch_interceptor = touch_interceptor,  //
                                                     .root_view = clipping_view               //
                                                 });

  result(nil);
}

- (void)onDispose:(FlutterMethodCall*)call result:(FlutterResult)result {
  NSNumber* arg = [call arguments];
  int64_t viewId = [arg longLongValue];

  if (self.instance->platform_views_.count(viewId) == 0) {
    result([FlutterError errorWithCode:@"unknown_view"
                               message:@"trying to dispose an unknown"
                               details:[NSString stringWithFormat:@"view id: '%lld'", viewId]]);
    return;
  }
  // We wait for next submitFrame to dispose views.
  self.instance->views_to_dispose_.insert(viewId);
  result(nil);
}

- (void)onAcceptGesture:(FlutterMethodCall*)call result:(FlutterResult)result {
  NSDictionary<NSString*, id>* args = [call arguments];
  int64_t viewId = [args[@"id"] longLongValue];

  if (self.instance->platform_views_.count(viewId) == 0) {
    result([FlutterError errorWithCode:@"unknown_view"
                               message:@"trying to set gesture state for an unknown view"
                               details:[NSString stringWithFormat:@"view id: '%lld'", viewId]]);
    return;
  }

  FlutterTouchInterceptingView* view = self.instance->platform_views_[viewId].touch_interceptor;
  [view releaseGesture];

  result(nil);
}

- (void)onRejectGesture:(FlutterMethodCall*)call result:(FlutterResult)result {
  NSDictionary<NSString*, id>* args = [call arguments];
  int64_t viewId = [args[@"id"] longLongValue];

  if (self.instance->platform_views_.count(viewId) == 0) {
    result([FlutterError errorWithCode:@"unknown_view"
                               message:@"trying to set gesture state for an unknown view"
                               details:[NSString stringWithFormat:@"view id: '%lld'", viewId]]);
    return;
  }

  FlutterTouchInterceptingView* view = self.instance->platform_views_[viewId].touch_interceptor;
  [view blockGesture];

  result(nil);
}

@end
