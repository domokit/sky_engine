// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_FML_CONCURRENT_MESSAGE_LOOP_H_
#define FLUTTER_FML_CONCURRENT_MESSAGE_LOOP_H_

#include <condition_variable>
#include <map>
#include <queue>
#include <thread>

#include "flutter/fml/closure.h"
#include "flutter/fml/macros.h"
#include "flutter/fml/task_runner.h"

namespace fml {

class ConcurrentTaskRunner;

class ConcurrentMessageLoop {
 public:
  static std::unique_ptr<ConcurrentMessageLoop> Create(
      size_t worker_count = std::thread::hardware_concurrency());

  ~ConcurrentMessageLoop();

  size_t GetWorkerCount() const;

  std::shared_ptr<ConcurrentTaskRunner> GetTaskRunner() { return task_runner_; }

  void Terminate();

  void PostTaskToAllWorkers(const fml::closure& task);

  bool RunsTasksOnCurrentThread();

 private:
  friend ConcurrentTaskRunner;

  size_t worker_count_ = 0;
  std::vector<std::thread> workers_;
  std::mutex tasks_mutex_;
  std::condition_variable tasks_condition_;
  std::queue<fml::closure> tasks_;
  std::vector<std::thread::id> worker_thread_ids_;
  std::map<std::thread::id, std::vector<fml::closure>> thread_tasks_;
  bool shutdown_ = false;
  std::shared_ptr<ConcurrentTaskRunner> task_runner_;

  explicit ConcurrentMessageLoop(size_t worker_count);

  void WorkerMain();

  void PostTask(const fml::closure& task);

  bool HasThreadTasksLocked() const;

  std::vector<fml::closure> GetThreadTasksLocked();

  FML_DISALLOW_COPY_AND_ASSIGN(ConcurrentMessageLoop);
};

class ConcurrentTaskRunner : public BasicTaskRunner {
 public:
  explicit ConcurrentTaskRunner(ConcurrentMessageLoop* weak_loop);

  virtual ~ConcurrentTaskRunner();

  void PostTask(const fml::closure& task) override;

 private:
  friend ConcurrentMessageLoop;

  // Raw pointer that is cleared out in ~ConcurrentMessageLoop.
  ConcurrentMessageLoop* weak_loop_;
  std::mutex weak_loop_mutex_;

  FML_DISALLOW_COPY_AND_ASSIGN(ConcurrentTaskRunner);
};

}  // namespace fml

#endif  // FLUTTER_FML_CONCURRENT_MESSAGE_LOOP_H_
