// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_FML_SYNCHRONIZATION_SYNC_SWITCH_H_
#define FLUTTER_FML_SYNCHRONIZATION_SYNC_SWITCH_H_

#include <forward_list>
#include <functional>
#include <mutex>

#include "flutter/fml/macros.h"

namespace fml {

/// A threadsafe structure that allows you to switch between 2 different
/// execution paths.
///
/// Execution and setting the switch is exclusive, i.e. only one will happen
/// at a time.
class SyncSwitch {
 public:
  /// Represents the 2 code paths available when calling |SyncSwitch::Execute|.
  struct Handlers {
    /// Sets the handler that will be executed if the |SyncSwitch| is true.
    Handlers& SetIfTrue(const std::function<void()>& handler);

    /// Sets the handler that will be executed if the |SyncSwitch| is false.
    Handlers& SetIfFalse(const std::function<void()>& handler);

    std::function<void()> true_handler = [] {};
    std::function<void()> false_handler = [] {};
  };

  /// Create a |SyncSwitch| with the specified value.
  ///
  /// @param[in]  value  Default value for the |SyncSwitch|.
  explicit SyncSwitch(bool value = false);

  /// Diverge execution between true and false values of the SyncSwitch.
  ///
  /// This can be called on any thread.  Note that attempting to call
  /// |SetSwitch| inside of the handlers will result in a self deadlock.
  ///
  /// @param[in]  handlers  Called for the correct value of the |SyncSwitch|.
  void Execute(const Handlers& handlers) const;

  /// Set the value of the SyncSwitch.
  ///
  /// This can be called on any thread.
  ///
  /// @param[in]  value  New value for the |SyncSwitch|.
  void SetSwitch(bool value);

#if !FLUTTER_RELEASE
  /// Whether the method |Execute| was executed after |SyncSwitch| is
  /// initialized or |ClearWasExecutedFlag| is called.
  ///
  bool WasExecuted() const;

  /// Clear the flag that the method |Execute| was executed. |WasExecuted|
  /// returns false after |ClearWasExecutedFlag| is called.
  ///
  void ClearWasExecutedFlag() const;
#endif  // FLUTTER_RELEASE

 private:
  mutable std::mutex mutex_;
  bool value_;

#if !FLUTTER_RELEASE
  mutable bool was_executed_flag_ = false;
#endif  // FLUTTER_RELEASE

  FML_DISALLOW_COPY_AND_ASSIGN(SyncSwitch);
};

}  // namespace fml

#endif  // FLUTTER_FML_SYNCHRONIZATION_SYNC_SWITCH_H_
