// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <OCMock/OCMock.h>
#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#include "fml/synchronization/count_down_latch.h"

#import "flutter/fml/thread.h"
#import "flutter/shell/platform/darwin/common/framework/Headers/FlutterMacros.h"
#import "flutter/shell/platform/darwin/ios/framework/Headers/FlutterPlatformViews.h"
#import "flutter/shell/platform/darwin/ios/framework/Headers/FlutterViewController.h"
#import "flutter/shell/platform/darwin/ios/framework/Source/FlutterPlatformViews_Internal.h"
#import "flutter/shell/platform/darwin/ios/framework/Source/FlutterTouchInterceptingView_Test.h"
#import "flutter/shell/platform/darwin/ios/platform_view_ios.h"

FLUTTER_ASSERT_ARC

@class FlutterPlatformViewsTestMockPlatformView;
__weak static FlutterPlatformViewsTestMockPlatformView* gMockPlatformView = nil;
const float kFloatCompareEpsilon = 0.001;

@interface FlutterPlatformViewsTestMockPlatformView : UIView
@end
@implementation FlutterPlatformViewsTestMockPlatformView

- (instancetype)init {
  self = [super init];
  if (self) {
    gMockPlatformView = self;
  }
  return self;
}

- (void)dealloc {
  gMockPlatformView = nil;
}

@end

@interface FlutterPlatformViewsTestMockFlutterPlatformView : NSObject <FlutterPlatformView>
@property(nonatomic, strong) UIView* view;
@property(nonatomic, assign) BOOL viewCreated;
@end

@implementation FlutterPlatformViewsTestMockFlutterPlatformView

- (instancetype)init {
  if (self = [super init]) {
    _view = [[FlutterPlatformViewsTestMockPlatformView alloc] init];
    _viewCreated = NO;
  }
  return self;
}

- (UIView*)view {
  [self checkViewCreatedOnce];
  return _view;
}

- (void)checkViewCreatedOnce {
  if (self.viewCreated) {
    abort();
  }
  self.viewCreated = YES;
}

@end

@interface FlutterPlatformViewsTestMockFlutterPlatformFactory
    : NSObject <FlutterPlatformViewFactory>
@end

@implementation FlutterPlatformViewsTestMockFlutterPlatformFactory
- (NSObject<FlutterPlatformView>*)createWithFrame:(CGRect)frame
                                   viewIdentifier:(int64_t)viewId
                                        arguments:(id _Nullable)args {
  return [[FlutterPlatformViewsTestMockFlutterPlatformView alloc] init];
}

@end

namespace flutter {
namespace {
class FlutterPlatformViewsTestMockPlatformViewDelegate : public PlatformView::Delegate {
 public:
  void OnPlatformViewCreated(std::unique_ptr<Surface> surface) override {}
  void OnPlatformViewDestroyed() override {}
  void OnPlatformViewScheduleFrame() override {}
  void OnPlatformViewAddView(int64_t view_id,
                             const ViewportMetrics& viewport_metrics,
                             AddViewCallback callback) override {}
  void OnPlatformViewRemoveView(int64_t view_id, RemoveViewCallback callback) override {}
  void OnPlatformViewSetNextFrameCallback(const fml::closure& closure) override {}
  void OnPlatformViewSetViewportMetrics(int64_t view_id, const ViewportMetrics& metrics) override {}
  const flutter::Settings& OnPlatformViewGetSettings() const override { return settings_; }
  void OnPlatformViewDispatchPlatformMessage(std::unique_ptr<PlatformMessage> message) override {}
  void OnPlatformViewDispatchPointerDataPacket(std::unique_ptr<PointerDataPacket> packet) override {
  }
  void OnPlatformViewDispatchSemanticsAction(int32_t id,
                                             SemanticsAction action,
                                             fml::MallocMapping args) override {}
  void OnPlatformViewSetSemanticsEnabled(bool enabled) override {}
  void OnPlatformViewSetAccessibilityFeatures(int32_t flags) override {}
  void OnPlatformViewRegisterTexture(std::shared_ptr<Texture> texture) override {}
  void OnPlatformViewUnregisterTexture(int64_t texture_id) override {}
  void OnPlatformViewMarkTextureFrameAvailable(int64_t texture_id) override {}

  void LoadDartDeferredLibrary(intptr_t loading_unit_id,
                               std::unique_ptr<const fml::Mapping> snapshot_data,
                               std::unique_ptr<const fml::Mapping> snapshot_instructions) override {
  }
  void LoadDartDeferredLibraryError(intptr_t loading_unit_id,
                                    const std::string error_message,
                                    bool transient) override {}
  void UpdateAssetResolverByType(std::unique_ptr<flutter::AssetResolver> updated_asset_resolver,
                                 flutter::AssetResolver::AssetResolverType type) override {}

  flutter::Settings settings_;
};

}  // namespace
}  // namespace flutter

@interface FlutterPlatformViewsTest : XCTestCase
@end

@implementation FlutterPlatformViewsTest

- (void)testFlutterViewOnlyCreateOnceInOneFrame {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread = std::make_unique<fml::Thread>("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread->GetTaskRunner(),
                               /*raster=*/thread->GetTaskRunner(),
                               /*ui=*/thread->GetTaskRunner(),
                               /*io=*/thread->GetTaskRunner());
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  flutterPlatformViewsController->SetTaskRunner(thread->GetTaskRunner());
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/mock_delegate.settings_.enable_impeller
          ? flutter::IOSRenderingAPI::kMetal
          : flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners,
      /*worker_task_runner=*/nil,
      /*is_gpu_disabled_jsync_switch=*/std::make_shared<fml::SyncSwitch>());

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory alloc] init];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
      result);
  UIView* flutterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 500, 500)];
  flutterPlatformViewsController->SetFlutterView(flutterView);
  // Create embedded view params
  flutter::MutatorsStack stack;
  // Layer tree always pushes a screen scale factor to the stack
  SkMatrix screenScaleMatrix =
      SkMatrix::Scale([UIScreen mainScreen].scale, [UIScreen mainScreen].scale);
  stack.PushTransform(screenScaleMatrix);
  // Push a translate matrix
  SkMatrix translateMatrix = SkMatrix::Translate(100, 100);
  stack.PushTransform(translateMatrix);
  SkMatrix finalMatrix;
  finalMatrix.setConcat(screenScaleMatrix, translateMatrix);

  auto embeddedViewParams =
      std::make_unique<flutter::EmbeddedViewParams>(finalMatrix, SkSize::Make(300, 300), stack);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
  flutterPlatformViewsController->CompositeEmbeddedView(2);

  XCTAssertNotNil(gMockPlatformView);

  flutterPlatformViewsController->Reset();
}

- (void)testCanCreatePlatformViewWithoutFlutterView {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread = std::make_unique<fml::Thread>("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread->GetTaskRunner(),
                               /*raster=*/thread->GetTaskRunner(),
                               /*ui=*/thread->GetTaskRunner(),
                               /*io=*/thread->GetTaskRunner());
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  flutterPlatformViewsController->SetTaskRunner(thread->GetTaskRunner());
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/mock_delegate.settings_.enable_impeller
          ? flutter::IOSRenderingAPI::kMetal
          : flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners,
      /*worker_task_runner=*/nil,
      /*is_gpu_disabled_jsync_switch=*/std::make_shared<fml::SyncSwitch>());

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory alloc] init];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  XCTAssertNotNil(gMockPlatformView);
}

- (void)testChildClippingViewHitTests {
  ChildClippingView* childClippingView =
      [[ChildClippingView alloc] initWithFrame:CGRectMake(0, 0, 500, 500)];
  UIView* childView = [[UIView alloc] initWithFrame:CGRectMake(100, 100, 100, 100)];
  [childClippingView addSubview:childView];

  XCTAssertFalse([childClippingView pointInside:CGPointMake(50, 50) withEvent:nil]);
  XCTAssertFalse([childClippingView pointInside:CGPointMake(99, 100) withEvent:nil]);
  XCTAssertFalse([childClippingView pointInside:CGPointMake(100, 99) withEvent:nil]);
  XCTAssertFalse([childClippingView pointInside:CGPointMake(201, 200) withEvent:nil]);
  XCTAssertFalse([childClippingView pointInside:CGPointMake(200, 201) withEvent:nil]);
  XCTAssertFalse([childClippingView pointInside:CGPointMake(99, 200) withEvent:nil]);
  XCTAssertFalse([childClippingView pointInside:CGPointMake(200, 299) withEvent:nil]);

  XCTAssertTrue([childClippingView pointInside:CGPointMake(150, 150) withEvent:nil]);
  XCTAssertTrue([childClippingView pointInside:CGPointMake(100, 100) withEvent:nil]);
  XCTAssertTrue([childClippingView pointInside:CGPointMake(199, 100) withEvent:nil]);
  XCTAssertTrue([childClippingView pointInside:CGPointMake(100, 199) withEvent:nil]);
  XCTAssertTrue([childClippingView pointInside:CGPointMake(199, 199) withEvent:nil]);
}

- (void)testReleasesBackdropFilterSubviewsOnChildClippingViewDealloc {
  __weak NSMutableArray<UIVisualEffectView*>* weakBackdropFilterSubviews = nil;
  __weak UIVisualEffectView* weakVisualEffectView1 = nil;
  __weak UIVisualEffectView* weakVisualEffectView2 = nil;

  @autoreleasepool {
    ChildClippingView* clippingView = [[ChildClippingView alloc] initWithFrame:CGRectZero];
    UIVisualEffectView* visualEffectView1 = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
    weakVisualEffectView1 = visualEffectView1;
    PlatformViewFilter* platformViewFilter1 =
        [[PlatformViewFilter alloc] initWithFrame:CGRectMake(0, 0, 10, 10)
                                       blurRadius:5
                                 visualEffectView:visualEffectView1];

    [clippingView applyBlurBackdropFilters:@[ platformViewFilter1 ]];

    // Replace the blur filter to validate the original and new UIVisualEffectView are released.
    UIVisualEffectView* visualEffectView2 = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    weakVisualEffectView2 = visualEffectView2;
    PlatformViewFilter* platformViewFilter2 =
        [[PlatformViewFilter alloc] initWithFrame:CGRectMake(0, 0, 10, 10)
                                       blurRadius:5
                                 visualEffectView:visualEffectView2];
    [clippingView applyBlurBackdropFilters:@[ platformViewFilter2 ]];

    weakBackdropFilterSubviews = clippingView.backdropFilterSubviews;
    XCTAssertNotNil(weakBackdropFilterSubviews);
    clippingView = nil;
  }
  XCTAssertNil(weakBackdropFilterSubviews);
  XCTAssertNil(weakVisualEffectView1);
  XCTAssertNil(weakVisualEffectView2);
}

- (void)testApplyBackdropFilter {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread = std::make_unique<fml::Thread>("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread->GetTaskRunner(),
                               /*raster=*/thread->GetTaskRunner(),
                               /*ui=*/thread->GetTaskRunner(),
                               /*io=*/thread->GetTaskRunner());
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  flutterPlatformViewsController->SetTaskRunner(thread->GetTaskRunner());
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/mock_delegate.settings_.enable_impeller
          ? flutter::IOSRenderingAPI::kMetal
          : flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners,
      /*worker_task_runner=*/nil,
      /*is_gpu_disabled_jsync_switch=*/std::make_shared<fml::SyncSwitch>());

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory alloc] init];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  XCTAssertNotNil(gMockPlatformView);

  UIView* flutterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
  flutterPlatformViewsController->SetFlutterView(flutterView);
  // Create embedded view params
  flutter::MutatorsStack stack;
  // Layer tree always pushes a screen scale factor to the stack
  CGFloat screenScale = [UIScreen mainScreen].scale;
  SkMatrix screenScaleMatrix = SkMatrix::Scale(screenScale, screenScale);
  stack.PushTransform(screenScaleMatrix);
  // Push a backdrop filter
  auto filter = std::make_shared<flutter::DlBlurImageFilter>(5, 2, flutter::DlTileMode::kClamp);
  stack.PushBackdropFilter(filter, SkRect::MakeXYWH(0, 0, screenScale * 10, screenScale * 10));

  auto embeddedViewParams =
      std::make_unique<flutter::EmbeddedViewParams>(screenScaleMatrix, SkSize::Make(10, 10), stack);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  flutterPlatformViewsController->CompositeWithParams(
      2, flutterPlatformViewsController->GetCompositionParams(2));

  XCTAssertTrue([gMockPlatformView.superview.superview isKindOfClass:[ChildClippingView class]]);
  ChildClippingView* childClippingView = (ChildClippingView*)gMockPlatformView.superview.superview;
  [flutterView addSubview:childClippingView];

  [flutterView setNeedsLayout];
  [flutterView layoutIfNeeded];

  // childClippingView has visual effect view with the correct configurations.
  NSUInteger numberOfExpectedVisualEffectView = 0;
  for (UIView* subview in childClippingView.subviews) {
    if (![subview isKindOfClass:[UIVisualEffectView class]]) {
      continue;
    }
    XCTAssertLessThan(numberOfExpectedVisualEffectView, 1u);
    if ([self validateOneVisualEffectView:subview
                            expectedFrame:CGRectMake(0, 0, 10, 10)
                              inputRadius:5]) {
      numberOfExpectedVisualEffectView++;
    }
  }
  XCTAssertEqual(numberOfExpectedVisualEffectView, 1u);
}

- (void)testApplyBackdropFilterWithCorrectFrame {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread = std::make_unique<fml::Thread>("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread->GetTaskRunner(),
                               /*raster=*/thread->GetTaskRunner(),
                               /*ui=*/thread->GetTaskRunner(),
                               /*io=*/thread->GetTaskRunner());
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  flutterPlatformViewsController->SetTaskRunner(thread->GetTaskRunner());
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/mock_delegate.settings_.enable_impeller
          ? flutter::IOSRenderingAPI::kMetal
          : flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners,
      /*worker_task_runner=*/nil,
      /*is_gpu_disabled_jsync_switch=*/std::make_shared<fml::SyncSwitch>());

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory alloc] init];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  XCTAssertNotNil(gMockPlatformView);

  UIView* flutterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
  flutterPlatformViewsController->SetFlutterView(flutterView);
  // Create embedded view params
  flutter::MutatorsStack stack;
  // Layer tree always pushes a screen scale factor to the stack
  CGFloat screenScale = [UIScreen mainScreen].scale;
  SkMatrix screenScaleMatrix = SkMatrix::Scale(screenScale, screenScale);
  stack.PushTransform(screenScaleMatrix);
  // Push a backdrop filter
  auto filter = std::make_shared<flutter::DlBlurImageFilter>(5, 2, flutter::DlTileMode::kClamp);
  stack.PushBackdropFilter(filter, SkRect::MakeXYWH(0, 0, screenScale * 8, screenScale * 8));

  auto embeddedViewParams =
      std::make_unique<flutter::EmbeddedViewParams>(screenScaleMatrix, SkSize::Make(5, 10), stack);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  flutterPlatformViewsController->CompositeWithParams(
      2, flutterPlatformViewsController->GetCompositionParams(2));

  XCTAssertTrue([gMockPlatformView.superview.superview isKindOfClass:[ChildClippingView class]]);
  ChildClippingView* childClippingView = (ChildClippingView*)gMockPlatformView.superview.superview;
  [flutterView addSubview:childClippingView];

  [flutterView setNeedsLayout];
  [flutterView layoutIfNeeded];

  // childClippingView has visual effect view with the correct configurations.
  NSUInteger numberOfExpectedVisualEffectView = 0;
  for (UIView* subview in childClippingView.subviews) {
    if (![subview isKindOfClass:[UIVisualEffectView class]]) {
      continue;
    }
    XCTAssertLessThan(numberOfExpectedVisualEffectView, 1u);
    if ([self validateOneVisualEffectView:subview
                            expectedFrame:CGRectMake(0, 0, 5, 8)
                              inputRadius:5]) {
      numberOfExpectedVisualEffectView++;
    }
  }
  XCTAssertEqual(numberOfExpectedVisualEffectView, 1u);
}

- (void)testApplyMultipleBackdropFilters {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread = std::make_unique<fml::Thread>("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread->GetTaskRunner(),
                               /*raster=*/thread->GetTaskRunner(),
                               /*ui=*/thread->GetTaskRunner(),
                               /*io=*/thread->GetTaskRunner());
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  flutterPlatformViewsController->SetTaskRunner(thread->GetTaskRunner());
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/mock_delegate.settings_.enable_impeller
          ? flutter::IOSRenderingAPI::kMetal
          : flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners,
      /*worker_task_runner=*/nil,
      /*is_gpu_disabled_jsync_switch=*/std::make_shared<fml::SyncSwitch>());

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory alloc] init];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  XCTAssertNotNil(gMockPlatformView);

  UIView* flutterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
  flutterPlatformViewsController->SetFlutterView(flutterView);
  // Create embedded view params
  flutter::MutatorsStack stack;
  // Layer tree always pushes a screen scale factor to the stack
  CGFloat screenScale = [UIScreen mainScreen].scale;
  SkMatrix screenScaleMatrix = SkMatrix::Scale(screenScale, screenScale);
  stack.PushTransform(screenScaleMatrix);
  // Push backdrop filters
  for (int i = 0; i < 50; i++) {
    auto filter = std::make_shared<flutter::DlBlurImageFilter>(i, 2, flutter::DlTileMode::kClamp);
    stack.PushBackdropFilter(filter, SkRect::MakeXYWH(0, 0, screenScale * 10, screenScale * 10));
  }

  auto embeddedViewParams =
      std::make_unique<flutter::EmbeddedViewParams>(screenScaleMatrix, SkSize::Make(20, 20), stack);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  flutterPlatformViewsController->CompositeWithParams(
      2, flutterPlatformViewsController->GetCompositionParams(2));

  XCTAssertTrue([gMockPlatformView.superview.superview isKindOfClass:ChildClippingView.class]);
  ChildClippingView* childClippingView = (ChildClippingView*)gMockPlatformView.superview.superview;
  [flutterView addSubview:childClippingView];

  [flutterView setNeedsLayout];
  [flutterView layoutIfNeeded];

  NSUInteger numberOfExpectedVisualEffectView = 0;
  for (UIView* subview in childClippingView.subviews) {
    if (![subview isKindOfClass:[UIVisualEffectView class]]) {
      continue;
    }
    XCTAssertLessThan(numberOfExpectedVisualEffectView, 50u);
    if ([self validateOneVisualEffectView:subview
                            expectedFrame:CGRectMake(0, 0, 10, 10)
                              inputRadius:(CGFloat)numberOfExpectedVisualEffectView]) {
      numberOfExpectedVisualEffectView++;
    }
  }
  XCTAssertEqual(numberOfExpectedVisualEffectView, (NSUInteger)numberOfExpectedVisualEffectView);
}

- (void)testAddBackdropFilters {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread = std::make_unique<fml::Thread>("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread->GetTaskRunner(),
                               /*raster=*/thread->GetTaskRunner(),
                               /*ui=*/thread->GetTaskRunner(),
                               /*io=*/thread->GetTaskRunner());
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  flutterPlatformViewsController->SetTaskRunner(thread->GetTaskRunner());
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/mock_delegate.settings_.enable_impeller
          ? flutter::IOSRenderingAPI::kMetal
          : flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners,
      /*worker_task_runner=*/nil,
      /*is_gpu_disabled_jsync_switch=*/std::make_shared<fml::SyncSwitch>());

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory alloc] init];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  XCTAssertNotNil(gMockPlatformView);

  UIView* flutterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
  flutterPlatformViewsController->SetFlutterView(flutterView);
  // Create embedded view params
  flutter::MutatorsStack stack;
  // Layer tree always pushes a screen scale factor to the stack
  CGFloat screenScale = [UIScreen mainScreen].scale;
  SkMatrix screenScaleMatrix = SkMatrix::Scale(screenScale, screenScale);
  stack.PushTransform(screenScaleMatrix);
  // Push a backdrop filter
  auto filter = std::make_shared<flutter::DlBlurImageFilter>(5, 2, flutter::DlTileMode::kClamp);
  stack.PushBackdropFilter(filter, SkRect::MakeXYWH(0, 0, screenScale * 10, screenScale * 10));

  auto embeddedViewParams =
      std::make_unique<flutter::EmbeddedViewParams>(screenScaleMatrix, SkSize::Make(10, 10), stack);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  flutterPlatformViewsController->CompositeWithParams(
      2, flutterPlatformViewsController->GetCompositionParams(2));

  XCTAssertTrue([gMockPlatformView.superview.superview isKindOfClass:[ChildClippingView class]]);
  ChildClippingView* childClippingView = (ChildClippingView*)gMockPlatformView.superview.superview;
  [flutterView addSubview:childClippingView];

  [flutterView setNeedsLayout];
  [flutterView layoutIfNeeded];

  NSMutableArray* originalVisualEffectViews = [[NSMutableArray alloc] init];
  for (UIView* subview in childClippingView.subviews) {
    if (![subview isKindOfClass:[UIVisualEffectView class]]) {
      continue;
    }
    XCTAssertLessThan(originalVisualEffectViews.count, 1u);
    if ([self validateOneVisualEffectView:subview
                            expectedFrame:CGRectMake(0, 0, 10, 10)
                              inputRadius:(CGFloat)5]) {
      [originalVisualEffectViews addObject:subview];
    }
  }
  XCTAssertEqual(originalVisualEffectViews.count, 1u);

  //
  // Simulate adding 1 backdrop filter (create a new mutators stack)
  // Create embedded view params
  flutter::MutatorsStack stack2;
  // Layer tree always pushes a screen scale factor to the stack
  stack2.PushTransform(screenScaleMatrix);
  // Push backdrop filters
  for (int i = 0; i < 2; i++) {
    stack2.PushBackdropFilter(filter, SkRect::MakeXYWH(0, 0, screenScale * 10, screenScale * 10));
  }

  embeddedViewParams = std::make_unique<flutter::EmbeddedViewParams>(screenScaleMatrix,
                                                                     SkSize::Make(10, 10), stack2);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  flutterPlatformViewsController->CompositeWithParams(
      2, flutterPlatformViewsController->GetCompositionParams(2));

  [flutterView setNeedsLayout];
  [flutterView layoutIfNeeded];

  NSMutableArray* newVisualEffectViews = [[NSMutableArray alloc] init];
  for (UIView* subview in childClippingView.subviews) {
    if (![subview isKindOfClass:[UIVisualEffectView class]]) {
      continue;
    }
    XCTAssertLessThan(newVisualEffectViews.count, 2u);

    if ([self validateOneVisualEffectView:subview
                            expectedFrame:CGRectMake(0, 0, 10, 10)
                              inputRadius:(CGFloat)5]) {
      [newVisualEffectViews addObject:subview];
    }
  }
  XCTAssertEqual(newVisualEffectViews.count, 2u);
  for (NSUInteger i = 0; i < originalVisualEffectViews.count; i++) {
    UIView* originalView = originalVisualEffectViews[i];
    UIView* newView = newVisualEffectViews[i];
    // Compare reference.
    XCTAssertEqual(originalView, newView);
    id mockOrignalView = OCMPartialMock(originalView);
    OCMReject([mockOrignalView removeFromSuperview]);
    [mockOrignalView stopMocking];
  }
}

- (void)testRemoveBackdropFilters {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread = std::make_unique<fml::Thread>("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread->GetTaskRunner(),
                               /*raster=*/thread->GetTaskRunner(),
                               /*ui=*/thread->GetTaskRunner(),
                               /*io=*/thread->GetTaskRunner());
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  flutterPlatformViewsController->SetTaskRunner(thread->GetTaskRunner());
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/mock_delegate.settings_.enable_impeller
          ? flutter::IOSRenderingAPI::kMetal
          : flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners,
      /*worker_task_runner=*/nil,
      /*is_gpu_disabled_jsync_switch=*/std::make_shared<fml::SyncSwitch>());

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory alloc] init];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  XCTAssertNotNil(gMockPlatformView);

  UIView* flutterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
  flutterPlatformViewsController->SetFlutterView(flutterView);
  // Create embedded view params
  flutter::MutatorsStack stack;
  // Layer tree always pushes a screen scale factor to the stack
  CGFloat screenScale = [UIScreen mainScreen].scale;
  SkMatrix screenScaleMatrix = SkMatrix::Scale(screenScale, screenScale);
  stack.PushTransform(screenScaleMatrix);
  // Push backdrop filters
  auto filter = std::make_shared<flutter::DlBlurImageFilter>(5, 2, flutter::DlTileMode::kClamp);
  for (int i = 0; i < 5; i++) {
    stack.PushBackdropFilter(filter, SkRect::MakeXYWH(0, 0, screenScale * 10, screenScale * 10));
  }

  auto embeddedViewParams =
      std::make_unique<flutter::EmbeddedViewParams>(screenScaleMatrix, SkSize::Make(10, 10), stack);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  flutterPlatformViewsController->CompositeWithParams(
      2, flutterPlatformViewsController->GetCompositionParams(2));

  XCTAssertTrue([gMockPlatformView.superview.superview isKindOfClass:ChildClippingView.class]);
  ChildClippingView* childClippingView = (ChildClippingView*)gMockPlatformView.superview.superview;
  [flutterView addSubview:childClippingView];

  [flutterView setNeedsLayout];
  [flutterView layoutIfNeeded];

  NSMutableArray* originalVisualEffectViews = [[NSMutableArray alloc] init];
  for (UIView* subview in childClippingView.subviews) {
    if (![subview isKindOfClass:[UIVisualEffectView class]]) {
      continue;
    }
    XCTAssertLessThan(originalVisualEffectViews.count, 5u);
    if ([self validateOneVisualEffectView:subview
                            expectedFrame:CGRectMake(0, 0, 10, 10)
                              inputRadius:(CGFloat)5]) {
      [originalVisualEffectViews addObject:subview];
    }
  }

  // Simulate removing 1 backdrop filter (create a new mutators stack)
  // Create embedded view params
  flutter::MutatorsStack stack2;
  // Layer tree always pushes a screen scale factor to the stack
  stack2.PushTransform(screenScaleMatrix);
  // Push backdrop filters
  for (int i = 0; i < 4; i++) {
    stack2.PushBackdropFilter(filter, SkRect::MakeXYWH(0, 0, screenScale * 10, screenScale * 10));
  }

  embeddedViewParams = std::make_unique<flutter::EmbeddedViewParams>(screenScaleMatrix,
                                                                     SkSize::Make(10, 10), stack2);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  flutterPlatformViewsController->CompositeWithParams(
      2, flutterPlatformViewsController->GetCompositionParams(2));

  [flutterView setNeedsLayout];
  [flutterView layoutIfNeeded];

  NSMutableArray* newVisualEffectViews = [[NSMutableArray alloc] init];
  for (UIView* subview in childClippingView.subviews) {
    if (![subview isKindOfClass:[UIVisualEffectView class]]) {
      continue;
    }
    XCTAssertLessThan(newVisualEffectViews.count, 4u);
    if ([self validateOneVisualEffectView:subview
                            expectedFrame:CGRectMake(0, 0, 10, 10)
                              inputRadius:(CGFloat)5]) {
      [newVisualEffectViews addObject:subview];
    }
  }
  XCTAssertEqual(newVisualEffectViews.count, 4u);

  for (NSUInteger i = 0; i < newVisualEffectViews.count; i++) {
    UIView* newView = newVisualEffectViews[i];
    id mockNewView = OCMPartialMock(newView);
    UIView* originalView = originalVisualEffectViews[i];
    // Compare reference.
    XCTAssertEqual(originalView, newView);
    OCMReject([mockNewView removeFromSuperview]);
    [mockNewView stopMocking];
  }

  // Simulate removing all backdrop filters (replace the mutators stack)
  // Update embedded view params, delete except screenScaleMatrix
  for (int i = 0; i < 5; i++) {
    stack2.Pop();
  }
  // No backdrop filters in the stack, so no nothing to push

  embeddedViewParams = std::make_unique<flutter::EmbeddedViewParams>(screenScaleMatrix,
                                                                     SkSize::Make(10, 10), stack2);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  flutterPlatformViewsController->CompositeWithParams(
      2, flutterPlatformViewsController->GetCompositionParams(2));

  [flutterView setNeedsLayout];
  [flutterView layoutIfNeeded];

  NSUInteger numberOfExpectedVisualEffectView = 0u;
  for (UIView* subview in childClippingView.subviews) {
    if ([subview isKindOfClass:[UIVisualEffectView class]]) {
      numberOfExpectedVisualEffectView++;
    }
  }
  XCTAssertEqual(numberOfExpectedVisualEffectView, 0u);
}

- (void)testEditBackdropFilters {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread = std::make_unique<fml::Thread>("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread->GetTaskRunner(),
                               /*raster=*/thread->GetTaskRunner(),
                               /*ui=*/thread->GetTaskRunner(),
                               /*io=*/thread->GetTaskRunner());
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  flutterPlatformViewsController->SetTaskRunner(thread->GetTaskRunner());
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/mock_delegate.settings_.enable_impeller
          ? flutter::IOSRenderingAPI::kMetal
          : flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners,
      /*worker_task_runner=*/nil,
      /*is_gpu_disabled_jsync_switch=*/std::make_shared<fml::SyncSwitch>());

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory alloc] init];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  XCTAssertNotNil(gMockPlatformView);

  UIView* flutterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
  flutterPlatformViewsController->SetFlutterView(flutterView);
  // Create embedded view params
  flutter::MutatorsStack stack;
  // Layer tree always pushes a screen scale factor to the stack
  CGFloat screenScale = [UIScreen mainScreen].scale;
  SkMatrix screenScaleMatrix = SkMatrix::Scale(screenScale, screenScale);
  stack.PushTransform(screenScaleMatrix);
  // Push backdrop filters
  auto filter = std::make_shared<flutter::DlBlurImageFilter>(5, 2, flutter::DlTileMode::kClamp);
  for (int i = 0; i < 5; i++) {
    stack.PushBackdropFilter(filter, SkRect::MakeXYWH(0, 0, screenScale * 10, screenScale * 10));
  }

  auto embeddedViewParams =
      std::make_unique<flutter::EmbeddedViewParams>(screenScaleMatrix, SkSize::Make(10, 10), stack);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  flutterPlatformViewsController->CompositeWithParams(
      2, flutterPlatformViewsController->GetCompositionParams(2));

  XCTAssertTrue([gMockPlatformView.superview.superview isKindOfClass:ChildClippingView.class]);
  ChildClippingView* childClippingView = (ChildClippingView*)gMockPlatformView.superview.superview;
  [flutterView addSubview:childClippingView];

  [flutterView setNeedsLayout];
  [flutterView layoutIfNeeded];

  NSMutableArray* originalVisualEffectViews = [[NSMutableArray alloc] init];
  for (UIView* subview in childClippingView.subviews) {
    if (![subview isKindOfClass:[UIVisualEffectView class]]) {
      continue;
    }
    XCTAssertLessThan(originalVisualEffectViews.count, 5u);
    if ([self validateOneVisualEffectView:subview
                            expectedFrame:CGRectMake(0, 0, 10, 10)
                              inputRadius:(CGFloat)5]) {
      [originalVisualEffectViews addObject:subview];
    }
  }

  // Simulate editing 1 backdrop filter in the middle of the stack (create a new mutators stack)
  // Create embedded view params
  flutter::MutatorsStack stack2;
  // Layer tree always pushes a screen scale factor to the stack
  stack2.PushTransform(screenScaleMatrix);
  // Push backdrop filters
  for (int i = 0; i < 5; i++) {
    if (i == 3) {
      auto filter2 =
          std::make_shared<flutter::DlBlurImageFilter>(2, 5, flutter::DlTileMode::kClamp);

      stack2.PushBackdropFilter(filter2,
                                SkRect::MakeXYWH(0, 0, screenScale * 10, screenScale * 10));
      continue;
    }

    stack2.PushBackdropFilter(filter, SkRect::MakeXYWH(0, 0, screenScale * 10, screenScale * 10));
  }

  embeddedViewParams = std::make_unique<flutter::EmbeddedViewParams>(screenScaleMatrix,
                                                                     SkSize::Make(10, 10), stack2);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  flutterPlatformViewsController->CompositeWithParams(
      2, flutterPlatformViewsController->GetCompositionParams(2));

  [flutterView setNeedsLayout];
  [flutterView layoutIfNeeded];

  NSMutableArray* newVisualEffectViews = [[NSMutableArray alloc] init];
  for (UIView* subview in childClippingView.subviews) {
    if (![subview isKindOfClass:[UIVisualEffectView class]]) {
      continue;
    }
    XCTAssertLessThan(newVisualEffectViews.count, 5u);
    CGFloat expectInputRadius = 5;
    if (newVisualEffectViews.count == 3) {
      expectInputRadius = 2;
    }
    if ([self validateOneVisualEffectView:subview
                            expectedFrame:CGRectMake(0, 0, 10, 10)
                              inputRadius:(CGFloat)expectInputRadius]) {
      [newVisualEffectViews addObject:subview];
    }
  }
  XCTAssertEqual(newVisualEffectViews.count, 5u);
  for (NSUInteger i = 0; i < newVisualEffectViews.count; i++) {
    UIView* newView = newVisualEffectViews[i];
    id mockNewView = OCMPartialMock(newView);
    UIView* originalView = originalVisualEffectViews[i];
    // Compare reference.
    XCTAssertEqual(originalView, newView);
    OCMReject([mockNewView removeFromSuperview]);
    [mockNewView stopMocking];
  }
  [newVisualEffectViews removeAllObjects];

  // Simulate editing 1 backdrop filter in the beginning of the stack (replace the mutators stack)
  // Update embedded view params, delete except screenScaleMatrix
  for (int i = 0; i < 5; i++) {
    stack2.Pop();
  }
  // Push backdrop filters
  for (int i = 0; i < 5; i++) {
    if (i == 0) {
      auto filter2 =
          std::make_shared<flutter::DlBlurImageFilter>(2, 5, flutter::DlTileMode::kClamp);
      stack2.PushBackdropFilter(filter2,
                                SkRect::MakeXYWH(0, 0, screenScale * 10, screenScale * 10));
      continue;
    }

    stack2.PushBackdropFilter(filter, SkRect::MakeXYWH(0, 0, screenScale * 10, screenScale * 10));
  }

  embeddedViewParams = std::make_unique<flutter::EmbeddedViewParams>(screenScaleMatrix,
                                                                     SkSize::Make(10, 10), stack2);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  flutterPlatformViewsController->CompositeWithParams(
      2, flutterPlatformViewsController->GetCompositionParams(2));

  [flutterView setNeedsLayout];
  [flutterView layoutIfNeeded];

  for (UIView* subview in childClippingView.subviews) {
    if (![subview isKindOfClass:[UIVisualEffectView class]]) {
      continue;
    }
    XCTAssertLessThan(newVisualEffectViews.count, 5u);
    CGFloat expectInputRadius = 5;
    if (newVisualEffectViews.count == 0) {
      expectInputRadius = 2;
    }
    if ([self validateOneVisualEffectView:subview
                            expectedFrame:CGRectMake(0, 0, 10, 10)
                              inputRadius:(CGFloat)expectInputRadius]) {
      [newVisualEffectViews addObject:subview];
    }
  }
  for (NSUInteger i = 0; i < newVisualEffectViews.count; i++) {
    UIView* newView = newVisualEffectViews[i];
    id mockNewView = OCMPartialMock(newView);
    UIView* originalView = originalVisualEffectViews[i];
    // Compare reference.
    XCTAssertEqual(originalView, newView);
    OCMReject([mockNewView removeFromSuperview]);
    [mockNewView stopMocking];
  }
  [newVisualEffectViews removeAllObjects];

  // Simulate editing 1 backdrop filter in the end of the stack (replace the mutators stack)
  // Update embedded view params, delete except screenScaleMatrix
  for (int i = 0; i < 5; i++) {
    stack2.Pop();
  }
  // Push backdrop filters
  for (int i = 0; i < 5; i++) {
    if (i == 4) {
      auto filter2 =
          std::make_shared<flutter::DlBlurImageFilter>(2, 5, flutter::DlTileMode::kClamp);
      stack2.PushBackdropFilter(filter2,
                                SkRect::MakeXYWH(0, 0, screenScale * 10, screenScale * 10));
      continue;
    }

    stack2.PushBackdropFilter(filter, SkRect::MakeXYWH(0, 0, screenScale * 10, screenScale * 10));
  }

  embeddedViewParams = std::make_unique<flutter::EmbeddedViewParams>(screenScaleMatrix,
                                                                     SkSize::Make(10, 10), stack2);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  flutterPlatformViewsController->CompositeWithParams(
      2, flutterPlatformViewsController->GetCompositionParams(2));

  [flutterView setNeedsLayout];
  [flutterView layoutIfNeeded];

  for (UIView* subview in childClippingView.subviews) {
    if (![subview isKindOfClass:[UIVisualEffectView class]]) {
      continue;
    }
    XCTAssertLessThan(newVisualEffectViews.count, 5u);
    CGFloat expectInputRadius = 5;
    if (newVisualEffectViews.count == 4) {
      expectInputRadius = 2;
    }
    if ([self validateOneVisualEffectView:subview
                            expectedFrame:CGRectMake(0, 0, 10, 10)
                              inputRadius:(CGFloat)expectInputRadius]) {
      [newVisualEffectViews addObject:subview];
    }
  }
  XCTAssertEqual(newVisualEffectViews.count, 5u);

  for (NSUInteger i = 0; i < newVisualEffectViews.count; i++) {
    UIView* newView = newVisualEffectViews[i];
    id mockNewView = OCMPartialMock(newView);
    UIView* originalView = originalVisualEffectViews[i];
    // Compare reference.
    XCTAssertEqual(originalView, newView);
    OCMReject([mockNewView removeFromSuperview]);
    [mockNewView stopMocking];
  }
  [newVisualEffectViews removeAllObjects];

  // Simulate editing all backdrop filters in the stack (replace the mutators stack)
  // Update embedded view params, delete except screenScaleMatrix
  for (int i = 0; i < 5; i++) {
    stack2.Pop();
  }
  // Push backdrop filters
  for (int i = 0; i < 5; i++) {
    auto filter2 = std::make_shared<flutter::DlBlurImageFilter>(i, 2, flutter::DlTileMode::kClamp);

    stack2.PushBackdropFilter(filter2, SkRect::MakeXYWH(0, 0, screenScale * 10, screenScale * 10));
  }

  embeddedViewParams = std::make_unique<flutter::EmbeddedViewParams>(screenScaleMatrix,
                                                                     SkSize::Make(10, 10), stack2);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  flutterPlatformViewsController->CompositeWithParams(
      2, flutterPlatformViewsController->GetCompositionParams(2));

  [flutterView setNeedsLayout];
  [flutterView layoutIfNeeded];

  for (UIView* subview in childClippingView.subviews) {
    if (![subview isKindOfClass:[UIVisualEffectView class]]) {
      continue;
    }
    XCTAssertLessThan(newVisualEffectViews.count, 5u);
    if ([self validateOneVisualEffectView:subview
                            expectedFrame:CGRectMake(0, 0, 10, 10)
                              inputRadius:(CGFloat)newVisualEffectViews.count]) {
      [newVisualEffectViews addObject:subview];
    }
  }
  XCTAssertEqual(newVisualEffectViews.count, 5u);

  for (NSUInteger i = 0; i < newVisualEffectViews.count; i++) {
    UIView* newView = newVisualEffectViews[i];
    id mockNewView = OCMPartialMock(newView);
    UIView* originalView = originalVisualEffectViews[i];
    // Compare reference.
    XCTAssertEqual(originalView, newView);
    OCMReject([mockNewView removeFromSuperview]);
    [mockNewView stopMocking];
  }
  [newVisualEffectViews removeAllObjects];
}

- (void)testApplyBackdropFilterNotDlBlurImageFilter {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread = std::make_unique<fml::Thread>("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread->GetTaskRunner(),
                               /*raster=*/thread->GetTaskRunner(),
                               /*ui=*/thread->GetTaskRunner(),
                               /*io=*/thread->GetTaskRunner());
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  flutterPlatformViewsController->SetTaskRunner(thread->GetTaskRunner());
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/mock_delegate.settings_.enable_impeller
          ? flutter::IOSRenderingAPI::kMetal
          : flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners,
      /*worker_task_runner=*/nil,
      /*is_gpu_disabled_jsync_switch=*/std::make_shared<fml::SyncSwitch>());

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory alloc] init];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  XCTAssertNotNil(gMockPlatformView);

  UIView* flutterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
  flutterPlatformViewsController->SetFlutterView(flutterView);
  // Create embedded view params
  flutter::MutatorsStack stack;
  // Layer tree always pushes a screen scale factor to the stack
  CGFloat screenScale = [UIScreen mainScreen].scale;
  SkMatrix screenScaleMatrix = SkMatrix::Scale(screenScale, screenScale);
  stack.PushTransform(screenScaleMatrix);
  // Push a dilate backdrop filter
  auto dilateFilter = std::make_shared<flutter::DlDilateImageFilter>(5, 2);
  stack.PushBackdropFilter(dilateFilter, SkRect::MakeEmpty());

  auto embeddedViewParams =
      std::make_unique<flutter::EmbeddedViewParams>(screenScaleMatrix, SkSize::Make(10, 10), stack);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  flutterPlatformViewsController->CompositeWithParams(
      2, flutterPlatformViewsController->GetCompositionParams(2));

  XCTAssertTrue([gMockPlatformView.superview.superview isKindOfClass:[ChildClippingView class]]);
  ChildClippingView* childClippingView = (ChildClippingView*)gMockPlatformView.superview.superview;

  [flutterView addSubview:childClippingView];

  [flutterView setNeedsLayout];
  [flutterView layoutIfNeeded];

  NSUInteger numberOfExpectedVisualEffectView = 0;
  for (UIView* subview in childClippingView.subviews) {
    if ([subview isKindOfClass:[UIVisualEffectView class]]) {
      numberOfExpectedVisualEffectView++;
    }
  }
  XCTAssertEqual(numberOfExpectedVisualEffectView, 0u);

  // Simulate adding a non-DlBlurImageFilter in the middle of the stack (create a new mutators
  // stack) Create embedded view params
  flutter::MutatorsStack stack2;
  // Layer tree always pushes a screen scale factor to the stack
  stack2.PushTransform(screenScaleMatrix);
  // Push backdrop filters and dilate filter
  auto blurFilter = std::make_shared<flutter::DlBlurImageFilter>(5, 2, flutter::DlTileMode::kClamp);

  for (int i = 0; i < 5; i++) {
    if (i == 2) {
      stack2.PushBackdropFilter(dilateFilter,
                                SkRect::MakeXYWH(0, 0, screenScale * 10, screenScale * 10));
      continue;
    }

    stack2.PushBackdropFilter(blurFilter,
                              SkRect::MakeXYWH(0, 0, screenScale * 10, screenScale * 10));
  }

  embeddedViewParams = std::make_unique<flutter::EmbeddedViewParams>(screenScaleMatrix,
                                                                     SkSize::Make(10, 10), stack2);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  flutterPlatformViewsController->CompositeWithParams(
      2, flutterPlatformViewsController->GetCompositionParams(2));

  [flutterView setNeedsLayout];
  [flutterView layoutIfNeeded];

  numberOfExpectedVisualEffectView = 0;
  for (UIView* subview in childClippingView.subviews) {
    if (![subview isKindOfClass:[UIVisualEffectView class]]) {
      continue;
    }
    XCTAssertLessThan(numberOfExpectedVisualEffectView, 4u);
    if ([self validateOneVisualEffectView:subview
                            expectedFrame:CGRectMake(0, 0, 10, 10)
                              inputRadius:(CGFloat)5]) {
      numberOfExpectedVisualEffectView++;
    }
  }
  XCTAssertEqual(numberOfExpectedVisualEffectView, 4u);

  // Simulate adding a non-DlBlurImageFilter to the beginning of the stack (replace the mutators
  // stack) Update embedded view params, delete except screenScaleMatrix
  for (int i = 0; i < 5; i++) {
    stack2.Pop();
  }
  // Push backdrop filters and dilate filter
  for (int i = 0; i < 5; i++) {
    if (i == 0) {
      stack2.PushBackdropFilter(dilateFilter,
                                SkRect::MakeXYWH(0, 0, screenScale * 10, screenScale * 10));
      continue;
    }

    stack2.PushBackdropFilter(blurFilter,
                              SkRect::MakeXYWH(0, 0, screenScale * 10, screenScale * 10));
  }

  embeddedViewParams = std::make_unique<flutter::EmbeddedViewParams>(screenScaleMatrix,
                                                                     SkSize::Make(10, 10), stack2);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  flutterPlatformViewsController->CompositeWithParams(
      2, flutterPlatformViewsController->GetCompositionParams(2));

  [flutterView setNeedsLayout];
  [flutterView layoutIfNeeded];

  numberOfExpectedVisualEffectView = 0;
  for (UIView* subview in childClippingView.subviews) {
    if (![subview isKindOfClass:[UIVisualEffectView class]]) {
      continue;
    }
    XCTAssertLessThan(numberOfExpectedVisualEffectView, 4u);
    if ([self validateOneVisualEffectView:subview
                            expectedFrame:CGRectMake(0, 0, 10, 10)
                              inputRadius:(CGFloat)5]) {
      numberOfExpectedVisualEffectView++;
    }
  }
  XCTAssertEqual(numberOfExpectedVisualEffectView, 4u);

  // Simulate adding a non-DlBlurImageFilter to the end of the stack (replace the mutators stack)
  // Update embedded view params, delete except screenScaleMatrix
  for (int i = 0; i < 5; i++) {
    stack2.Pop();
  }
  // Push backdrop filters and dilate filter
  for (int i = 0; i < 5; i++) {
    if (i == 4) {
      stack2.PushBackdropFilter(dilateFilter,
                                SkRect::MakeXYWH(0, 0, screenScale * 10, screenScale * 10));
      continue;
    }

    stack2.PushBackdropFilter(blurFilter,
                              SkRect::MakeXYWH(0, 0, screenScale * 10, screenScale * 10));
  }

  embeddedViewParams = std::make_unique<flutter::EmbeddedViewParams>(screenScaleMatrix,
                                                                     SkSize::Make(10, 10), stack2);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  flutterPlatformViewsController->CompositeWithParams(
      2, flutterPlatformViewsController->GetCompositionParams(2));

  [flutterView setNeedsLayout];
  [flutterView layoutIfNeeded];

  numberOfExpectedVisualEffectView = 0;
  for (UIView* subview in childClippingView.subviews) {
    if (![subview isKindOfClass:[UIVisualEffectView class]]) {
      continue;
    }
    XCTAssertLessThan(numberOfExpectedVisualEffectView, 4u);
    if ([self validateOneVisualEffectView:subview
                            expectedFrame:CGRectMake(0, 0, 10, 10)
                              inputRadius:(CGFloat)5]) {
      numberOfExpectedVisualEffectView++;
    }
  }
  XCTAssertEqual(numberOfExpectedVisualEffectView, 4u);

  // Simulate adding only non-DlBlurImageFilter to the stack (replace the mutators stack)
  // Update embedded view params, delete except screenScaleMatrix
  for (int i = 0; i < 5; i++) {
    stack2.Pop();
  }
  // Push dilate filters
  for (int i = 0; i < 5; i++) {
    stack2.PushBackdropFilter(dilateFilter,
                              SkRect::MakeXYWH(0, 0, screenScale * 10, screenScale * 10));
  }

  embeddedViewParams = std::make_unique<flutter::EmbeddedViewParams>(screenScaleMatrix,
                                                                     SkSize::Make(10, 10), stack2);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  flutterPlatformViewsController->CompositeWithParams(
      2, flutterPlatformViewsController->GetCompositionParams(2));

  [flutterView setNeedsLayout];
  [flutterView layoutIfNeeded];

  numberOfExpectedVisualEffectView = 0;
  for (UIView* subview in childClippingView.subviews) {
    if ([subview isKindOfClass:[UIVisualEffectView class]]) {
      numberOfExpectedVisualEffectView++;
    }
  }
  XCTAssertEqual(numberOfExpectedVisualEffectView, 0u);
}

- (void)testApplyBackdropFilterCorrectAPI {
  [PlatformViewFilter resetPreparation];
  // The gaussianBlur filter is extracted from UIVisualEffectView.
  // Each test requires a new PlatformViewFilter
  // Valid UIVisualEffectView API
  UIVisualEffectView* visualEffectView = [[UIVisualEffectView alloc]
      initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
  PlatformViewFilter* platformViewFilter =
      [[PlatformViewFilter alloc] initWithFrame:CGRectMake(0, 0, 10, 10)
                                     blurRadius:5
                               visualEffectView:visualEffectView];
  XCTAssertNotNil(platformViewFilter);
}

- (void)testApplyBackdropFilterAPIChangedInvalidUIVisualEffectView {
  [PlatformViewFilter resetPreparation];
  UIVisualEffectView* visualEffectView = [[UIVisualEffectView alloc] init];
  PlatformViewFilter* platformViewFilter =
      [[PlatformViewFilter alloc] initWithFrame:CGRectMake(0, 0, 10, 10)
                                     blurRadius:5
                               visualEffectView:visualEffectView];
  XCTAssertNil(platformViewFilter);
}

- (void)testApplyBackdropFilterAPIChangedNoGaussianBlurFilter {
  [PlatformViewFilter resetPreparation];
  UIVisualEffectView* editedUIVisualEffectView = [[UIVisualEffectView alloc]
      initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
  NSArray* subviews = editedUIVisualEffectView.subviews;
  for (UIView* view in subviews) {
    if ([NSStringFromClass([view class]) hasSuffix:@"BackdropView"]) {
      for (CIFilter* filter in view.layer.filters) {
        if ([[filter valueForKey:@"name"] isEqual:@"gaussianBlur"]) {
          [filter setValue:@"notGaussianBlur" forKey:@"name"];
          break;
        }
      }
      break;
    }
  }
  PlatformViewFilter* platformViewFilter =
      [[PlatformViewFilter alloc] initWithFrame:CGRectMake(0, 0, 10, 10)
                                     blurRadius:5
                               visualEffectView:editedUIVisualEffectView];
  XCTAssertNil(platformViewFilter);
}

- (void)testApplyBackdropFilterAPIChangedInvalidInputRadius {
  [PlatformViewFilter resetPreparation];
  UIVisualEffectView* editedUIVisualEffectView = [[UIVisualEffectView alloc]
      initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
  NSArray* subviews = editedUIVisualEffectView.subviews;
  for (UIView* view in subviews) {
    if ([NSStringFromClass([view class]) hasSuffix:@"BackdropView"]) {
      for (CIFilter* filter in view.layer.filters) {
        if ([[filter valueForKey:@"name"] isEqual:@"gaussianBlur"]) {
          [filter setValue:@"invalidInputRadius" forKey:@"inputRadius"];
          break;
        }
      }
      break;
    }
  }

  PlatformViewFilter* platformViewFilter =
      [[PlatformViewFilter alloc] initWithFrame:CGRectMake(0, 0, 10, 10)
                                     blurRadius:5
                               visualEffectView:editedUIVisualEffectView];
  XCTAssertNil(platformViewFilter);
}

- (void)testBackdropFilterVisualEffectSubviewBackgroundColor {
  __weak UIVisualEffectView* weakVisualEffectView;

  @autoreleasepool {
    UIVisualEffectView* visualEffectView = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
    weakVisualEffectView = visualEffectView;
    PlatformViewFilter* platformViewFilter =
        [[PlatformViewFilter alloc] initWithFrame:CGRectMake(0, 0, 10, 10)
                                       blurRadius:5
                                 visualEffectView:visualEffectView];
    CGColorRef visualEffectSubviewBackgroundColor = nil;
    for (UIView* view in [platformViewFilter backdropFilterView].subviews) {
      if ([NSStringFromClass([view class]) hasSuffix:@"VisualEffectSubview"]) {
        visualEffectSubviewBackgroundColor = view.layer.backgroundColor;
      }
    }
    XCTAssertTrue(
        CGColorEqualToColor(visualEffectSubviewBackgroundColor, UIColor.clearColor.CGColor));
  }
  XCTAssertNil(weakVisualEffectView);
}

- (void)testCompositePlatformView {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread = std::make_unique<fml::Thread>("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread->GetTaskRunner(),
                               /*raster=*/thread->GetTaskRunner(),
                               /*ui=*/thread->GetTaskRunner(),
                               /*io=*/thread->GetTaskRunner());
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  flutterPlatformViewsController->SetTaskRunner(thread->GetTaskRunner());
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/mock_delegate.settings_.enable_impeller
          ? flutter::IOSRenderingAPI::kMetal
          : flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners,
      /*worker_task_runner=*/nil,
      /*is_gpu_disabled_jsync_switch=*/std::make_shared<fml::SyncSwitch>());

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory alloc] init];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  XCTAssertNotNil(gMockPlatformView);

  UIView* flutterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 500, 500)];
  flutterPlatformViewsController->SetFlutterView(flutterView);
  // Create embedded view params
  flutter::MutatorsStack stack;
  // Layer tree always pushes a screen scale factor to the stack
  SkMatrix screenScaleMatrix =
      SkMatrix::Scale([UIScreen mainScreen].scale, [UIScreen mainScreen].scale);
  stack.PushTransform(screenScaleMatrix);
  // Push a translate matrix
  SkMatrix translateMatrix = SkMatrix::Translate(100, 100);
  stack.PushTransform(translateMatrix);
  SkMatrix finalMatrix;
  finalMatrix.setConcat(screenScaleMatrix, translateMatrix);

  auto embeddedViewParams =
      std::make_unique<flutter::EmbeddedViewParams>(finalMatrix, SkSize::Make(300, 300), stack);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  flutterPlatformViewsController->CompositeWithParams(
      2, flutterPlatformViewsController->GetCompositionParams(2));

  CGRect platformViewRectInFlutterView = [gMockPlatformView convertRect:gMockPlatformView.bounds
                                                                 toView:flutterView];
  XCTAssertTrue(CGRectEqualToRect(platformViewRectInFlutterView, CGRectMake(100, 100, 300, 300)));
}

- (void)testBackdropFilterCorrectlyPushedAndReset {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread = std::make_unique<fml::Thread>("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread->GetTaskRunner(),
                               /*raster=*/thread->GetTaskRunner(),
                               /*ui=*/thread->GetTaskRunner(),
                               /*io=*/thread->GetTaskRunner());
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  flutterPlatformViewsController->SetTaskRunner(thread->GetTaskRunner());
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/mock_delegate.settings_.enable_impeller
          ? flutter::IOSRenderingAPI::kMetal
          : flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners,
      /*worker_task_runner=*/nil,
      /*is_gpu_disabled_jsync_switch=*/std::make_shared<fml::SyncSwitch>());

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory alloc] init];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  XCTAssertNotNil(gMockPlatformView);

  UIView* flutterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
  flutterPlatformViewsController->SetFlutterView(flutterView);
  // Create embedded view params
  flutter::MutatorsStack stack;
  // Layer tree always pushes a screen scale factor to the stack
  CGFloat screenScale = [UIScreen mainScreen].scale;
  SkMatrix screenScaleMatrix = SkMatrix::Scale(screenScale, screenScale);
  stack.PushTransform(screenScaleMatrix);

  auto embeddedViewParams =
      std::make_unique<flutter::EmbeddedViewParams>(screenScaleMatrix, SkSize::Make(10, 10), stack);

  flutterPlatformViewsController->BeginFrame(SkISize::Make(0, 0));
  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
  flutterPlatformViewsController->PushVisitedPlatformView(2);
  auto filter = std::make_shared<flutter::DlBlurImageFilter>(5, 2, flutter::DlTileMode::kClamp);
  flutterPlatformViewsController->PushFilterToVisitedPlatformViews(
      filter, SkRect::MakeXYWH(0, 0, screenScale * 10, screenScale * 10));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  flutterPlatformViewsController->CompositeWithParams(
      2, flutterPlatformViewsController->GetCompositionParams(2));

  XCTAssertTrue([gMockPlatformView.superview.superview isKindOfClass:[ChildClippingView class]]);
  ChildClippingView* childClippingView = (ChildClippingView*)gMockPlatformView.superview.superview;
  [flutterView addSubview:childClippingView];

  [flutterView setNeedsLayout];
  [flutterView layoutIfNeeded];

  // childClippingView has visual effect view with the correct configurations.
  NSUInteger numberOfExpectedVisualEffectView = 0;
  for (UIView* subview in childClippingView.subviews) {
    if (![subview isKindOfClass:[UIVisualEffectView class]]) {
      continue;
    }
    XCTAssertLessThan(numberOfExpectedVisualEffectView, 1u);
    if ([self validateOneVisualEffectView:subview
                            expectedFrame:CGRectMake(0, 0, 10, 10)
                              inputRadius:5]) {
      numberOfExpectedVisualEffectView++;
    }
  }
  XCTAssertEqual(numberOfExpectedVisualEffectView, 1u);

  // New frame, with no filter pushed.
  auto embeddedViewParams2 =
      std::make_unique<flutter::EmbeddedViewParams>(screenScaleMatrix, SkSize::Make(10, 10), stack);
  flutterPlatformViewsController->BeginFrame(SkISize::Make(0, 0));
  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams2));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  flutterPlatformViewsController->CompositeWithParams(
      2, flutterPlatformViewsController->GetCompositionParams(2));

  XCTAssertTrue([gMockPlatformView.superview.superview isKindOfClass:[ChildClippingView class]]);

  [flutterView setNeedsLayout];
  [flutterView layoutIfNeeded];

  numberOfExpectedVisualEffectView = 0;
  for (UIView* subview in childClippingView.subviews) {
    if (![subview isKindOfClass:[UIVisualEffectView class]]) {
      continue;
    }
    numberOfExpectedVisualEffectView++;
  }
  XCTAssertEqual(numberOfExpectedVisualEffectView, 0u);
}

- (void)testChildClippingViewShouldBeTheBoundingRectOfPlatformView {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread = std::make_unique<fml::Thread>("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread->GetTaskRunner(),
                               /*raster=*/thread->GetTaskRunner(),
                               /*ui=*/thread->GetTaskRunner(),
                               /*io=*/thread->GetTaskRunner());
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  flutterPlatformViewsController->SetTaskRunner(thread->GetTaskRunner());
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/mock_delegate.settings_.enable_impeller
          ? flutter::IOSRenderingAPI::kMetal
          : flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners,
      /*worker_task_runner=*/nil,
      /*is_gpu_disabled_jsync_switch=*/std::make_shared<fml::SyncSwitch>());

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory alloc] init];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  XCTAssertNotNil(gMockPlatformView);

  UIView* flutterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 500, 500)];
  flutterPlatformViewsController->SetFlutterView(flutterView);
  // Create embedded view params
  flutter::MutatorsStack stack;
  // Layer tree always pushes a screen scale factor to the stack
  SkMatrix screenScaleMatrix =
      SkMatrix::Scale([UIScreen mainScreen].scale, [UIScreen mainScreen].scale);
  stack.PushTransform(screenScaleMatrix);
  // Push a rotate matrix
  SkMatrix rotateMatrix;
  rotateMatrix.setRotate(10);
  stack.PushTransform(rotateMatrix);
  SkMatrix finalMatrix;
  finalMatrix.setConcat(screenScaleMatrix, rotateMatrix);

  auto embeddedViewParams =
      std::make_unique<flutter::EmbeddedViewParams>(finalMatrix, SkSize::Make(300, 300), stack);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  flutterPlatformViewsController->CompositeWithParams(
      2, flutterPlatformViewsController->GetCompositionParams(2));

  CGRect platformViewRectInFlutterView = [gMockPlatformView convertRect:gMockPlatformView.bounds
                                                                 toView:flutterView];
  XCTAssertTrue([gMockPlatformView.superview.superview isKindOfClass:ChildClippingView.class]);
  ChildClippingView* childClippingView = (ChildClippingView*)gMockPlatformView.superview.superview;
  // The childclippingview's frame is set based on flow, but the platform view's frame is set based
  // on quartz. Although they should be the same, but we should tolerate small floating point
  // errors.
  XCTAssertLessThan(fabs(platformViewRectInFlutterView.origin.x - childClippingView.frame.origin.x),
                    kFloatCompareEpsilon);
  XCTAssertLessThan(fabs(platformViewRectInFlutterView.origin.y - childClippingView.frame.origin.y),
                    kFloatCompareEpsilon);
  XCTAssertLessThan(
      fabs(platformViewRectInFlutterView.size.width - childClippingView.frame.size.width),
      kFloatCompareEpsilon);
  XCTAssertLessThan(
      fabs(platformViewRectInFlutterView.size.height - childClippingView.frame.size.height),
      kFloatCompareEpsilon);
}

- (void)testClipsDoNotInterceptWithPlatformViewShouldNotAddMaskView {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread = std::make_unique<fml::Thread>("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread->GetTaskRunner(),
                               /*raster=*/thread->GetTaskRunner(),
                               /*ui=*/thread->GetTaskRunner(),
                               /*io=*/thread->GetTaskRunner());
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  flutterPlatformViewsController->SetTaskRunner(thread->GetTaskRunner());
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/mock_delegate.settings_.enable_impeller
          ? flutter::IOSRenderingAPI::kMetal
          : flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners,
      /*worker_task_runner=*/nil,
      /*is_gpu_disabled_jsync_switch=*/std::make_shared<fml::SyncSwitch>());

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory alloc] init];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  XCTAssertNotNil(gMockPlatformView);

  UIView* flutterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 30, 30)];
  flutterPlatformViewsController->SetFlutterView(flutterView);
  // Create embedded view params.
  flutter::MutatorsStack stack;
  // Layer tree always pushes a screen scale factor to the stack.
  SkMatrix screenScaleMatrix =
      SkMatrix::Scale([UIScreen mainScreen].scale, [UIScreen mainScreen].scale);
  stack.PushTransform(screenScaleMatrix);
  SkMatrix translateMatrix = SkMatrix::Translate(5, 5);
  // The platform view's rect for this test will be (5, 5, 10, 10).
  stack.PushTransform(translateMatrix);
  // Push a clip rect, big enough to contain the entire platform view bound.
  SkRect rect = SkRect::MakeXYWH(0, 0, 25, 25);
  stack.PushClipRect(rect);
  // Push a clip rrect, big enough to contain the entire platform view bound without clipping it.
  // Make the origin (-1, -1) so that the top left rounded corner isn't clipping the PlatformView.
  SkRect rect_for_rrect = SkRect::MakeXYWH(-1, -1, 25, 25);
  SkRRect rrect = SkRRect::MakeRectXY(rect_for_rrect, 1, 1);
  stack.PushClipRRect(rrect);

  auto embeddedViewParams = std::make_unique<flutter::EmbeddedViewParams>(
      SkMatrix::Concat(screenScaleMatrix, translateMatrix), SkSize::Make(5, 5), stack);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  flutterPlatformViewsController->CompositeWithParams(
      2, flutterPlatformViewsController->GetCompositionParams(2));

  gMockPlatformView.backgroundColor = UIColor.redColor;
  XCTAssertTrue([gMockPlatformView.superview.superview isKindOfClass:ChildClippingView.class]);
  ChildClippingView* childClippingView = (ChildClippingView*)gMockPlatformView.superview.superview;
  [flutterView addSubview:childClippingView];

  [flutterView setNeedsLayout];
  [flutterView layoutIfNeeded];
  XCTAssertNil(childClippingView.maskView);
}

- (void)testClipRRectOnlyHasCornersInterceptWithPlatformViewShouldAddMaskView {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread = std::make_unique<fml::Thread>("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread->GetTaskRunner(),
                               /*raster=*/thread->GetTaskRunner(),
                               /*ui=*/thread->GetTaskRunner(),
                               /*io=*/thread->GetTaskRunner());
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  flutterPlatformViewsController->SetTaskRunner(thread->GetTaskRunner());
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/mock_delegate.settings_.enable_impeller
          ? flutter::IOSRenderingAPI::kMetal
          : flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners,
      /*worker_task_runner=*/nil,
      /*is_gpu_disabled_jsync_switch=*/std::make_shared<fml::SyncSwitch>());

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory alloc] init];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  XCTAssertNotNil(gMockPlatformView);

  UIView* flutterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 30, 30)];
  flutterPlatformViewsController->SetFlutterView(flutterView);
  // Create embedded view params
  flutter::MutatorsStack stack;
  // Layer tree always pushes a screen scale factor to the stack.
  SkMatrix screenScaleMatrix =
      SkMatrix::Scale([UIScreen mainScreen].scale, [UIScreen mainScreen].scale);
  stack.PushTransform(screenScaleMatrix);
  SkMatrix translateMatrix = SkMatrix::Translate(5, 5);
  // The platform view's rect for this test will be (5, 5, 10, 10).
  stack.PushTransform(translateMatrix);

  // Push a clip rrect, the rect of the rrect is the same as the PlatformView of the corner should.
  // clip the PlatformView.
  SkRect rect_for_rrect = SkRect::MakeXYWH(0, 0, 10, 10);
  SkRRect rrect = SkRRect::MakeRectXY(rect_for_rrect, 1, 1);
  stack.PushClipRRect(rrect);

  auto embeddedViewParams = std::make_unique<flutter::EmbeddedViewParams>(
      SkMatrix::Concat(screenScaleMatrix, translateMatrix), SkSize::Make(5, 5), stack);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  flutterPlatformViewsController->CompositeWithParams(
      2, flutterPlatformViewsController->GetCompositionParams(2));

  gMockPlatformView.backgroundColor = UIColor.redColor;
  XCTAssertTrue([gMockPlatformView.superview.superview isKindOfClass:ChildClippingView.class]);
  ChildClippingView* childClippingView = (ChildClippingView*)gMockPlatformView.superview.superview;
  [flutterView addSubview:childClippingView];

  [flutterView setNeedsLayout];
  [flutterView layoutIfNeeded];

  XCTAssertNotNil(childClippingView.maskView);
}

- (void)testClipRect {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread = std::make_unique<fml::Thread>("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread->GetTaskRunner(),
                               /*raster=*/thread->GetTaskRunner(),
                               /*ui=*/thread->GetTaskRunner(),
                               /*io=*/thread->GetTaskRunner());
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  flutterPlatformViewsController->SetTaskRunner(thread->GetTaskRunner());
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/mock_delegate.settings_.enable_impeller
          ? flutter::IOSRenderingAPI::kMetal
          : flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners,
      /*worker_task_runner=*/nil,
      /*is_gpu_disabled_jsync_switch=*/std::make_shared<fml::SyncSwitch>());

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory alloc] init];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  XCTAssertNotNil(gMockPlatformView);

  UIView* flutterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
  flutterPlatformViewsController->SetFlutterView(flutterView);
  // Create embedded view params
  flutter::MutatorsStack stack;
  // Layer tree always pushes a screen scale factor to the stack
  SkMatrix screenScaleMatrix =
      SkMatrix::Scale([UIScreen mainScreen].scale, [UIScreen mainScreen].scale);
  stack.PushTransform(screenScaleMatrix);
  // Push a clip rect
  SkRect rect = SkRect::MakeXYWH(2, 2, 3, 3);
  stack.PushClipRect(rect);

  auto embeddedViewParams =
      std::make_unique<flutter::EmbeddedViewParams>(screenScaleMatrix, SkSize::Make(10, 10), stack);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  flutterPlatformViewsController->CompositeWithParams(
      2, flutterPlatformViewsController->GetCompositionParams(2));

  gMockPlatformView.backgroundColor = UIColor.redColor;
  XCTAssertTrue([gMockPlatformView.superview.superview isKindOfClass:ChildClippingView.class]);
  ChildClippingView* childClippingView = (ChildClippingView*)gMockPlatformView.superview.superview;
  [flutterView addSubview:childClippingView];

  [flutterView setNeedsLayout];
  [flutterView layoutIfNeeded];

  CGRect insideClipping = CGRectMake(2, 2, 3, 3);
  for (int i = 0; i < 10; i++) {
    for (int j = 0; j < 10; j++) {
      CGPoint point = CGPointMake(i, j);
      int alpha = [self alphaOfPoint:CGPointMake(i, j) onView:flutterView];
      if (CGRectContainsPoint(insideClipping, point)) {
        XCTAssertEqual(alpha, 255);
      } else {
        XCTAssertEqual(alpha, 0);
      }
    }
  }
}

- (void)testClipRRect {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread = std::make_unique<fml::Thread>("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread->GetTaskRunner(),
                               /*raster=*/thread->GetTaskRunner(),
                               /*ui=*/thread->GetTaskRunner(),
                               /*io=*/thread->GetTaskRunner());
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  flutterPlatformViewsController->SetTaskRunner(thread->GetTaskRunner());
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/mock_delegate.settings_.enable_impeller
          ? flutter::IOSRenderingAPI::kMetal
          : flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners,
      /*worker_task_runner=*/nil,
      /*is_gpu_disabled_jsync_switch=*/std::make_shared<fml::SyncSwitch>());

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory alloc] init];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  XCTAssertNotNil(gMockPlatformView);

  UIView* flutterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
  flutterPlatformViewsController->SetFlutterView(flutterView);
  // Create embedded view params
  flutter::MutatorsStack stack;
  // Layer tree always pushes a screen scale factor to the stack
  SkMatrix screenScaleMatrix =
      SkMatrix::Scale([UIScreen mainScreen].scale, [UIScreen mainScreen].scale);
  stack.PushTransform(screenScaleMatrix);
  // Push a clip rrect
  SkRRect rrect = SkRRect::MakeRectXY(SkRect::MakeXYWH(2, 2, 6, 6), 1, 1);
  stack.PushClipRRect(rrect);

  auto embeddedViewParams =
      std::make_unique<flutter::EmbeddedViewParams>(screenScaleMatrix, SkSize::Make(10, 10), stack);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  flutterPlatformViewsController->CompositeWithParams(
      2, flutterPlatformViewsController->GetCompositionParams(2));

  gMockPlatformView.backgroundColor = UIColor.redColor;
  XCTAssertTrue([gMockPlatformView.superview.superview isKindOfClass:ChildClippingView.class]);
  ChildClippingView* childClippingView = (ChildClippingView*)gMockPlatformView.superview.superview;
  [flutterView addSubview:childClippingView];

  [flutterView setNeedsLayout];
  [flutterView layoutIfNeeded];

  /*
  ClippingMask          outterClipping
    2 3 4 5 6 7           2 3 4 5 6 7
  2 / - - - - \         2 + - - - - +
  3 |         |         3 |         |
  4 |         |         4 |         |
  5 |         |         5 |         |
  6 |         |         6 |         |
  7 \ - - - - /         7 + - - - - +

  innerClipping1        innerClipping2
    2 3 4 5 6 7           2 3 4 5 6 7
  2   + - - +           2
  3   |     |           3 + - - - - +
  4   |     |           4 |         |
  5   |     |           5 |         |
  6   |     |           6 + - - - - +
  7   + - - +           7
  */
  CGRect innerClipping1 = CGRectMake(3, 2, 4, 6);
  CGRect innerClipping2 = CGRectMake(2, 3, 6, 4);
  CGRect outterClipping = CGRectMake(2, 2, 6, 6);
  for (int i = 0; i < 10; i++) {
    for (int j = 0; j < 10; j++) {
      CGPoint point = CGPointMake(i, j);
      int alpha = [self alphaOfPoint:CGPointMake(i, j) onView:flutterView];
      if (CGRectContainsPoint(innerClipping1, point) ||
          CGRectContainsPoint(innerClipping2, point)) {
        // Pixels inside either of the 2 inner clippings should be fully opaque.
        XCTAssertEqual(alpha, 255);
      } else if (CGRectContainsPoint(outterClipping, point)) {
        // Corner pixels (i.e. (2, 2), (2, 7), (7, 2) and (7, 7)) should be partially transparent.
        XCTAssert(0 < alpha && alpha < 255);
      } else {
        // Pixels outside outterClipping should be fully transparent.
        XCTAssertEqual(alpha, 0);
      }
    }
  }
}

- (void)testClipPath {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread = std::make_unique<fml::Thread>("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread->GetTaskRunner(),
                               /*raster=*/thread->GetTaskRunner(),
                               /*ui=*/thread->GetTaskRunner(),
                               /*io=*/thread->GetTaskRunner());
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  flutterPlatformViewsController->SetTaskRunner(thread->GetTaskRunner());
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/mock_delegate.settings_.enable_impeller
          ? flutter::IOSRenderingAPI::kMetal
          : flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners,
      /*worker_task_runner=*/nil,
      /*is_gpu_disabled_jsync_switch=*/std::make_shared<fml::SyncSwitch>());

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory alloc] init];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  XCTAssertNotNil(gMockPlatformView);

  UIView* flutterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
  flutterPlatformViewsController->SetFlutterView(flutterView);
  // Create embedded view params
  flutter::MutatorsStack stack;
  // Layer tree always pushes a screen scale factor to the stack
  SkMatrix screenScaleMatrix =
      SkMatrix::Scale([UIScreen mainScreen].scale, [UIScreen mainScreen].scale);
  stack.PushTransform(screenScaleMatrix);
  // Push a clip path
  SkPath path;
  path.addRoundRect(SkRect::MakeXYWH(2, 2, 6, 6), 1, 1);
  stack.PushClipPath(path);

  auto embeddedViewParams =
      std::make_unique<flutter::EmbeddedViewParams>(screenScaleMatrix, SkSize::Make(10, 10), stack);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  flutterPlatformViewsController->CompositeWithParams(
      2, flutterPlatformViewsController->GetCompositionParams(2));

  gMockPlatformView.backgroundColor = UIColor.redColor;
  XCTAssertTrue([gMockPlatformView.superview.superview isKindOfClass:ChildClippingView.class]);
  ChildClippingView* childClippingView = (ChildClippingView*)gMockPlatformView.superview.superview;
  [flutterView addSubview:childClippingView];

  [flutterView setNeedsLayout];
  [flutterView layoutIfNeeded];

  /*
  ClippingMask          outterClipping
    2 3 4 5 6 7           2 3 4 5 6 7
  2 / - - - - \         2 + - - - - +
  3 |         |         3 |         |
  4 |         |         4 |         |
  5 |         |         5 |         |
  6 |         |         6 |         |
  7 \ - - - - /         7 + - - - - +

  innerClipping1        innerClipping2
    2 3 4 5 6 7           2 3 4 5 6 7
  2   + - - +           2
  3   |     |           3 + - - - - +
  4   |     |           4 |         |
  5   |     |           5 |         |
  6   |     |           6 + - - - - +
  7   + - - +           7
  */
  CGRect innerClipping1 = CGRectMake(3, 2, 4, 6);
  CGRect innerClipping2 = CGRectMake(2, 3, 6, 4);
  CGRect outterClipping = CGRectMake(2, 2, 6, 6);
  for (int i = 0; i < 10; i++) {
    for (int j = 0; j < 10; j++) {
      CGPoint point = CGPointMake(i, j);
      int alpha = [self alphaOfPoint:CGPointMake(i, j) onView:flutterView];
      if (CGRectContainsPoint(innerClipping1, point) ||
          CGRectContainsPoint(innerClipping2, point)) {
        // Pixels inside either of the 2 inner clippings should be fully opaque.
        XCTAssertEqual(alpha, 255);
      } else if (CGRectContainsPoint(outterClipping, point)) {
        // Corner pixels (i.e. (2, 2), (2, 7), (7, 2) and (7, 7)) should be partially transparent.
        XCTAssert(0 < alpha && alpha < 255);
      } else {
        // Pixels outside outterClipping should be fully transparent.
        XCTAssertEqual(alpha, 0);
      }
    }
  }
}

- (void)testSetFlutterViewControllerAfterCreateCanStillDispatchTouchEvents {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread = std::make_unique<fml::Thread>("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread->GetTaskRunner(),
                               /*raster=*/thread->GetTaskRunner(),
                               /*ui=*/thread->GetTaskRunner(),
                               /*io=*/thread->GetTaskRunner());
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  flutterPlatformViewsController->SetTaskRunner(thread->GetTaskRunner());
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/mock_delegate.settings_.enable_impeller
          ? flutter::IOSRenderingAPI::kMetal
          : flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners,
      /*worker_task_runner=*/nil,
      /*is_gpu_disabled_jsync_switch=*/std::make_shared<fml::SyncSwitch>());

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory alloc] init];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  XCTAssertNotNil(gMockPlatformView);

  // Find touch inteceptor view
  UIView* touchInteceptorView = gMockPlatformView;
  while (touchInteceptorView != nil &&
         ![touchInteceptorView isKindOfClass:[FlutterTouchInterceptingView class]]) {
    touchInteceptorView = touchInteceptorView.superview;
  }
  XCTAssertNotNil(touchInteceptorView);

  // Find ForwardGestureRecognizer
  UIGestureRecognizer* forwardGectureRecognizer = nil;
  for (UIGestureRecognizer* gestureRecognizer in touchInteceptorView.gestureRecognizers) {
    if ([gestureRecognizer isKindOfClass:NSClassFromString(@"ForwardingGestureRecognizer")]) {
      forwardGectureRecognizer = gestureRecognizer;
      break;
    }
  }

  // Before setting flutter view controller, events are not dispatched.
  NSSet* touches1 = [[NSSet alloc] init];
  id event1 = OCMClassMock([UIEvent class]);
  id flutterViewContoller = OCMClassMock([FlutterViewController class]);
  [forwardGectureRecognizer touchesBegan:touches1 withEvent:event1];
  OCMReject([flutterViewContoller touchesBegan:touches1 withEvent:event1]);

  // Set flutter view controller allows events to be dispatched.
  NSSet* touches2 = [[NSSet alloc] init];
  id event2 = OCMClassMock([UIEvent class]);
  flutterPlatformViewsController->SetFlutterViewController(flutterViewContoller);
  [forwardGectureRecognizer touchesBegan:touches2 withEvent:event2];
  OCMVerify([flutterViewContoller touchesBegan:touches2 withEvent:event2]);
}

- (void)testSetFlutterViewControllerInTheMiddleOfTouchEventShouldStillAllowGesturesToBeHandled {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread = std::make_unique<fml::Thread>("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread->GetTaskRunner(),
                               /*raster=*/thread->GetTaskRunner(),
                               /*ui=*/thread->GetTaskRunner(),
                               /*io=*/thread->GetTaskRunner());
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  flutterPlatformViewsController->SetTaskRunner(thread->GetTaskRunner());
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/mock_delegate.settings_.enable_impeller
          ? flutter::IOSRenderingAPI::kMetal
          : flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners,
      /*worker_task_runner=*/nil,
      /*is_gpu_disabled_jsync_switch=*/std::make_shared<fml::SyncSwitch>());

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory alloc] init];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  XCTAssertNotNil(gMockPlatformView);

  // Find touch inteceptor view
  UIView* touchInteceptorView = gMockPlatformView;
  while (touchInteceptorView != nil &&
         ![touchInteceptorView isKindOfClass:[FlutterTouchInterceptingView class]]) {
    touchInteceptorView = touchInteceptorView.superview;
  }
  XCTAssertNotNil(touchInteceptorView);

  // Find ForwardGestureRecognizer
  UIGestureRecognizer* forwardGectureRecognizer = nil;
  for (UIGestureRecognizer* gestureRecognizer in touchInteceptorView.gestureRecognizers) {
    if ([gestureRecognizer isKindOfClass:NSClassFromString(@"ForwardingGestureRecognizer")]) {
      forwardGectureRecognizer = gestureRecognizer;
      break;
    }
  }
  id flutterViewContoller = OCMClassMock([FlutterViewController class]);
  {
    // ***** Sequence 1, finishing touch event with touchEnded ***** //
    flutterPlatformViewsController->SetFlutterViewController(flutterViewContoller);

    NSSet* touches1 = [[NSSet alloc] init];
    id event1 = OCMClassMock([UIEvent class]);
    [forwardGectureRecognizer touchesBegan:touches1 withEvent:event1];
    OCMVerify([flutterViewContoller touchesBegan:touches1 withEvent:event1]);

    flutterPlatformViewsController->SetFlutterViewController(nil);

    // Allow the touch events to finish
    NSSet* touches2 = [[NSSet alloc] init];
    id event2 = OCMClassMock([UIEvent class]);
    [forwardGectureRecognizer touchesMoved:touches2 withEvent:event2];
    OCMVerify([flutterViewContoller touchesMoved:touches2 withEvent:event2]);

    NSSet* touches3 = [[NSSet alloc] init];
    id event3 = OCMClassMock([UIEvent class]);
    [forwardGectureRecognizer touchesEnded:touches3 withEvent:event3];
    OCMVerify([flutterViewContoller touchesEnded:touches3 withEvent:event3]);

    // Now the 2nd touch sequence should not be allowed.
    NSSet* touches4 = [[NSSet alloc] init];
    id event4 = OCMClassMock([UIEvent class]);
    [forwardGectureRecognizer touchesBegan:touches4 withEvent:event4];
    OCMReject([flutterViewContoller touchesBegan:touches4 withEvent:event4]);

    NSSet* touches5 = [[NSSet alloc] init];
    id event5 = OCMClassMock([UIEvent class]);
    [forwardGectureRecognizer touchesEnded:touches5 withEvent:event5];
    OCMReject([flutterViewContoller touchesEnded:touches5 withEvent:event5]);
  }

  {
    // ***** Sequence 2, finishing touch event with touchCancelled ***** //
    flutterPlatformViewsController->SetFlutterViewController(flutterViewContoller);

    NSSet* touches1 = [[NSSet alloc] init];
    id event1 = OCMClassMock([UIEvent class]);
    [forwardGectureRecognizer touchesBegan:touches1 withEvent:event1];
    OCMVerify([flutterViewContoller touchesBegan:touches1 withEvent:event1]);

    flutterPlatformViewsController->SetFlutterViewController(nil);

    // Allow the touch events to finish
    NSSet* touches2 = [[NSSet alloc] init];
    id event2 = OCMClassMock([UIEvent class]);
    [forwardGectureRecognizer touchesMoved:touches2 withEvent:event2];
    OCMVerify([flutterViewContoller touchesMoved:touches2 withEvent:event2]);

    NSSet* touches3 = [[NSSet alloc] init];
    id event3 = OCMClassMock([UIEvent class]);
    [forwardGectureRecognizer touchesCancelled:touches3 withEvent:event3];
    OCMVerify([flutterViewContoller forceTouchesCancelled:touches3]);

    // Now the 2nd touch sequence should not be allowed.
    NSSet* touches4 = [[NSSet alloc] init];
    id event4 = OCMClassMock([UIEvent class]);
    [forwardGectureRecognizer touchesBegan:touches4 withEvent:event4];
    OCMReject([flutterViewContoller touchesBegan:touches4 withEvent:event4]);

    NSSet* touches5 = [[NSSet alloc] init];
    id event5 = OCMClassMock([UIEvent class]);
    [forwardGectureRecognizer touchesEnded:touches5 withEvent:event5];
    OCMReject([flutterViewContoller touchesEnded:touches5 withEvent:event5]);
  }

  flutterPlatformViewsController->Reset();
}

- (void)
    testSetFlutterViewControllerInTheMiddleOfTouchEventAllowsTheNewControllerToHandleSecondTouchSequence {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread = std::make_unique<fml::Thread>("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread->GetTaskRunner(),
                               /*raster=*/thread->GetTaskRunner(),
                               /*ui=*/thread->GetTaskRunner(),
                               /*io=*/thread->GetTaskRunner());
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  flutterPlatformViewsController->SetTaskRunner(thread->GetTaskRunner());
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/mock_delegate.settings_.enable_impeller
          ? flutter::IOSRenderingAPI::kMetal
          : flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners,
      /*worker_task_runner=*/nil,
      /*is_gpu_disabled_jsync_switch=*/std::make_shared<fml::SyncSwitch>());

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory alloc] init];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  XCTAssertNotNil(gMockPlatformView);

  // Find touch inteceptor view
  UIView* touchInteceptorView = gMockPlatformView;
  while (touchInteceptorView != nil &&
         ![touchInteceptorView isKindOfClass:[FlutterTouchInterceptingView class]]) {
    touchInteceptorView = touchInteceptorView.superview;
  }
  XCTAssertNotNil(touchInteceptorView);

  // Find ForwardGestureRecognizer
  UIGestureRecognizer* forwardGectureRecognizer = nil;
  for (UIGestureRecognizer* gestureRecognizer in touchInteceptorView.gestureRecognizers) {
    if ([gestureRecognizer isKindOfClass:NSClassFromString(@"ForwardingGestureRecognizer")]) {
      forwardGectureRecognizer = gestureRecognizer;
      break;
    }
  }
  id flutterViewContoller = OCMClassMock([FlutterViewController class]);

  flutterPlatformViewsController->SetFlutterViewController(flutterViewContoller);

  // The touches in this sequence requires 1 touch object, we always create the NSSet with one item.
  NSSet* touches1 = [NSSet setWithObject:@1];
  id event1 = OCMClassMock([UIEvent class]);
  [forwardGectureRecognizer touchesBegan:touches1 withEvent:event1];
  OCMVerify([flutterViewContoller touchesBegan:touches1 withEvent:event1]);

  FlutterViewController* flutterViewContoller2 = OCMClassMock([FlutterViewController class]);
  flutterPlatformViewsController->SetFlutterViewController(flutterViewContoller2);

  // Touch events should still send to the old FlutterViewController if FlutterViewController
  // is updated in between.
  NSSet* touches2 = [NSSet setWithObject:@1];
  id event2 = OCMClassMock([UIEvent class]);
  [forwardGectureRecognizer touchesBegan:touches2 withEvent:event2];
  OCMVerify([flutterViewContoller touchesBegan:touches2 withEvent:event2]);
  OCMReject([flutterViewContoller2 touchesBegan:touches2 withEvent:event2]);

  NSSet* touches3 = [NSSet setWithObject:@1];
  id event3 = OCMClassMock([UIEvent class]);
  [forwardGectureRecognizer touchesMoved:touches3 withEvent:event3];
  OCMVerify([flutterViewContoller touchesMoved:touches3 withEvent:event3]);
  OCMReject([flutterViewContoller2 touchesMoved:touches3 withEvent:event3]);

  NSSet* touches4 = [NSSet setWithObject:@1];
  id event4 = OCMClassMock([UIEvent class]);
  [forwardGectureRecognizer touchesEnded:touches4 withEvent:event4];
  OCMVerify([flutterViewContoller touchesEnded:touches4 withEvent:event4]);
  OCMReject([flutterViewContoller2 touchesEnded:touches4 withEvent:event4]);

  NSSet* touches5 = [NSSet setWithObject:@1];
  id event5 = OCMClassMock([UIEvent class]);
  [forwardGectureRecognizer touchesEnded:touches5 withEvent:event5];
  OCMVerify([flutterViewContoller touchesEnded:touches5 withEvent:event5]);
  OCMReject([flutterViewContoller2 touchesEnded:touches5 withEvent:event5]);

  // Now the 2nd touch sequence should go to the new FlutterViewController

  NSSet* touches6 = [NSSet setWithObject:@1];
  id event6 = OCMClassMock([UIEvent class]);
  [forwardGectureRecognizer touchesBegan:touches6 withEvent:event6];
  OCMVerify([flutterViewContoller2 touchesBegan:touches6 withEvent:event6]);
  OCMReject([flutterViewContoller touchesBegan:touches6 withEvent:event6]);

  // Allow the touch events to finish
  NSSet* touches7 = [NSSet setWithObject:@1];
  id event7 = OCMClassMock([UIEvent class]);
  [forwardGectureRecognizer touchesMoved:touches7 withEvent:event7];
  OCMVerify([flutterViewContoller2 touchesMoved:touches7 withEvent:event7]);
  OCMReject([flutterViewContoller touchesMoved:touches7 withEvent:event7]);

  NSSet* touches8 = [NSSet setWithObject:@1];
  id event8 = OCMClassMock([UIEvent class]);
  [forwardGectureRecognizer touchesEnded:touches8 withEvent:event8];
  OCMVerify([flutterViewContoller2 touchesEnded:touches8 withEvent:event8]);
  OCMReject([flutterViewContoller touchesEnded:touches8 withEvent:event8]);

  flutterPlatformViewsController->Reset();
}

- (void)testFlutterPlatformViewTouchesCancelledEventAreForcedToBeCancelled {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread = std::make_unique<fml::Thread>("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread->GetTaskRunner(),
                               /*raster=*/thread->GetTaskRunner(),
                               /*ui=*/thread->GetTaskRunner(),
                               /*io=*/thread->GetTaskRunner());
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  flutterPlatformViewsController->SetTaskRunner(thread->GetTaskRunner());
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/mock_delegate.settings_.enable_impeller
          ? flutter::IOSRenderingAPI::kMetal
          : flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners,
      /*worker_task_runner=*/nil,
      /*is_gpu_disabled_jsync_switch=*/std::make_shared<fml::SyncSwitch>());

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory alloc] init];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  XCTAssertNotNil(gMockPlatformView);

  // Find touch inteceptor view
  UIView* touchInteceptorView = gMockPlatformView;
  while (touchInteceptorView != nil &&
         ![touchInteceptorView isKindOfClass:[FlutterTouchInterceptingView class]]) {
    touchInteceptorView = touchInteceptorView.superview;
  }
  XCTAssertNotNil(touchInteceptorView);

  // Find ForwardGestureRecognizer
  UIGestureRecognizer* forwardGectureRecognizer = nil;
  for (UIGestureRecognizer* gestureRecognizer in touchInteceptorView.gestureRecognizers) {
    if ([gestureRecognizer isKindOfClass:NSClassFromString(@"ForwardingGestureRecognizer")]) {
      forwardGectureRecognizer = gestureRecognizer;
      break;
    }
  }
  id flutterViewContoller = OCMClassMock([FlutterViewController class]);

  flutterPlatformViewsController->SetFlutterViewController(flutterViewContoller);

  NSSet* touches1 = [NSSet setWithObject:@1];
  id event1 = OCMClassMock([UIEvent class]);
  [forwardGectureRecognizer touchesBegan:touches1 withEvent:event1];

  [forwardGectureRecognizer touchesCancelled:touches1 withEvent:event1];
  OCMVerify([flutterViewContoller forceTouchesCancelled:touches1]);

  flutterPlatformViewsController->Reset();
}

- (void)testFlutterPlatformViewControllerSubmitFrameWithoutFlutterViewNotCrashing {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread = std::make_unique<fml::Thread>("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread->GetTaskRunner(),
                               /*raster=*/thread->GetTaskRunner(),
                               /*ui=*/thread->GetTaskRunner(),
                               /*io=*/thread->GetTaskRunner());
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  flutterPlatformViewsController->SetTaskRunner(thread->GetTaskRunner());
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/mock_delegate.settings_.enable_impeller
          ? flutter::IOSRenderingAPI::kMetal
          : flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners,
      /*worker_task_runner=*/nil,
      /*is_gpu_disabled_jsync_switch=*/std::make_shared<fml::SyncSwitch>());

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory alloc] init];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  XCTAssertNotNil(gMockPlatformView);

  // Create embedded view params
  flutter::MutatorsStack stack;
  SkMatrix finalMatrix;

  auto embeddedViewParams_1 =
      std::make_unique<flutter::EmbeddedViewParams>(finalMatrix, SkSize::Make(300, 300), stack);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams_1));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  flutterPlatformViewsController->CompositeWithParams(
      2, flutterPlatformViewsController->GetCompositionParams(2));

  flutter::SurfaceFrame::FramebufferInfo framebuffer_info;
  auto mock_surface = std::make_unique<flutter::SurfaceFrame>(
      nullptr, framebuffer_info,
      [](const flutter::SurfaceFrame& surface_frame, flutter::DlCanvas* canvas) { return false; },
      /*frame_size=*/SkISize::Make(800, 600));
  XCTAssertFalse(
      flutterPlatformViewsController->SubmitFrame(nullptr, nullptr, std::move(mock_surface)));

  auto embeddedViewParams_2 =
      std::make_unique<flutter::EmbeddedViewParams>(finalMatrix, SkSize::Make(300, 300), stack);
  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams_2));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  flutterPlatformViewsController->CompositeWithParams(
      2, flutterPlatformViewsController->GetCompositionParams(2));

  auto mock_surface_submit_true = std::make_unique<flutter::SurfaceFrame>(
      nullptr, framebuffer_info,
      [](const flutter::SurfaceFrame& surface_frame, flutter::DlCanvas* canvas) { return true; },
      /*frame_size=*/SkISize::Make(800, 600));
  XCTAssertTrue(flutterPlatformViewsController->SubmitFrame(nullptr, nullptr,
                                                            std::move(mock_surface_submit_true)));
}

- (void)
    testFlutterPlatformViewControllerResetDeallocsPlatformViewWhenRootViewsNotBindedToFlutterView {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread = std::make_unique<fml::Thread>("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread->GetTaskRunner(),
                               /*raster=*/thread->GetTaskRunner(),
                               /*ui=*/thread->GetTaskRunner(),
                               /*io=*/thread->GetTaskRunner());
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  flutterPlatformViewsController->SetTaskRunner(thread->GetTaskRunner());
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/mock_delegate.settings_.enable_impeller
          ? flutter::IOSRenderingAPI::kMetal
          : flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners,
      /*worker_task_runner=*/nil,
      /*is_gpu_disabled_jsync_switch=*/std::make_shared<fml::SyncSwitch>());

  UIView* flutterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 500, 500)];
  flutterPlatformViewsController->SetFlutterView(flutterView);

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory alloc] init];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  // autorelease pool to trigger an autorelease for all the root_views_ and touch_interceptors_.
  @autoreleasepool {
    flutterPlatformViewsController->OnMethodCall(
        [FlutterMethodCall
            methodCallWithMethodName:@"create"
                           arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
        result);

    flutter::MutatorsStack stack;
    SkMatrix finalMatrix;
    auto embeddedViewParams =
        std::make_unique<flutter::EmbeddedViewParams>(finalMatrix, SkSize::Make(300, 300), stack);
    flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
    flutterPlatformViewsController->CompositeEmbeddedView(2);

    // Not calling |flutterPlatformViewsController::SubmitFrame| so that the platform views are not
    // added to flutter_view_.

    XCTAssertNotNil(gMockPlatformView);
    flutterPlatformViewsController->Reset();
  }
  XCTAssertNil(gMockPlatformView);
}

- (void)testFlutterPlatformViewControllerBeginFrameShouldResetCompisitionOrder {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread = std::make_unique<fml::Thread>("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread->GetTaskRunner(),
                               /*raster=*/thread->GetTaskRunner(),
                               /*ui=*/thread->GetTaskRunner(),
                               /*io=*/thread->GetTaskRunner());
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  flutterPlatformViewsController->SetTaskRunner(thread->GetTaskRunner());
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/mock_delegate.settings_.enable_impeller
          ? flutter::IOSRenderingAPI::kMetal
          : flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners,
      /*worker_task_runner=*/nil,
      /*is_gpu_disabled_jsync_switch=*/std::make_shared<fml::SyncSwitch>());

  UIView* flutterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 500, 500)];
  flutterPlatformViewsController->SetFlutterView(flutterView);

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory alloc] init];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };

  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @0, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  // First frame, |EmbeddedViewCount| is not empty after composite.
  flutterPlatformViewsController->BeginFrame(SkISize::Make(300, 300));
  flutter::MutatorsStack stack;
  SkMatrix finalMatrix;
  auto embeddedViewParams1 =
      std::make_unique<flutter::EmbeddedViewParams>(finalMatrix, SkSize::Make(300, 300), stack);
  flutterPlatformViewsController->PrerollCompositeEmbeddedView(0, std::move(embeddedViewParams1));
  flutterPlatformViewsController->CompositeEmbeddedView(0);
  flutterPlatformViewsController->CompositeWithParams(
      0, flutterPlatformViewsController->GetCompositionParams(0));

  XCTAssertEqual(flutterPlatformViewsController->EmbeddedViewCount(), 1UL);

  // Second frame, |EmbeddedViewCount| should be empty at the start
  flutterPlatformViewsController->BeginFrame(SkISize::Make(300, 300));
  XCTAssertEqual(flutterPlatformViewsController->EmbeddedViewCount(), 0UL);

  auto embeddedViewParams2 =
      std::make_unique<flutter::EmbeddedViewParams>(finalMatrix, SkSize::Make(300, 300), stack);
  flutterPlatformViewsController->PrerollCompositeEmbeddedView(0, std::move(embeddedViewParams2));
  flutterPlatformViewsController->CompositeEmbeddedView(0);
  flutterPlatformViewsController->CompositeWithParams(
      0, flutterPlatformViewsController->GetCompositionParams(0));

  XCTAssertEqual(flutterPlatformViewsController->EmbeddedViewCount(), 1UL);
}

- (void)
    testFlutterPlatformViewControllerSubmitFrameShouldOrderSubviewsCorrectlyWithDifferentViewHierarchy {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread = std::make_unique<fml::Thread>("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread->GetTaskRunner(),
                               /*raster=*/thread->GetTaskRunner(),
                               /*ui=*/thread->GetTaskRunner(),
                               /*io=*/thread->GetTaskRunner());
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  flutterPlatformViewsController->SetTaskRunner(thread->GetTaskRunner());
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/mock_delegate.settings_.enable_impeller
          ? flutter::IOSRenderingAPI::kMetal
          : flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners,
      /*worker_task_runner=*/nil,
      /*is_gpu_disabled_jsync_switch=*/std::make_shared<fml::SyncSwitch>());

  UIView* flutterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 500, 500)];
  flutterPlatformViewsController->SetFlutterView(flutterView);

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory alloc] init];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @0, @"viewType" : @"MockFlutterPlatformView"}],
      result);
  UIView* view1 = gMockPlatformView;

  // This overwrites `gMockPlatformView` to another view.
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @1, @"viewType" : @"MockFlutterPlatformView"}],
      result);
  UIView* view2 = gMockPlatformView;

  flutterPlatformViewsController->BeginFrame(SkISize::Make(300, 300));
  flutter::MutatorsStack stack;
  SkMatrix finalMatrix;
  auto embeddedViewParams1 =
      std::make_unique<flutter::EmbeddedViewParams>(finalMatrix, SkSize::Make(300, 300), stack);
  flutterPlatformViewsController->PrerollCompositeEmbeddedView(0, std::move(embeddedViewParams1));

  auto embeddedViewParams2 =
      std::make_unique<flutter::EmbeddedViewParams>(finalMatrix, SkSize::Make(500, 500), stack);
  flutterPlatformViewsController->PrerollCompositeEmbeddedView(1, std::move(embeddedViewParams2));

  // SKSurface is required if the root FlutterView is present.
  const SkImageInfo image_info = SkImageInfo::MakeN32Premul(1000, 1000);
  sk_sp<SkSurface> mock_sk_surface = SkSurfaces::Raster(image_info);
  flutter::SurfaceFrame::FramebufferInfo framebuffer_info;
  auto mock_surface = std::make_unique<flutter::SurfaceFrame>(
      std::move(mock_sk_surface), framebuffer_info,
      [](const flutter::SurfaceFrame& surface_frame, flutter::DlCanvas* canvas) { return true; },
      /*frame_size=*/SkISize::Make(800, 600));

  auto latch = std::make_shared<fml::CountDownLatch>(1u);
  thread->GetTaskRunner()->PostTask([&latch]() { latch->CountDown(); });
  latch->Wait();

  XCTAssertTrue(
      flutterPlatformViewsController->SubmitFrame(nullptr, nullptr, std::move(mock_surface)));

  // platform view is wrapped by touch interceptor, which itself is wrapped by clipping view.
  UIView* clippingView1 = view1.superview.superview;
  UIView* clippingView2 = view2.superview.superview;
  XCTAssertTrue([flutterView.subviews indexOfObject:clippingView1] <
                    [flutterView.subviews indexOfObject:clippingView2],
                @"The first clipping view should be added before the second clipping view.");

  // Need to recreate these params since they are `std::move`ed.
  flutterPlatformViewsController->BeginFrame(SkISize::Make(300, 300));
  // Process the second frame in the opposite order.
  embeddedViewParams2 =
      std::make_unique<flutter::EmbeddedViewParams>(finalMatrix, SkSize::Make(500, 500), stack);
  flutterPlatformViewsController->PrerollCompositeEmbeddedView(1, std::move(embeddedViewParams2));

  embeddedViewParams1 =
      std::make_unique<flutter::EmbeddedViewParams>(finalMatrix, SkSize::Make(300, 300), stack);
  flutterPlatformViewsController->PrerollCompositeEmbeddedView(0, std::move(embeddedViewParams1));

  mock_sk_surface = SkSurfaces::Raster(image_info);
  mock_surface = std::make_unique<flutter::SurfaceFrame>(
      std::move(mock_sk_surface), framebuffer_info,
      [](const flutter::SurfaceFrame& surface_frame, flutter::DlCanvas* canvas) { return true; },
      /*frame_size=*/SkISize::Make(800, 600));
  XCTAssertTrue(
      flutterPlatformViewsController->SubmitFrame(nullptr, nullptr, std::move(mock_surface)));

  latch = std::make_shared<fml::CountDownLatch>(1u);
  thread->GetTaskRunner()->PostTask([&latch]() { latch->CountDown(); });
  latch->Wait();

  XCTAssertTrue([flutterView.subviews indexOfObject:clippingView1] >
                    [flutterView.subviews indexOfObject:clippingView2],
                @"The first clipping view should be added after the second clipping view.");
}

- (void)
    testFlutterPlatformViewControllerSubmitFrameShouldOrderSubviewsCorrectlyWithSameViewHierarchy {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread = std::make_unique<fml::Thread>("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread->GetTaskRunner(),
                               /*raster=*/thread->GetTaskRunner(),
                               /*ui=*/thread->GetTaskRunner(),
                               /*io=*/thread->GetTaskRunner());
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  flutterPlatformViewsController->SetTaskRunner(thread->GetTaskRunner());
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/mock_delegate.settings_.enable_impeller
          ? flutter::IOSRenderingAPI::kMetal
          : flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners,
      /*worker_task_runner=*/nil,
      /*is_gpu_disabled_jsync_switch=*/std::make_shared<fml::SyncSwitch>());

  UIView* flutterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 500, 500)];
  flutterPlatformViewsController->SetFlutterView(flutterView);

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory alloc] init];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @0, @"viewType" : @"MockFlutterPlatformView"}],
      result);
  UIView* view1 = gMockPlatformView;

  // This overwrites `gMockPlatformView` to another view.
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @1, @"viewType" : @"MockFlutterPlatformView"}],
      result);
  UIView* view2 = gMockPlatformView;

  flutterPlatformViewsController->BeginFrame(SkISize::Make(300, 300));
  flutter::MutatorsStack stack;
  SkMatrix finalMatrix;
  auto embeddedViewParams1 =
      std::make_unique<flutter::EmbeddedViewParams>(finalMatrix, SkSize::Make(300, 300), stack);
  flutterPlatformViewsController->PrerollCompositeEmbeddedView(0, std::move(embeddedViewParams1));

  auto embeddedViewParams2 =
      std::make_unique<flutter::EmbeddedViewParams>(finalMatrix, SkSize::Make(500, 500), stack);
  flutterPlatformViewsController->PrerollCompositeEmbeddedView(1, std::move(embeddedViewParams2));

  // SKSurface is required if the root FlutterView is present.
  const SkImageInfo image_info = SkImageInfo::MakeN32Premul(1000, 1000);
  sk_sp<SkSurface> mock_sk_surface = SkSurfaces::Raster(image_info);
  flutter::SurfaceFrame::FramebufferInfo framebuffer_info;
  auto mock_surface = std::make_unique<flutter::SurfaceFrame>(
      std::move(mock_sk_surface), framebuffer_info,
      [](const flutter::SurfaceFrame& surface_frame, flutter::DlCanvas* canvas) { return true; },
      /*frame_size=*/SkISize::Make(800, 600));

  XCTAssertTrue(
      flutterPlatformViewsController->SubmitFrame(nullptr, nullptr, std::move(mock_surface)));
  auto latch = std::make_shared<fml::CountDownLatch>(1u);
  thread->GetTaskRunner()->PostTask([&latch]() { latch->CountDown(); });
  latch->Wait();

  // platform view is wrapped by touch interceptor, which itself is wrapped by clipping view.
  UIView* clippingView1 = view1.superview.superview;
  UIView* clippingView2 = view2.superview.superview;
  XCTAssertTrue([flutterView.subviews indexOfObject:clippingView1] <
                    [flutterView.subviews indexOfObject:clippingView2],
                @"The first clipping view should be added before the second clipping view.");

  // Need to recreate these params since they are `std::move`ed.
  flutterPlatformViewsController->BeginFrame(SkISize::Make(300, 300));
  // Process the second frame in the same order.
  embeddedViewParams1 =
      std::make_unique<flutter::EmbeddedViewParams>(finalMatrix, SkSize::Make(300, 300), stack);
  flutterPlatformViewsController->PrerollCompositeEmbeddedView(0, std::move(embeddedViewParams1));

  embeddedViewParams2 =
      std::make_unique<flutter::EmbeddedViewParams>(finalMatrix, SkSize::Make(500, 500), stack);
  flutterPlatformViewsController->PrerollCompositeEmbeddedView(1, std::move(embeddedViewParams2));

  mock_sk_surface = SkSurfaces::Raster(image_info);
  mock_surface = std::make_unique<flutter::SurfaceFrame>(
      std::move(mock_sk_surface), framebuffer_info,
      [](const flutter::SurfaceFrame& surface_frame, flutter::DlCanvas* canvas) { return true; },
      /*frame_size=*/SkISize::Make(800, 600));
  XCTAssertTrue(
      flutterPlatformViewsController->SubmitFrame(nullptr, nullptr, std::move(mock_surface)));

  latch = std::make_shared<fml::CountDownLatch>(1u);
  thread->GetTaskRunner()->PostTask([&latch]() { latch->CountDown(); });
  latch->Wait();

  XCTAssertTrue([flutterView.subviews indexOfObject:clippingView1] <
                    [flutterView.subviews indexOfObject:clippingView2],
                @"The first clipping view should be added before the second clipping view.");
}

- (int)alphaOfPoint:(CGPoint)point onView:(UIView*)view {
  unsigned char pixel[4] = {0};

  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

  // Draw the pixel on `point` in the context.
  CGContextRef context = CGBitmapContextCreate(
      pixel, 1, 1, 8, 4, colorSpace, kCGBitmapAlphaInfoMask & kCGImageAlphaPremultipliedLast);
  CGContextTranslateCTM(context, -point.x, -point.y);
  [view.layer renderInContext:context];

  CGContextRelease(context);
  CGColorSpaceRelease(colorSpace);
  // Get the alpha from the pixel that we just rendered.
  return pixel[3];
}

- (void)testHasFirstResponderInViewHierarchySubtree_viewItselfBecomesFirstResponder {
  // For view to become the first responder, it must be a descendant of a UIWindow
  UIWindow* window = [[UIWindow alloc] init];
  UITextField* textField = [[UITextField alloc] init];
  [window addSubview:textField];

  [textField becomeFirstResponder];
  XCTAssertTrue(textField.isFirstResponder);
  XCTAssertTrue(textField.flt_hasFirstResponderInViewHierarchySubtree);
  [textField resignFirstResponder];
  XCTAssertFalse(textField.isFirstResponder);
  XCTAssertFalse(textField.flt_hasFirstResponderInViewHierarchySubtree);
}

- (void)testHasFirstResponderInViewHierarchySubtree_descendantViewBecomesFirstResponder {
  // For view to become the first responder, it must be a descendant of a UIWindow
  UIWindow* window = [[UIWindow alloc] init];
  UIView* view = [[UIView alloc] init];
  UIView* childView = [[UIView alloc] init];
  UITextField* textField = [[UITextField alloc] init];
  [window addSubview:view];
  [view addSubview:childView];
  [childView addSubview:textField];

  [textField becomeFirstResponder];
  XCTAssertTrue(textField.isFirstResponder);
  XCTAssertTrue(view.flt_hasFirstResponderInViewHierarchySubtree);
  [textField resignFirstResponder];
  XCTAssertFalse(textField.isFirstResponder);
  XCTAssertFalse(view.flt_hasFirstResponderInViewHierarchySubtree);
}

- (void)testFlutterClippingMaskViewPoolReuseViewsAfterRecycle {
  FlutterClippingMaskViewPool* pool = [[FlutterClippingMaskViewPool alloc] initWithCapacity:2];
  FlutterClippingMaskView* view1 = [pool getMaskViewWithFrame:CGRectZero];
  FlutterClippingMaskView* view2 = [pool getMaskViewWithFrame:CGRectZero];
  [pool insertViewToPoolIfNeeded:view1];
  [pool insertViewToPoolIfNeeded:view2];
  CGRect newRect = CGRectMake(0, 0, 10, 10);
  FlutterClippingMaskView* view3 = [pool getMaskViewWithFrame:newRect];
  FlutterClippingMaskView* view4 = [pool getMaskViewWithFrame:newRect];
  // view3 and view4 should randomly get either of view1 and view2.
  NSSet* set1 = [NSSet setWithObjects:view1, view2, nil];
  NSSet* set2 = [NSSet setWithObjects:view3, view4, nil];
  XCTAssertEqualObjects(set1, set2);
  XCTAssertTrue(CGRectEqualToRect(view3.frame, newRect));
  XCTAssertTrue(CGRectEqualToRect(view4.frame, newRect));
}

- (void)testFlutterClippingMaskViewPoolAllocsNewMaskViewsAfterReachingCapacity {
  FlutterClippingMaskViewPool* pool = [[FlutterClippingMaskViewPool alloc] initWithCapacity:2];
  FlutterClippingMaskView* view1 = [pool getMaskViewWithFrame:CGRectZero];
  FlutterClippingMaskView* view2 = [pool getMaskViewWithFrame:CGRectZero];
  FlutterClippingMaskView* view3 = [pool getMaskViewWithFrame:CGRectZero];
  XCTAssertNotEqual(view1, view3);
  XCTAssertNotEqual(view2, view3);
}

- (void)testMaskViewsReleasedWhenPoolIsReleased {
  __weak UIView* weakView;
  @autoreleasepool {
    FlutterClippingMaskViewPool* pool = [[FlutterClippingMaskViewPool alloc] initWithCapacity:2];
    FlutterClippingMaskView* view = [pool getMaskViewWithFrame:CGRectZero];
    weakView = view;
    XCTAssertNotNil(weakView);
  }
  XCTAssertNil(weakView);
}

- (void)testClipMaskViewIsReused {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread = std::make_unique<fml::Thread>("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread->GetTaskRunner(),
                               /*raster=*/thread->GetTaskRunner(),
                               /*ui=*/thread->GetTaskRunner(),
                               /*io=*/thread->GetTaskRunner());
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  flutterPlatformViewsController->SetTaskRunner(thread->GetTaskRunner());
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/mock_delegate.settings_.enable_impeller
          ? flutter::IOSRenderingAPI::kMetal
          : flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners,
      /*worker_task_runner=*/nil,
      /*is_gpu_disabled_jsync_switch=*/std::make_shared<fml::SyncSwitch>());

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory alloc] init];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @1, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  XCTAssertNotNil(gMockPlatformView);
  UIView* flutterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
  flutterPlatformViewsController->SetFlutterView(flutterView);
  // Create embedded view params
  flutter::MutatorsStack stack1;
  // Layer tree always pushes a screen scale factor to the stack
  SkMatrix screenScaleMatrix =
      SkMatrix::Scale([UIScreen mainScreen].scale, [UIScreen mainScreen].scale);
  stack1.PushTransform(screenScaleMatrix);
  // Push a clip rect
  SkRect rect = SkRect::MakeXYWH(2, 2, 3, 3);
  stack1.PushClipRect(rect);

  auto embeddedViewParams1 = std::make_unique<flutter::EmbeddedViewParams>(
      screenScaleMatrix, SkSize::Make(10, 10), stack1);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(1, std::move(embeddedViewParams1));
  flutterPlatformViewsController->CompositeEmbeddedView(1);
  flutterPlatformViewsController->CompositeWithParams(
      1, flutterPlatformViewsController->GetCompositionParams(1));

  UIView* childClippingView1 = gMockPlatformView.superview.superview;
  UIView* maskView1 = childClippingView1.maskView;
  XCTAssertNotNil(maskView1);

  // Composite a new frame.
  flutterPlatformViewsController->BeginFrame(SkISize::Make(100, 100));
  flutter::MutatorsStack stack2;
  auto embeddedViewParams2 = std::make_unique<flutter::EmbeddedViewParams>(
      screenScaleMatrix, SkSize::Make(10, 10), stack2);
  auto embeddedViewParams3 = std::make_unique<flutter::EmbeddedViewParams>(
      screenScaleMatrix, SkSize::Make(10, 10), stack2);
  flutterPlatformViewsController->PrerollCompositeEmbeddedView(1, std::move(embeddedViewParams3));
  flutterPlatformViewsController->CompositeEmbeddedView(1);
  flutterPlatformViewsController->CompositeWithParams(
      1, flutterPlatformViewsController->GetCompositionParams(1));

  childClippingView1 = gMockPlatformView.superview.superview;

  // This overrides gMockPlatformView to point to the newly created platform view.
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  auto embeddedViewParams4 = std::make_unique<flutter::EmbeddedViewParams>(
      screenScaleMatrix, SkSize::Make(10, 10), stack1);
  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams4));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  flutterPlatformViewsController->CompositeWithParams(
      2, flutterPlatformViewsController->GetCompositionParams(2));

  UIView* childClippingView2 = gMockPlatformView.superview.superview;

  UIView* maskView2 = childClippingView2.maskView;
  XCTAssertEqual(maskView1, maskView2);
  XCTAssertNotNil(childClippingView2.maskView);
  XCTAssertNil(childClippingView1.maskView);
}

- (void)testDifferentClipMaskViewIsUsedForEachView {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread = std::make_unique<fml::Thread>("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread->GetTaskRunner(),
                               /*raster=*/thread->GetTaskRunner(),
                               /*ui=*/thread->GetTaskRunner(),
                               /*io=*/thread->GetTaskRunner());
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  flutterPlatformViewsController->SetTaskRunner(thread->GetTaskRunner());
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/mock_delegate.settings_.enable_impeller
          ? flutter::IOSRenderingAPI::kMetal
          : flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners,
      /*worker_task_runner=*/nil,
      /*is_gpu_disabled_jsync_switch=*/std::make_shared<fml::SyncSwitch>());

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory alloc] init];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };

  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @1, @"viewType" : @"MockFlutterPlatformView"}],
      result);
  UIView* view1 = gMockPlatformView;

  // This overwrites `gMockPlatformView` to another view.
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
      result);
  UIView* view2 = gMockPlatformView;

  XCTAssertNotNil(gMockPlatformView);
  UIView* flutterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
  flutterPlatformViewsController->SetFlutterView(flutterView);
  // Create embedded view params
  flutter::MutatorsStack stack1;
  // Layer tree always pushes a screen scale factor to the stack
  SkMatrix screenScaleMatrix =
      SkMatrix::Scale([UIScreen mainScreen].scale, [UIScreen mainScreen].scale);
  stack1.PushTransform(screenScaleMatrix);
  // Push a clip rect
  SkRect rect = SkRect::MakeXYWH(2, 2, 3, 3);
  stack1.PushClipRect(rect);

  auto embeddedViewParams1 = std::make_unique<flutter::EmbeddedViewParams>(
      screenScaleMatrix, SkSize::Make(10, 10), stack1);

  flutter::MutatorsStack stack2;
  stack2.PushClipRect(rect);
  auto embeddedViewParams2 = std::make_unique<flutter::EmbeddedViewParams>(
      screenScaleMatrix, SkSize::Make(10, 10), stack2);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(1, std::move(embeddedViewParams1));
  flutterPlatformViewsController->CompositeEmbeddedView(1);
  flutterPlatformViewsController->CompositeWithParams(
      1, flutterPlatformViewsController->GetCompositionParams(1));

  UIView* childClippingView1 = view1.superview.superview;

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams2));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  flutterPlatformViewsController->CompositeWithParams(
      2, flutterPlatformViewsController->GetCompositionParams(2));

  UIView* childClippingView2 = view2.superview.superview;
  UIView* maskView1 = childClippingView1.maskView;
  UIView* maskView2 = childClippingView2.maskView;
  XCTAssertNotEqual(maskView1, maskView2);
}

- (void)testMaskViewUsesCAShapeLayerAsTheBackingLayer {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread = std::make_unique<fml::Thread>("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread->GetTaskRunner(),
                               /*raster=*/thread->GetTaskRunner(),
                               /*ui=*/thread->GetTaskRunner(),
                               /*io=*/thread->GetTaskRunner());
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  flutterPlatformViewsController->SetTaskRunner(thread->GetTaskRunner());
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/mock_delegate.settings_.enable_impeller
          ? flutter::IOSRenderingAPI::kMetal
          : flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners,
      /*worker_task_runner=*/nil,
      /*is_gpu_disabled_jsync_switch=*/std::make_shared<fml::SyncSwitch>());

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory alloc] init];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };

  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @1, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  XCTAssertNotNil(gMockPlatformView);
  UIView* flutterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
  flutterPlatformViewsController->SetFlutterView(flutterView);
  // Create embedded view params
  flutter::MutatorsStack stack1;
  // Layer tree always pushes a screen scale factor to the stack
  SkMatrix screenScaleMatrix =
      SkMatrix::Scale([UIScreen mainScreen].scale, [UIScreen mainScreen].scale);
  stack1.PushTransform(screenScaleMatrix);
  // Push a clip rect
  SkRect rect = SkRect::MakeXYWH(2, 2, 3, 3);
  stack1.PushClipRect(rect);

  auto embeddedViewParams1 = std::make_unique<flutter::EmbeddedViewParams>(
      screenScaleMatrix, SkSize::Make(10, 10), stack1);

  flutter::MutatorsStack stack2;
  stack2.PushClipRect(rect);
  auto embeddedViewParams2 = std::make_unique<flutter::EmbeddedViewParams>(
      screenScaleMatrix, SkSize::Make(10, 10), stack2);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(1, std::move(embeddedViewParams1));
  flutterPlatformViewsController->CompositeEmbeddedView(1);
  flutterPlatformViewsController->CompositeWithParams(
      1, flutterPlatformViewsController->GetCompositionParams(1));

  UIView* childClippingView = gMockPlatformView.superview.superview;

  UIView* maskView = childClippingView.maskView;
  XCTAssert([maskView.layer isKindOfClass:[CAShapeLayer class]],
            @"Mask view must use CAShapeLayer as its backing layer.");
}

// Return true if a correct visual effect view is found. It also implies all the validation in this
// method passes.
//
// There are two fail states for this method. 1. One of the XCTAssert method failed; or 2. No
// correct visual effect view found.
- (BOOL)validateOneVisualEffectView:(UIView*)visualEffectView
                      expectedFrame:(CGRect)frame
                        inputRadius:(CGFloat)inputRadius {
  XCTAssertTrue(CGRectEqualToRect(visualEffectView.frame, frame));
  for (UIView* view in visualEffectView.subviews) {
    if (![NSStringFromClass([view class]) hasSuffix:@"BackdropView"]) {
      continue;
    }
    XCTAssertEqual(view.layer.filters.count, 1u);
    NSObject* filter = view.layer.filters.firstObject;

    XCTAssertEqualObjects([filter valueForKey:@"name"], @"gaussianBlur");

    NSObject* inputRadiusInFilter = [filter valueForKey:@"inputRadius"];
    XCTAssertTrue([inputRadiusInFilter isKindOfClass:[NSNumber class]] &&
                  flutter::BlurRadiusEqualToBlurRadius(((NSNumber*)inputRadiusInFilter).floatValue,
                                                       inputRadius));
    return YES;
  }
  return NO;
}

- (void)testDisposingViewInCompositionOrderDoNotCrash {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread = std::make_unique<fml::Thread>("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread->GetTaskRunner(),
                               /*raster=*/thread->GetTaskRunner(),
                               /*ui=*/thread->GetTaskRunner(),
                               /*io=*/thread->GetTaskRunner());
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  flutterPlatformViewsController->SetTaskRunner(thread->GetTaskRunner());
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/mock_delegate.settings_.enable_impeller
          ? flutter::IOSRenderingAPI::kMetal
          : flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners,
      /*worker_task_runner=*/nil,
      /*is_gpu_disabled_jsync_switch=*/std::make_shared<fml::SyncSwitch>());

  UIView* flutterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 500, 500)];
  flutterPlatformViewsController->SetFlutterView(flutterView);

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory alloc] init];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };

  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @0, @"viewType" : @"MockFlutterPlatformView"}],
      result);
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @1, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  {
    // **** First frame, view id 0, 1 in the composition_order_, disposing view 0 is called. **** //
    // No view should be disposed, or removed from the composition order.
    flutterPlatformViewsController->BeginFrame(SkISize::Make(300, 300));
    flutter::MutatorsStack stack;
    SkMatrix finalMatrix;
    auto embeddedViewParams0 =
        std::make_unique<flutter::EmbeddedViewParams>(finalMatrix, SkSize::Make(300, 300), stack);
    flutterPlatformViewsController->PrerollCompositeEmbeddedView(0, std::move(embeddedViewParams0));

    auto embeddedViewParams1 =
        std::make_unique<flutter::EmbeddedViewParams>(finalMatrix, SkSize::Make(300, 300), stack);
    flutterPlatformViewsController->PrerollCompositeEmbeddedView(1, std::move(embeddedViewParams1));

    XCTAssertEqual(flutterPlatformViewsController->EmbeddedViewCount(), 2UL);

    XCTestExpectation* expectation = [self expectationWithDescription:@"dispose call ended."];
    FlutterResult disposeResult = ^(id result) {
      [expectation fulfill];
    };

    flutterPlatformViewsController->OnMethodCall(
        [FlutterMethodCall methodCallWithMethodName:@"dispose" arguments:@0], disposeResult);
    [self waitForExpectationsWithTimeout:30 handler:nil];

    const SkImageInfo image_info = SkImageInfo::MakeN32Premul(1000, 1000);
    sk_sp<SkSurface> mock_sk_surface = SkSurfaces::Raster(image_info);
    flutter::SurfaceFrame::FramebufferInfo framebuffer_info;
    auto mock_surface = std::make_unique<flutter::SurfaceFrame>(
        std::move(mock_sk_surface), framebuffer_info,
        [](const flutter::SurfaceFrame& surface_frame, flutter::DlCanvas* canvas) { return true; },
        /*frame_size=*/SkISize::Make(800, 600));
    XCTAssertTrue(
        flutterPlatformViewsController->SubmitFrame(nullptr, nullptr, std::move(mock_surface)));

    auto latch = std::make_shared<fml::CountDownLatch>(1u);
    thread->GetTaskRunner()->PostTask([&latch]() { latch->CountDown(); });
    latch->Wait();

    // Disposing won't remove embedded views until the view is removed from the composition_order_
    XCTAssertEqual(flutterPlatformViewsController->EmbeddedViewCount(), 2UL);
    XCTAssertNotNil(flutterPlatformViewsController->GetPlatformViewByID(0));
    XCTAssertNotNil(flutterPlatformViewsController->GetPlatformViewByID(1));
  }

  {
    // **** Second frame, view id 1 in the composition_order_, no disposing view is called,  **** //
    // View 0 is removed from the composition order in this frame, hence also disposed.
    flutterPlatformViewsController->BeginFrame(SkISize::Make(300, 300));
    flutter::MutatorsStack stack;
    SkMatrix finalMatrix;
    auto embeddedViewParams1 =
        std::make_unique<flutter::EmbeddedViewParams>(finalMatrix, SkSize::Make(300, 300), stack);
    flutterPlatformViewsController->PrerollCompositeEmbeddedView(1, std::move(embeddedViewParams1));

    const SkImageInfo image_info = SkImageInfo::MakeN32Premul(1000, 1000);
    sk_sp<SkSurface> mock_sk_surface = SkSurfaces::Raster(image_info);
    flutter::SurfaceFrame::FramebufferInfo framebuffer_info;
    auto mock_surface = std::make_unique<flutter::SurfaceFrame>(
        std::move(mock_sk_surface), framebuffer_info,
        [](const flutter::SurfaceFrame& surface_frame, flutter::DlCanvas* canvas) { return true; },
        /*frame_size=*/SkISize::Make(800, 600));
    XCTAssertTrue(
        flutterPlatformViewsController->SubmitFrame(nullptr, nullptr, std::move(mock_surface)));

    auto latch = std::make_shared<fml::CountDownLatch>(1u);
    thread->GetTaskRunner()->PostTask([&latch]() { latch->CountDown(); });
    latch->Wait();

    // Disposing won't remove embedded views until the view is removed from the composition_order_
    XCTAssertEqual(flutterPlatformViewsController->EmbeddedViewCount(), 1UL);
    XCTAssertNil(flutterPlatformViewsController->GetPlatformViewByID(0));
    XCTAssertNotNil(flutterPlatformViewsController->GetPlatformViewByID(1));
  }
}
- (void)testOnlyPlatformViewsAreRemovedWhenReset {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread = std::make_unique<fml::Thread>("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread->GetTaskRunner(),
                               /*raster=*/thread->GetTaskRunner(),
                               /*ui=*/thread->GetTaskRunner(),
                               /*io=*/thread->GetTaskRunner());
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  flutterPlatformViewsController->SetTaskRunner(thread->GetTaskRunner());
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/mock_delegate.settings_.enable_impeller
          ? flutter::IOSRenderingAPI::kMetal
          : flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners,
      /*worker_task_runner=*/nil,
      /*is_gpu_disabled_jsync_switch=*/std::make_shared<fml::SyncSwitch>());

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory alloc] init];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
      result);
  UIView* flutterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 500, 500)];
  flutterPlatformViewsController->SetFlutterView(flutterView);
  // Create embedded view params
  flutter::MutatorsStack stack;
  // Layer tree always pushes a screen scale factor to the stack
  SkMatrix screenScaleMatrix =
      SkMatrix::Scale([UIScreen mainScreen].scale, [UIScreen mainScreen].scale);
  stack.PushTransform(screenScaleMatrix);
  // Push a translate matrix
  SkMatrix translateMatrix = SkMatrix::Translate(100, 100);
  stack.PushTransform(translateMatrix);
  SkMatrix finalMatrix;
  finalMatrix.setConcat(screenScaleMatrix, translateMatrix);

  auto embeddedViewParams =
      std::make_unique<flutter::EmbeddedViewParams>(finalMatrix, SkSize::Make(300, 300), stack);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
  flutterPlatformViewsController->CompositeEmbeddedView(2);

  // SKSurface is required if the root FlutterView is present.
  const SkImageInfo image_info = SkImageInfo::MakeN32Premul(1000, 1000);
  sk_sp<SkSurface> mock_sk_surface = SkSurfaces::Raster(image_info);
  flutter::SurfaceFrame::FramebufferInfo framebuffer_info;
  auto mock_surface = std::make_unique<flutter::SurfaceFrame>(
      std::move(mock_sk_surface), framebuffer_info,
      [](const flutter::SurfaceFrame& surface_frame, flutter::DlCanvas* canvas) { return true; },
      /*frame_size=*/SkISize::Make(800, 600));

  flutterPlatformViewsController->SubmitFrame(nullptr, nullptr, std::move(mock_surface));

  auto latch = std::make_shared<fml::CountDownLatch>(1u);
  thread->GetTaskRunner()->PostTask([&latch]() { latch->CountDown(); });
  latch->Wait();

  UIView* someView = [[UIView alloc] init];
  [flutterView addSubview:someView];

  flutterPlatformViewsController->Reset();
  XCTAssertEqual(flutterView.subviews.count, 1u);
  XCTAssertEqual(flutterView.subviews.firstObject, someView);
}

- (void)testFlutterTouchInterceptingViewLinksToAccessibilityContainer {
  FlutterTouchInterceptingView* touchInteceptorView = [[FlutterTouchInterceptingView alloc] init];
  NSObject* container = [[NSObject alloc] init];
  [touchInteceptorView setFlutterAccessibilityContainer:container];
  XCTAssertEqualObjects([touchInteceptorView accessibilityContainer], container);
}

@end
