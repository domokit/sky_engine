// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_SHELL_PLATFORM_ANDROID_PLATFORM_MESSAGE_RESPONSE_ANDROID_H_
#define FLUTTER_SHELL_PLATFORM_ANDROID_PLATFORM_MESSAGE_RESPONSE_ANDROID_H_

#include "flutter/fml/macros.h"
#include "flutter/fml/platform/android/jni_weak_ref.h"
#include "flutter/fml/task_runner.h"
#include "flutter/lib/ui/window/platform_message_response.h"
#include "flutter/shell/platform/android/jni/platform_view_android_jni.h"

namespace flutter {

class PlatformMessageResponseAndroid : public flutter::PlatformMessageResponse {
 public:
  // |flutter::PlatformMessageResponse|
  void Complete(std::unique_ptr<fml::Mapping> data) override;

  // |flutter::PlatformMessageResponse|
  void CompleteEmpty() override;

 private:
  PlatformMessageResponseAndroid(
      int response_id,
      std::unique_ptr<PlatformViewAndroidJni> jni_facade,
      fml::RefPtr<fml::TaskRunner> platform_task_runner);

  ~PlatformMessageResponseAndroid() override;

  int response_id_;
  fml::jni::JavaObjectWeakGlobalRef weak_java_object_;
  std::unique_ptr<PlatformViewAndroidJni> jni_facade_;
  fml::RefPtr<fml::TaskRunner> platform_task_runner_;

  FML_FRIEND_MAKE_REF_COUNTED(PlatformMessageResponseAndroid);
  FML_DISALLOW_COPY_AND_ASSIGN(PlatformMessageResponseAndroid);
};

}  // namespace flutter

#endif  // FLUTTER_SHELL_PLATFORM_ANDROID_PLATFORM_MESSAGE_RESPONSE_ANDROID_H_
