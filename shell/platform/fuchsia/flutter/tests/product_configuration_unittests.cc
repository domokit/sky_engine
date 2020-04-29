// Copyright 2020 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <gtest/gtest.h>

#include "flutter/fml/time/time_delta.h"
#include "flutter/shell/platform/fuchsia/flutter/product_configuration.h"

using namespace flutter_runner;

namespace flutter_runner_test {

class ProductConfigurationTest : public testing::Test {};

TEST_F(ProductConfigurationTest, ValidVsyncOffset) {
  const std::string json_string = "{ \"vsync_offset_in_us\" : 9000 } ";
  const fml::TimeDelta expected_offset = fml::TimeDelta::FromMicroseconds(9000);

  ProductConfiguration product_config = ProductConfiguration(json_string);
  EXPECT_EQ(product_config.get_vsync_offset(), expected_offset);
}

TEST_F(ProductConfigurationTest, EmptyJsonString) {
  const std::string json_string = "";
  const fml::TimeDelta expected_offset = fml::TimeDelta::FromMicroseconds(0);

  ProductConfiguration product_config = ProductConfiguration(json_string);
  EXPECT_EQ(product_config.get_vsync_offset(), expected_offset);
}

TEST_F(ProductConfigurationTest, EmptyVsyncOffset) {
  const std::string json_string = "{ \"vsync_offset_in_us\" : } ";
  const fml::TimeDelta expected_offset = fml::TimeDelta::FromMicroseconds(0);

  ProductConfiguration product_config = ProductConfiguration(json_string);
  EXPECT_EQ(product_config.get_vsync_offset(), expected_offset);
}

TEST_F(ProductConfigurationTest, NonIntegerVsyncOffset) {
  const std::string json_string = "{ \"vsync_offset_in_us\" : 3.14159 } ";
  const fml::TimeDelta expected_offset = fml::TimeDelta::FromMicroseconds(0);

  ProductConfiguration product_config = ProductConfiguration(json_string);
  EXPECT_EQ(product_config.get_vsync_offset(), expected_offset);
}

TEST_F(ProductConfigurationTest, NonNumberVsyncOffset) {
  const std::string json_string =
      "{ \"vsync_offset_in_us\" : \"not_an_offset\" } ";
  const fml::TimeDelta expected_offset = fml::TimeDelta::FromMicroseconds(0);

  ProductConfiguration product_config = ProductConfiguration(json_string);
  EXPECT_EQ(product_config.get_vsync_offset(), expected_offset);
}

}  // namespace flutter_runner_test
