// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_SHELL_PLATFORM_LINUX_FL_TASK_RUNNER_H_
#define FLUTTER_SHELL_PLATFORM_LINUX_FL_TASK_RUNNER_H_

#include <glib-object.h>

#include "flutter/shell/platform/embedder/embedder.h"

G_BEGIN_DECLS

G_DECLARE_FINAL_TYPE(FlTaskRunner, fl_task_runner, FL, TASK_RUNNER, GObject);

typedef void (*FlTaskExecutor)(FlutterTask task, gpointer user_data);

/**
 * fl_task_runner_new
 * @executor: Function responsible for executing fluter tasks.
 * @executor_user_data: user data for executor.
 *
 * Creates new task runner instance.
 *
 * Returns: an #FlTaskRunner.
 */
FlTaskRunner* fl_task_runner_new(FlTaskExecutor executor,
                                 gpointer executor_user_data);

/**
 * fl_task_runner_post_task
 * @task_runner: an #FlTaskRunner.
 * @task: flutter task being scheduled
 * @target_time_nanos: absolute time in nanoseconds
 *
 * Posts a flutter task to be executed on main thread. This function is thread
 * safe and may be called from any thread.
 */
void fl_task_runner_post_task(FlTaskRunner* task_runner,
                              FlutterTask task,
                              uint64_t target_time_nanos);

/**
 * fl_task_runner_stop
 * @task_runner: an #FlTaskRunner.
 *
 * Requests stop. After this method completes no more tasks will be executed
 * by the task runner. Remaining scheduled tasks will be ignored.
 * Must be invoked on main thread.
 */
void fl_task_runner_stop(FlTaskRunner* task_runner);

/**
 * fl_task_runner_block_main_thread
 * @task_runner: an #FlTaskRunner.
 *
 * Blocks main thread until fl_task_runner_release_main_thread is called.
 * While main thread is blocked tasks posted to #FlTaskRunner are executed as
 * usual.
 * Must be invoked on main thread.
 */
void fl_task_runner_block_main_thread(FlTaskRunner* task_runner);

/**
 * fl_task_runner_release_main_thread
 * @task_runner: an #FlTaskRunner.
 *
 * Unblocks main thread. This will resume normal processing of main loop.
 * Can be invoked from any thread.
 */
void fl_task_runner_release_main_thread(FlTaskRunner* self);

G_END_DECLS

#endif  // FLUTTER_SHELL_PLATFORM_LINUX_FL_TASK_RUNNER_H_
