// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "flutter/shell/common/animator.h"

#include "flutter/flow/frame_timings.h"
#include "flutter/fml/time/time_point.h"
#include "flutter/fml/trace_event.h"
#include "third_party/dart/runtime/include/dart_tools_api.h"

namespace flutter {

namespace {

// Wait 51 milliseconds (which is 1 more milliseconds than 3 frames at 60hz)
// before notifying the engine that we are idle.  See comments in |BeginFrame|
// for further discussion on why this is necessary.
constexpr fml::TimeDelta kNotifyIdleTaskWaitTime =
    fml::TimeDelta::FromMilliseconds(51);

}  // namespace

Animator::Animator(Delegate& delegate,
                   const TaskRunners& task_runners,
                   std::unique_ptr<VsyncWaiter> waiter)
    : delegate_(delegate),
      task_runners_(task_runners),
      waiter_(std::move(waiter)),
#if SHELL_ENABLE_METAL
      layer_tree_pipeline_(std::make_shared<LayerTreePipeline>(2)),
#else   // SHELL_ENABLE_METAL
      // TODO(dnfield): We should remove this logic and set the pipeline depth
      // back to 2 in this case. See
      // https://github.com/flutter/engine/pull/9132 for discussion.
      layer_tree_pipeline_(std::make_shared<LayerTreePipeline>(
          task_runners.GetPlatformTaskRunner() ==
                  task_runners.GetRasterTaskRunner()
              ? 1
              : 2)),
#endif  // SHELL_ENABLE_METAL
      pending_frame_semaphore_(1),
      weak_factory_(this) {
}

Animator::~Animator() = default;

void Animator::EnqueueTraceFlowId(uint64_t trace_flow_id) {
  fml::TaskRunner::RunNowOrPostTask(
      task_runners_.GetUITaskRunner(),
      [self = weak_factory_.GetWeakPtr(), trace_flow_id] {
        if (!self) {
          return;
        }
        self->trace_flow_ids_.push_back(trace_flow_id);
        self->ScheduleMaybeClearTraceFlowIds();
      });
}

static fml::TimePoint FxlToDartOrEarlier(fml::TimePoint time) {
  auto dart_now = fml::TimeDelta::FromMicroseconds(Dart_TimelineGetMicros());
  fml::TimePoint fxl_now = fml::TimePoint::Now();
  return fml::TimePoint::FromEpochDelta(time - fxl_now + dart_now);
}

void Animator::BeginFrame(
    std::unique_ptr<FrameTimingsRecorder> frame_timings_recorder) {
  TRACE_EVENT_ASYNC_END0("flutter", "Frame Request Pending",
                         frame_request_number_);
  frame_request_number_++;

  frame_timings_recorder_ = std::move(frame_timings_recorder);
  frame_timings_recorder_->RecordBuildStart(fml::TimePoint::Now());

  TRACE_EVENT_WITH_FRAME_NUMBER(frame_timings_recorder_, "flutter",
                                "Animator::BeginFrame");
  while (!trace_flow_ids_.empty()) {
    uint64_t trace_flow_id = trace_flow_ids_.front();
    TRACE_FLOW_END("flutter", "PointerEvent", trace_flow_id);
    trace_flow_ids_.pop_front();
  }

  frame_scheduled_ = false;
  notify_idle_task_id_++;
  regenerate_layer_tree_ = false;
  pending_frame_semaphore_.Signal();

  if (!producer_continuation_) {
    // We may already have a valid pipeline continuation in case a previous
    // begin frame did not result in an Animation::Render. Simply reuse that
    // instead of asking the pipeline for a fresh continuation.
    producer_continuation_ = layer_tree_pipeline_->Produce();

    if (!producer_continuation_) {
      // If we still don't have valid continuation, the pipeline is currently
      // full because the consumer is being too slow. Try again at the next
      // frame interval.
      TRACE_EVENT0("flutter", "PipelineFull");
      RequestFrame();
      return;
    }
  }

  // We have acquired a valid continuation from the pipeline and are ready
  // to service potential frame.
  FML_DCHECK(producer_continuation_);
  fml::tracing::TraceEventAsyncComplete(
      "flutter", "VsyncSchedulingOverhead",
      frame_timings_recorder_->GetVsyncStartTime(),
      frame_timings_recorder_->GetBuildStartTime());
  const fml::TimePoint frame_target_time =
      frame_timings_recorder_->GetVsyncTargetTime();
  dart_frame_deadline_ = FxlToDartOrEarlier(frame_target_time);
  uint64_t frame_number = frame_timings_recorder_->GetFrameNumber();
  delegate_.OnAnimatorBeginFrame(frame_target_time, frame_number);

  if (!frame_scheduled_ && has_rendered_) {
    // Under certain workloads (such as our parent view resizing us, which is
    // communicated to us by repeat viewport metrics events), we won't
    // actually have a frame scheduled yet, despite the fact that we *will* be
    // producing a frame next vsync (it will be scheduled once we receive the
    // viewport event).  Because of this, we hold off on calling
    // |OnAnimatorNotifyIdle| for a little bit, as that could cause garbage
    // collection to trigger at a highly undesirable time.
    task_runners_.GetUITaskRunner()->PostDelayedTask(
        [self = weak_factory_.GetWeakPtr(),
         notify_idle_task_id = notify_idle_task_id_]() {
          if (!self) {
            return;
          }
          // If our (this task's) task id is the same as the current one
          // (meaning there were no follow up frames to the |BeginFrame| call
          // that posted this task) and no frame is currently scheduled, then
          // assume that we are idle, and notify the engine of this.
          if (notify_idle_task_id == self->notify_idle_task_id_ &&
              !self->frame_scheduled_) {
            TRACE_EVENT0("flutter", "BeginFrame idle callback");
            self->delegate_.OnAnimatorNotifyIdle(
                FxlToDartOrEarlier(fml::TimePoint::Now() +
                                   fml::TimeDelta::FromMicroseconds(100000)));
          }
        },
        kNotifyIdleTaskWaitTime);
  }
}

void Animator::Render(std::shared_ptr<flutter::LayerTree> layer_tree) {
  has_rendered_ = true;
  last_layer_tree_size_ = layer_tree->frame_size();

  if (!frame_timings_recorder_) {
    // Framework can directly call render with a built scene.
    frame_timings_recorder_ = std::make_unique<FrameTimingsRecorder>();
    const fml::TimePoint placeholder_time = fml::TimePoint::Now();
    frame_timings_recorder_->RecordVsync(placeholder_time, placeholder_time);
    frame_timings_recorder_->RecordBuildStart(placeholder_time);
  }

  TRACE_EVENT_WITH_FRAME_NUMBER(frame_timings_recorder_, "flutter",
                                "Animator::Render");
  frame_timings_recorder_->RecordBuildEnd(fml::TimePoint::Now());

  delegate_.OnAnimatorUpdateLatestFrameTargetTime(
      frame_timings_recorder_->GetVsyncTargetTime());

  auto layer_tree_item = std::make_unique<LayerTreeItem>(
      std::move(layer_tree), std::move(frame_timings_recorder_));
  // Commit the pending continuation.
  PipelineProduceResult result =
      producer_continuation_.Complete(std::move(layer_tree_item));

  if (!result.success) {
    FML_DLOG(INFO) << "No pending continuation to commit";
    return;
  }

  if (!result.is_first_item) {
    // It has been successfully pushed to the pipeline but not as the first
    // item. Eventually the 'Rasterizer' will consume it, so we don't need to
    // notify the delegate.
    return;
  }

  delegate_.OnAnimatorDraw(layer_tree_pipeline_);
}

const std::weak_ptr<VsyncWaiter> Animator::GetVsyncWaiter() const {
  std::weak_ptr<VsyncWaiter> weak = waiter_;
  return weak;
}

bool Animator::CanReuseLastLayerTree() {
  return !regenerate_layer_tree_;
}

void Animator::DrawLastLayerTree(
    std::unique_ptr<FrameTimingsRecorder> frame_timings_recorder) {
  pending_frame_semaphore_.Signal();
  // In this case BeginFrame doesn't get called, we need to
  // adjust frame timings to update build start and end times,
  // given that the frame doesn't get built in this case, we
  // will use Now() for both start and end times as an indication.
  const auto now = fml::TimePoint::Now();
  frame_timings_recorder->RecordBuildStart(now);
  frame_timings_recorder->RecordBuildEnd(now);
  delegate_.OnAnimatorDrawLastLayerTree(std::move(frame_timings_recorder));
}

void Animator::RequestFrame(
    bool regenerate_layer_tree,
    std::optional<fml::TimePoint> force_directly_call_next_vsync_target_time) {
  if (regenerate_layer_tree) {
    regenerate_layer_tree_ = true;
  }

  // when want to directly call, should *cancel* previous pending call and
  // schedule again instead of skip scheduling
  if (!force_directly_call_next_vsync_target_time.has_value() &&
      pending_await_vsync_id_.load().has_value()) {
    // Multiple calls to Animator::RequestFrame will still result in a
    // single request to the VsyncWaiter.
    return;
  }
  // TODO this is not atomic with above
  // when [pending_await_vsync_id_] is not null, this will effectively
  // cancel the previous one
  int curr_await_vsync_id = next_await_vsync_id_++;
  pending_await_vsync_id_ = curr_await_vsync_id;

  // The AwaitVSync is going to call us back at the next VSync. However, we want
  // to be reasonably certain that the UI thread is not in the middle of a
  // particularly expensive callout. We post the AwaitVSync to run right after
  // an idle. This does NOT provide a guarantee that the UI thread has not
  // started an expensive operation right after posting this message however.
  // To support that, we need edge triggered wakes on VSync.

  task_runners_.GetUITaskRunner()->PostTask(
      [self = weak_factory_.GetWeakPtr(),
       force_directly_call_next_vsync_target_time, curr_await_vsync_id,
       frame_request_number = frame_request_number_]() {
        if (!self) {
          return;
        }
        TRACE_EVENT_ASYNC_BEGIN0("flutter", "Frame Request Pending",
                                 frame_request_number);
        self->AwaitVSync(force_directly_call_next_vsync_target_time,
                         curr_await_vsync_id);
      });
  frame_scheduled_ = true;
}

void Animator::AwaitVSync(
    std::optional<fml::TimePoint> force_directly_call_next_vsync_target_time,
    int curr_await_vsync_id) {
  // (hacky) implementation in the runnable prototype can be seen in:
  // https://github.com/fzyzcjy/engine/blob/7e646656db8ac82d8436942e9f8e738999b0bdc4/shell/common/animator.cc#L371
  // that one works well in the prototype, but is too hacky
  // I will reimplement it if this PR looks acceptable
  bool should_directly_call =
      force_directly_call_next_vsync_target_time.has_value() || TODO;

  auto callback =
      [self = weak_factory_.GetWeakPtr()](
          std::unique_ptr<FrameTimingsRecorder> frame_timings_recorder) {
        if (self) {
          if (self->CanReuseLastLayerTree()) {
            self->DrawLastLayerTree(std::move(frame_timings_recorder));
          } else {
            self->BeginFrame(std::move(frame_timings_recorder));
          }
        }
      };

  if (should_directly_call) {
    // again, the original code is runnable but hacky
    const fml::TimePoint next_vsync_target_time =
        force_directly_call_next_vsync_target_time.value_or(TODO);
    // mimic how [Animator::Render] fills the recorder
    std::unique_ptr<FrameTimingsRecorder> frame_timings_recorder =
        std::make_unique<FrameTimingsRecorder>();
    frame_timings_recorder->RecordVsync(
        next_vsync_target_time - ONE_FRAME_DURATION, next_vsync_target_time);

    callback(std::move(frame_timings_recorder));
  } else {
    waiter_->AsyncWaitForVsync(callback);
  }

  if (has_rendered_) {
    delegate_.OnAnimatorNotifyIdle(dart_frame_deadline_);
  }
}

void Animator::ScheduleSecondaryVsyncCallback(uintptr_t id,
                                              const fml::closure& callback) {
  waiter_->ScheduleSecondaryCallback(id, callback);
}

void Animator::ScheduleMaybeClearTraceFlowIds() {
  waiter_->ScheduleSecondaryCallback(
      reinterpret_cast<uintptr_t>(this), [self = weak_factory_.GetWeakPtr()] {
        if (!self) {
          return;
        }
        if (!self->frame_scheduled_ && !self->trace_flow_ids_.empty()) {
          TRACE_EVENT0("flutter",
                       "Animator::ScheduleMaybeClearTraceFlowIds - callback");
          while (!self->trace_flow_ids_.empty()) {
            auto flow_id = self->trace_flow_ids_.front();
            TRACE_FLOW_END("flutter", "PointerEvent", flow_id);
            self->trace_flow_ids_.pop_front();
          }
        }
      });
}

}  // namespace flutter
