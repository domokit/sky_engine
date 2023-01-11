// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_SHELL_PLATFORM_COMMON_ALERT_PLATFORM_NODE_DELEGATE_H_
#define FLUTTER_SHELL_PLATFORM_COMMON_ALERT_PLATFORM_NODE_DELEGATE_H_

#include "flutter/third_party/accessibility/ax/ax_node_data.h"
#include "flutter/third_party/accessibility/ax/platform/ax_platform_node_delegate_base.h"

namespace flutter {

class AlertPlatformNodeDelegate : public ui::AXPlatformNodeDelegateBase {
 public:
  explicit AlertPlatformNodeDelegate(
      ui::AXPlatformNodeDelegate* parent_delegate);
  ~AlertPlatformNodeDelegate();

  AlertPlatformNodeDelegate(const AlertPlatformNodeDelegate& other) = delete;
  AlertPlatformNodeDelegate operator=(const AlertPlatformNodeDelegate& other) =
      delete;

  void SetText(const std::u16string& text);

  // |AXPlatformNodeDelegate|
  gfx::NativeViewAccessible GetParent() override;

 private:
  // AXPlatformNodeDelegate overrides.
  gfx::AcceleratedWidget GetTargetForNativeAccessibilityEvent() override;
  const ui::AXUniqueId& GetUniqueId() const override;
  const ui::AXNodeData& GetData() const override;

  ui::AXPlatformNodeDelegate* parent_delegate_;
  ui::AXNodeData data_;
  ui::AXUniqueId id_;
};

}  // namespace flutter

#endif  // FLUTTER_SHELL_PLATFORM_COMMON_ALERT_PLATFORM_NODE_DELEGATE_H_
