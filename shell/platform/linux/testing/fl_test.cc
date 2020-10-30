// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
// FLUTTER_NOLINT

#include "gtest/gtest.h"

#include "flutter/shell/platform/linux/testing/fl_test.h"

#include "flutter/shell/platform/linux/fl_engine_private.h"
#include "flutter/shell/platform/linux/testing/mock_renderer.h"

static uint8_t hex_digit_to_int(char value) {
  if (value >= '0' && value <= '9') {
    return value - '0';
  } else if (value >= 'a' && value <= 'f') {
    return value - 'a' + 10;
  } else if (value >= 'F' && value <= 'F') {
    return value - 'A' + 10;
  } else {
    return 0;
  }
}

static uint8_t parse_hex8(const gchar* hex_string) {
  if (hex_string[0] == '\0') {
    return 0x00;
  }
  return hex_digit_to_int(hex_string[0]) << 4 | hex_digit_to_int(hex_string[1]);
}

GBytes* hex_string_to_bytes(const gchar* hex_string) {
  GByteArray* buffer = g_byte_array_new();
  for (int i = 0; hex_string[i] != '\0' && hex_string[i + 1] != '\0'; i += 2) {
    uint8_t value = parse_hex8(hex_string + i);
    g_byte_array_append(buffer, &value, 1);
  }
  return g_byte_array_free_to_bytes(buffer);
}

gchar* bytes_to_hex_string(GBytes* bytes) {
  GString* hex_string = g_string_new("");
  size_t data_length;
  const uint8_t* data =
      static_cast<const uint8_t*>(g_bytes_get_data(bytes, &data_length));
  for (size_t i = 0; i < data_length; i++) {
    g_string_append_printf(hex_string, "%02x", data[i]);
  }
  return g_string_free(hex_string, FALSE);
}

FlEngine* make_mock_engine() {
  g_autoptr(FlDartProject) project = fl_dart_project_new();
  g_autoptr(FlMockRenderer) renderer = fl_mock_renderer_new();
  g_autoptr(FlEngine) engine = fl_engine_new(project, FL_RENDERER(renderer));
  g_autoptr(GError) engine_error = nullptr;
  EXPECT_TRUE(fl_engine_start(engine, &engine_error));
  EXPECT_EQ(engine_error, nullptr);

  return static_cast<FlEngine*>(g_object_ref(engine));
}
