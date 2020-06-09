// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#define FML_USED_ON_EMBEDDER

#include <functional>
#include <future>
#include <memory>

#include "flutter/shell/common/animator.h"
#include "flutter/shell/common/shell_test.h"
#include "flutter/shell/common/shell_test_platform_view.h"
#include "flutter/testing/testing.h"
#include "gtest/gtest.h"

namespace flutter {
namespace testing {

TEST_F(ShellTest, VSyncTargetTime) {
  // Add native callbacks to listen for window.onBeginFrame
  int64_t target_time;
  fml::AutoResetWaitableEvent on_target_time_latch;
  auto nativeOnBeginFrame = [&on_target_time_latch,
                             &target_time](Dart_NativeArguments args) {
    Dart_Handle exception = nullptr;
    target_time =
        tonic::DartConverter<int64_t>::FromArguments(args, 0, exception);
    on_target_time_latch.Signal();
  };
  AddNativeCallback("NativeOnBeginFrame",
                    CREATE_NATIVE_ENTRY(nativeOnBeginFrame));

  // Create all te prerequisites for a shell.
  ASSERT_FALSE(DartVMRef::IsInstanceRunning());
  auto settings = CreateSettingsForFixture();

  std::unique_ptr<Shell> shell;

  TaskRunners task_runners = GetTaskRunnersForFixture();
  // this is not used as we are not using simulated events.
  const auto vsync_clock = std::make_shared<ShellTestVsyncClock>();
  CreateVsyncWaiter create_vsync_waiter = [&]() {
    return static_cast<std::unique_ptr<VsyncWaiter>>(
        std::make_unique<ConstantFiringVsyncWaiter>(task_runners));
  };

  // create a shell with a constant firing vsync waiter.
  auto platform_task = std::async(std::launch::async, [&]() {
    fml::MessageLoop::EnsureInitializedForCurrentThread();

    shell = Shell::Create(
        task_runners, settings,
        [vsync_clock, &create_vsync_waiter](Shell& shell) {
          return ShellTestPlatformView::Create(
              shell, shell.GetTaskRunners(), vsync_clock,
              std::move(create_vsync_waiter),
              ShellTestPlatformView::BackendType::kDefaultBackend, nullptr);
        },
        [](Shell& shell) {
          return std::make_unique<Rasterizer>(
              shell, shell.GetTaskRunners(),
              shell.GetIsGpuDisabledSyncSwitch());
        });
    ASSERT_TRUE(DartVMRef::IsInstanceRunning());

    auto configuration = RunConfiguration::InferFromSettings(settings);
    ASSERT_TRUE(configuration.IsValid());
    configuration.SetEntrypoint("onBeginFrameMain");

    RunEngine(shell.get(), std::move(configuration));
  });
  platform_task.wait();

  // schedule a frame to trigger window.onBeginFrame
  fml::TaskRunner::RunNowOrPostTask(shell->GetTaskRunners().GetUITaskRunner(),
                                    [engine = shell->GetEngine()]() {
                                      if (engine) {
                                        // this implies we can re-use the last
                                        // frame to trigger begin frame rather
                                        // than re-generating the layer tree.
                                        engine->ScheduleFrame(true);
                                      }
                                    });

  on_target_time_latch.Wait();
  const auto vsync_waiter_target_time =
      ConstantFiringVsyncWaiter::frame_target_time;
  ASSERT_EQ(vsync_waiter_target_time.ToEpochDelta().ToMicroseconds(),
            target_time);

  // validate that the latest target time has also been updated.
  ASSERT_EQ(GetLatestFrameTargetTime(shell.get()), vsync_waiter_target_time);

  // teardown.
  DestroyShell(std::move(shell), std::move(task_runners));
  ASSERT_FALSE(DartVMRef::IsInstanceRunning());
}

// TEST_F(ShellTest, OnPlatformViewDestoryStopsAnimator) {
//   // Add native callbacks to listen for window.onBeginFrame
//   fml::AutoResetWaitableEvent latch;
//   int on_begin_frame_triggered = 0;
//   auto nativeOnBeginFrame = [&latch, &on_begin_frame_triggered](Dart_NativeArguments args) {
//     on_begin_frame_triggered ++;
//     latch.Signal();
//   };
//   AddNativeCallback("NativeOnBeginFrame",
//                     CREATE_NATIVE_ENTRY(nativeOnBeginFrame));

//   // Create all te prerequisites for a shell.
//   ASSERT_FALSE(DartVMRef::IsInstanceRunning());
//   auto settings = CreateSettingsForFixture();

//   std::unique_ptr<Shell> shell;

//   TaskRunners task_runners = GetTaskRunnersForFixture();
//   // this is not used as we are not using simulated events.
//   const auto vsync_clock = std::make_shared<ShellTestVsyncClock>();
//   CreateVsyncWaiter create_vsync_waiter = [&]() {
//     return static_cast<std::unique_ptr<VsyncWaiter>>(
//         std::make_unique<ConstantFiringVsyncWaiter>(task_runners));
//   };

//   // create a shell with a constant firing vsync waiter.
//   auto platform_task = std::async(std::launch::async, [&]() {
//     fml::MessageLoop::EnsureInitializedForCurrentThread();

//     shell = Shell::Create(
//         task_runners, settings,
//         [vsync_clock, &create_vsync_waiter](Shell& shell) {
//           return ShellTestPlatformView::Create(
//               shell, shell.GetTaskRunners(), vsync_clock,
//               std::move(create_vsync_waiter),
//               ShellTestPlatformView::BackendType::kDefaultBackend, nullptr);
//         },
//         [](Shell& shell) {
//           return std::make_unique<Rasterizer>(
//               shell, shell.GetTaskRunners(),
//               shell.GetIsGpuDisabledSyncSwitch());
//         });
//     ASSERT_TRUE(DartVMRef::IsInstanceRunning());

//     auto configuration = RunConfiguration::InferFromSettings(settings);
//     ASSERT_TRUE(configuration.IsValid());
//     configuration.SetEntrypoint("onBeginFrameMain");

//     RunEngine(shell.get(), std::move(configuration));
//   });
//   platform_task.wait();

//   // schedule a frame to trigger window.onBeginFrame
//   fml::TaskRunner::RunNowOrPostTask(shell->GetTaskRunners().GetUITaskRunner(),
//                                     [engine = shell->GetEngine()]() {
//                                       if (engine) {
//                                         // this implies we can re-use the last
//                                         // frame to trigger begin frame rather
//                                         // than re-generating the layer tree.
//                                         engine->ScheduleFrame(true);
//                                       }
//                                     });

//   // Request frame count 1
//   AnimatorRequestFrame(shell.get(), true);
//   latch.Wait();
//   // Animator did not stop, callback should be triggered once.
//   ASSERT_EQ(on_begin_frame_triggered, 1);
//   fml::AutoResetWaitableEvent destory_platform_view_latch;
//   fml::TaskRunner::RunNowOrPostTask(
//       shell->GetTaskRunners().GetPlatformTaskRunner(), [platform_view = shell->GetPlatformView(), &destory_platform_view_latch]() {
//         platform_view->NotifyDestroyed();
//         destory_platform_view_latch.Signal();
//       });
//   destory_platform_view_latch.Wait();
//   // Request frame count 2
//   AnimatorRequestFrame(shell.get(), true);

//   fml::AutoResetWaitableEvent create_platform_view_latch;
//   fml::TaskRunner::RunNowOrPostTask(
//       shell->GetTaskRunners().GetPlatformTaskRunner(), [platform_view = shell->GetPlatformView(), &create_platform_view_latch]() {
//         // NotifyCreated triggers animator.RequestFrame, so this is request frame count 3.
//         platform_view->NotifyCreated();
//         create_platform_view_latch.Signal();
//       });
//   create_platform_view_latch.Wait();
//   latch.Wait();
//   // Because the request frame count 2 is called after we destroyed the platform view, so we should only get 2 callbacks.
//   ASSERT_EQ(on_begin_frame_triggered, 2);

//   // teardown.
//   DestroyShell(std::move(shell), std::move(task_runners));
//   ASSERT_FALSE(DartVMRef::IsInstanceRunning());
// }

}  // namespace testing
}  // namespace flutter
