// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_LIB_UI_WINDOW_PLATFORM_CONFIGURATION_H_
#define FLUTTER_LIB_UI_WINDOW_PLATFORM_CONFIGURATION_H_

#include <memory>
#include <set>
#include <string>
#include <unordered_map>
#include <vector>

#include "flutter/fml/time/time_point.h"
#include "flutter/lib/ui/semantics/semantics_update.h"
#include "flutter/lib/ui/window/platform_message.h"
#include "flutter/lib/ui/window/pointer_data_packet.h"
#include "flutter/lib/ui/window/viewport_metrics.h"
#include "flutter/lib/ui/window/window.h"
#include "third_party/tonic/dart_persistent_value.h"

namespace tonic {
class DartLibraryNatives;

// So tonic::ToDart<std::vector<int64_t>> returns List<int> instead of
// List<dynamic>.
template <>
struct DartListFactory<int64_t> {
  static Dart_Handle NewList(intptr_t length) {
    return Dart_NewListOf(Dart_CoreType_Int, length);
  }
};

}  // namespace tonic

namespace flutter {
class FontCollection;
class PlatformMessage;
class Scene;

// Must match the AccessibilityFeatureFlag enum in framework.
enum class AccessibilityFeatureFlag : int32_t {
  kAccessibleNavigation = 1 << 0,
  kInvertColors = 1 << 1,
  kDisableAnimations = 1 << 2,
  kBoldText = 1 << 3,
  kReduceMotion = 1 << 4,
  kHighContrast = 1 << 5,
};

class PlatformConfigurationClient {
 public:
  virtual std::string DefaultRouteName() = 0;
  virtual void ScheduleFrame() = 0;
  virtual void Render(Scene* scene) = 0;
  virtual void UpdateSemantics(SemanticsUpdate* update) = 0;
  virtual void HandlePlatformMessage(fml::RefPtr<PlatformMessage> message) = 0;
  virtual FontCollection& GetFontCollection() = 0;
  virtual void UpdateIsolateDescription(const std::string isolate_name,
                                        int64_t isolate_port) = 0;
  virtual void SetNeedsReportTimings(bool value) = 0;
  virtual std::shared_ptr<const fml::Mapping> GetPersistentIsolateData() = 0;
  virtual std::unique_ptr<std::vector<std::string>>
  ComputePlatformResolvedLocale(
      const std::vector<std::string>& supported_locale_data) = 0;

 protected:
  virtual ~PlatformConfigurationClient();
};

class PlatformConfiguration final {
 public:
  explicit PlatformConfiguration(PlatformConfigurationClient* client);

  ~PlatformConfiguration();

  PlatformConfigurationClient* client() const { return client_; }

  void DidCreateIsolate();
  void UpdateLocales(const std::vector<std::string>& locales);
  void UpdateUserSettingsData(const std::string& data);
  void UpdateLifecycleState(const std::string& data);
  void UpdateSemanticsEnabled(bool enabled);
  void UpdateAccessibilityFeatures(int32_t flags);
  void DispatchPlatformMessage(fml::RefPtr<PlatformMessage> message);
  void DispatchPointerDataPacket(const PointerDataPacket& packet);
  void DispatchSemanticsAction(int32_t id,
                               SemanticsAction action,
                               std::vector<uint8_t> args);
  void BeginFrame(fml::TimePoint frameTime);
  void ReportTimings(std::vector<int64_t> timings);

  void CompletePlatformMessageResponse(int response_id,
                                       std::vector<uint8_t> data);
  void CompletePlatformMessageEmptyResponse(int response_id);

  static void RegisterNatives(tonic::DartLibraryNatives* natives);

  //----------------------------------------------------------------------------
  /// @brief Retrieves the Window.
  ///
  /// @return the Window.
  const Window& window() const { return *window_; }

  //----------------------------------------------------------------------------
  /// @brief Sets the viewport metrics of the Window.
  ///
  /// @param[in] window_metrics The viewport metrics to replace the old ones
  ///            with.
  void SetWindowMetrics(const ViewportMetrics& window_metrics);

 private:
  PlatformConfigurationClient* client_;
  tonic::DartPersistentValue library_;

  std::unique_ptr<Window> window_;

  // We use id 0 to mean that no response is expected.
  int next_response_id_ = 1;
  std::unordered_map<int, fml::RefPtr<PlatformMessageResponse>>
      pending_responses_;
};

}  // namespace flutter

#endif  // FLUTTER_LIB_UI_WINDOW_PLATFORM_CONFIGURATION_H_
