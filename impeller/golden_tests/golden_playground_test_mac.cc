// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <dlfcn.h>
#include <filesystem>
#include <memory>

#include "flutter/impeller/golden_tests/golden_playground_test.h"

#include "flutter/impeller/aiks/picture.h"
#include "flutter/impeller/golden_tests/golden_digest.h"
#include "flutter/impeller/golden_tests/metal_screenshotter.h"
#include "flutter/impeller/golden_tests/vulkan_screenshotter.h"
#include "impeller/typographer/backends/skia/typographer_context_skia.h"
#include "impeller/typographer/typographer_context.h"

namespace impeller {

// If you add a new playground test to the aiks unittests and you do not want it
// to also be a golden test, then add the test name here.
static const std::vector<std::string> kSkipTests = {
    "impeller_Play_AiksTest_CanDrawPaintMultipleTimesInteractive_Metal",
    "impeller_Play_AiksTest_CanDrawPaintMultipleTimesInteractive_Vulkan",
    "impeller_Play_AiksTest_CanRenderLinearGradientManyColorsUnevenStops_Metal",
    "impeller_Play_AiksTest_CanRenderLinearGradientManyColorsUnevenStops_"
    "Vulkan",
    "impeller_Play_AiksTest_CanRenderRadialGradient_Metal",
    "impeller_Play_AiksTest_CanRenderRadialGradient_Vulkan",
    "impeller_Play_AiksTest_CanRenderRadialGradientManyColors_Metal",
    "impeller_Play_AiksTest_CanRenderRadialGradientManyColors_Vulkan",
    "impeller_Play_AiksTest_CanRenderBackdropBlurInteractive_Metal",
    "impeller_Play_AiksTest_CanRenderBackdropBlurInteractive_Vulkan",
    "impeller_Play_AiksTest_ClippedBlurFilterRendersCorrectlyInteractive_Metal",
    "impeller_Play_AiksTest_ClippedBlurFilterRendersCorrectlyInteractive_"
    "Vulkan",
    "impeller_Play_AiksTest_CoverageOriginShouldBeAccountedForInSubpasses_"
    "Metal",
    "impeller_Play_AiksTest_CoverageOriginShouldBeAccountedForInSubpasses_"
    "Vulkan",
    "impeller_Play_AiksTest_GaussianBlurRotatedAndClippedInteractive_Metal",
    "impeller_Play_AiksTest_GaussianBlurRotatedAndClippedInteractive_Vulkan",
    "impeller_Play_AiksTest_GradientStrokesRenderCorrectly_Metal",
    "impeller_Play_AiksTest_GradientStrokesRenderCorrectly_Vulkan",
    "impeller_Play_AiksTest_ColorWheel_Metal",
    "impeller_Play_AiksTest_ColorWheel_Vulkan",
    "impeller_Play_AiksTest_SceneColorSource_Metal",
    "impeller_Play_AiksTest_SceneColorSource_Vulkan",
    "impeller_Play_AiksTest_SolidStrokesRenderCorrectly_Metal",
    "impeller_Play_AiksTest_SolidStrokesRenderCorrectly_Vulkan",
    "impeller_Play_AiksTest_TextFrameSubpixelAlignment_Metal",
    "impeller_Play_AiksTest_TextFrameSubpixelAlignment_Vulkan",
    // TextRotated is flakey and we can't seem to get it to stabilize on Skia
    // Gold.
    "impeller_Play_AiksTest_TextRotated_Metal",
    "impeller_Play_AiksTest_TextRotated_Vulkan",
    // Runtime stage based tests get confused with a Metal context.
    "impeller_Play_AiksTest_CanRenderClippedRuntimeEffects_Vulkan",
    "impeller_Play_AiksTest_CaptureContext_Metal",
    "impeller_Play_AiksTest_CaptureContext_Vulkan",
};

namespace {
std::string GetTestName() {
  std::string suite_name =
      ::testing::UnitTest::GetInstance()->current_test_suite()->name();
  std::string test_name =
      ::testing::UnitTest::GetInstance()->current_test_info()->name();
  std::stringstream ss;
  ss << "impeller_" << suite_name << "_" << test_name;
  std::string result = ss.str();
  // Make sure there are no slashes in the test name.
  std::replace(result.begin(), result.end(), '/', '_');
  return result;
}

std::string GetGoldenFilename() {
  return GetTestName() + ".png";
}

bool SaveScreenshot(std::unique_ptr<testing::Screenshot> screenshot) {
  if (!screenshot || !screenshot->GetBytes()) {
    return false;
  }
  std::string test_name = GetTestName();
  std::string filename = GetGoldenFilename();
  testing::GoldenDigest::Instance()->AddImage(
      test_name, filename, screenshot->GetWidth(), screenshot->GetHeight());
  return screenshot->WriteToPNG(
      testing::WorkingDirectory::Instance()->GetFilenamePath(filename));
}
}  // namespace

struct GoldenPlaygroundTest::GoldenPlaygroundTestImpl {
  std::unique_ptr<testing::Screenshotter> screenshotter;
  ISize window_size = ISize{1024, 768};
};

GoldenPlaygroundTest::GoldenPlaygroundTest()
    : typographer_context_(TypographerContextSkia::Make()),
      pimpl_(new GoldenPlaygroundTest::GoldenPlaygroundTestImpl()) {
  if (GetParam() == PlaygroundBackend::kMetal) {
    pimpl_->screenshotter = std::make_unique<testing::MetalScreenshotter>();
  } else if (GetParam() == PlaygroundBackend::kVulkan) {
    pimpl_->screenshotter = std::make_unique<testing::VulkanScreenshotter>();
  }
}

GoldenPlaygroundTest::~GoldenPlaygroundTest() = default;

void GoldenPlaygroundTest::SetTypographerContext(
    std::shared_ptr<TypographerContext> typographer_context) {
  typographer_context_ = std::move(typographer_context);
};

void GoldenPlaygroundTest::TearDown() {
  ASSERT_FALSE(dlopen("/usr/local/lib/libMoltenVK.dylib", RTLD_NOLOAD));
}

void GoldenPlaygroundTest::SetUp() {
  std::filesystem::path testing_assets_path =
      flutter::testing::GetTestingAssetsPath();
  std::filesystem::path target_path = testing_assets_path.parent_path()
                                          .parent_path()
                                          .parent_path()
                                          .parent_path();
  std::filesystem::path icd_path = target_path / "vk_swiftshader_icd.json";
  setenv("VK_ICD_FILENAMES", icd_path.c_str(), 1);

  if (GetBackend() != PlaygroundBackend::kMetal &&
      GetBackend() != PlaygroundBackend::kVulkan) {
    GTEST_SKIP_("GoldenPlaygroundTest doesn't support this backend type.");
    return;
  }

  std::string test_name = GetTestName();
  if (std::find(kSkipTests.begin(), kSkipTests.end(), test_name) !=
      kSkipTests.end()) {
    GTEST_SKIP_(
        "GoldenPlaygroundTest doesn't support interactive playground tests "
        "yet.");
  }

  testing::GoldenDigest::Instance()->AddDimension(
      "gpu_string", GetContext()->DescribeGpuModel());
}

PlaygroundBackend GoldenPlaygroundTest::GetBackend() const {
  return GetParam();
}

bool GoldenPlaygroundTest::OpenPlaygroundHere(Picture picture) {
  AiksContext renderer(GetContext(), typographer_context_);

  auto screenshot = pimpl_->screenshotter->MakeScreenshot(renderer, picture,
                                                          pimpl_->window_size);
  return SaveScreenshot(std::move(screenshot));
}

bool GoldenPlaygroundTest::OpenPlaygroundHere(
    AiksPlaygroundCallback
        callback) {  // NOLINT(performance-unnecessary-value-param)
  AiksContext renderer(GetContext(), typographer_context_);

  std::optional<Picture> picture;
  std::unique_ptr<testing::Screenshot> screenshot;
  for (int i = 0; i < 2; ++i) {
    picture = callback(renderer);
    if (!picture.has_value()) {
      return false;
    }
    screenshot = pimpl_->screenshotter->MakeScreenshot(
        renderer, picture.value(), pimpl_->window_size);
  }

  return SaveScreenshot(std::move(screenshot));
}

std::shared_ptr<Texture> GoldenPlaygroundTest::CreateTextureForFixture(
    const char* fixture_name,
    bool enable_mipmapping) const {
  std::shared_ptr<fml::Mapping> mapping =
      flutter::testing::OpenFixtureAsMapping(fixture_name);
  auto result = Playground::CreateTextureForMapping(GetContext(), mapping,
                                                    enable_mipmapping);
  if (result) {
    result->SetLabel(fixture_name);
  }
  return result;
}

RuntimeStage::Map GoldenPlaygroundTest::OpenAssetAsRuntimeStage(
    const char* asset_name) const {
  const std::shared_ptr<fml::Mapping> fixture =
      flutter::testing::OpenFixtureAsMapping(asset_name);
  if (!fixture || fixture->GetSize() == 0) {
    return {};
  }
  return RuntimeStage::DecodeRuntimeStages(fixture);
}

std::shared_ptr<Context> GoldenPlaygroundTest::GetContext() const {
  return pimpl_->screenshotter->GetPlayground().GetContext();
}

Point GoldenPlaygroundTest::GetContentScale() const {
  return pimpl_->screenshotter->GetPlayground().GetContentScale();
}

Scalar GoldenPlaygroundTest::GetSecondsElapsed() const {
  return 0.0f;
}

ISize GoldenPlaygroundTest::GetWindowSize() const {
  return pimpl_->window_size;
}

void GoldenPlaygroundTest::GoldenPlaygroundTest::SetWindowSize(ISize size) {
  pimpl_->window_size = size;
}

fml::Status GoldenPlaygroundTest::SetCapabilities(
    const std::shared_ptr<Capabilities>& capabilities) {
  return pimpl_->screenshotter->GetPlayground().SetCapabilities(capabilities);
}

}  // namespace impeller
