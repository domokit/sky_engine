// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "flutter/shell/platform/common/cpp/client_wrapper/include/flutter/event_channel.h"

#include <memory>
#include <string>

#include "flutter/shell/platform/common/cpp/client_wrapper/include/flutter/binary_messenger.h"
#include "flutter/shell/platform/common/cpp/client_wrapper/include/flutter/event_stream_handler_functions.h"
#include "flutter/shell/platform/common/cpp/client_wrapper/include/flutter/standard_method_codec.h"
#include "gtest/gtest.h"

namespace flutter {

namespace {

class TestBinaryMessenger : public BinaryMessenger {
 public:
  void Send(const std::string& channel,
            const uint8_t* message,
            const size_t message_size,
            BinaryReply reply) const override {}

  void SetMessageHandler(const std::string& channel,
                         BinaryMessageHandler handler) override {
    last_message_handler_channel_ = channel;
    last_message_handler_ = handler;
  }

  std::string last_message_handler_channel() {
    return last_message_handler_channel_;
  }

  BinaryMessageHandler last_message_handler() { return last_message_handler_; }

 private:
  std::string last_message_handler_channel_;
  BinaryMessageHandler last_message_handler_;
};

}  // namespace

// Tests that SetStreamHandler sets a handler that correctly interacts with
// the binary messenger.
TEST(EventChannelTest, Registration) {
  TestBinaryMessenger messenger;
  const std::string channel_name("some_channel");
  const StandardMethodCodec& codec = StandardMethodCodec::GetInstance();
  EventChannel channel(&messenger, channel_name, &codec);

  bool on_listen_called = false;
  auto handler = std::make_unique<
      flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
      [&on_listen_called](
          const flutter::EncodableValue* arguments,
          std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
          -> std::unique_ptr<StreamHandlerError<flutter::EncodableValue>> {
        on_listen_called = true;
        return nullptr;
      },
      [](const flutter::EncodableValue* arguments)
          -> std::unique_ptr<StreamHandlerError<flutter::EncodableValue>> {
        return nullptr;
      });
  channel.SetStreamHandler(std::move(handler));
  EXPECT_EQ(messenger.last_message_handler_channel(), channel_name);
  EXPECT_NE(messenger.last_message_handler(), nullptr);

  // Send dummy listen message.
  MethodCall<flutter::EncodableValue> call("listen", nullptr);
  auto message = codec.EncodeMethodCall(call);
  messenger.last_message_handler()(
      message->data(), message->size(),
      [](const uint8_t* reply, const size_t reply_size) {});

  // Check results.
  EXPECT_EQ(on_listen_called, true);
}

// Tests that SetStreamHandler with a null handler unregisters the handler.
TEST(EventChannelTest, Unregistration) {
  TestBinaryMessenger messenger;
  const std::string channel_name("some_channel");
  const StandardMethodCodec& codec = StandardMethodCodec::GetInstance();
  EventChannel channel(&messenger, channel_name, &codec);

  auto handler = std::make_unique<
      flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
      [](const flutter::EncodableValue* arguments,
         std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
          -> std::unique_ptr<StreamHandlerError<flutter::EncodableValue>> {
        return nullptr;
      },
      [](const flutter::EncodableValue* arguments)
          -> std::unique_ptr<StreamHandlerError<flutter::EncodableValue>> {
        return nullptr;
      });
  channel.SetStreamHandler(std::move(handler));
  EXPECT_EQ(messenger.last_message_handler_channel(), channel_name);
  EXPECT_NE(messenger.last_message_handler(), nullptr);

  channel.SetStreamHandler(nullptr);
  EXPECT_EQ(messenger.last_message_handler_channel(), channel_name);
  EXPECT_EQ(messenger.last_message_handler(), nullptr);
}

// Test that OnCancel callback sequence.
TEST(EventChannelTest, Cancel) {
  TestBinaryMessenger messenger;
  const std::string channel_name("some_channel");
  const StandardMethodCodec& codec = StandardMethodCodec::GetInstance();
  EventChannel channel(&messenger, channel_name, &codec);

  bool on_listen_called = false;
  bool on_cancel_called = false;
  auto handler = std::make_unique<
      flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
      [&on_listen_called](
          const flutter::EncodableValue* arguments,
          std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
          -> std::unique_ptr<StreamHandlerError<flutter::EncodableValue>> {
        on_listen_called = true;
        return nullptr;
      },
      [&on_cancel_called](const flutter::EncodableValue* arguments)
          -> std::unique_ptr<StreamHandlerError<flutter::EncodableValue>> {
        on_cancel_called = true;
        return nullptr;
      });
  channel.SetStreamHandler(std::move(handler));
  EXPECT_EQ(messenger.last_message_handler_channel(), channel_name);
  EXPECT_NE(messenger.last_message_handler(), nullptr);

  // Send dummy listen message.
  MethodCall<flutter::EncodableValue> call_listen("listen", nullptr);
  auto message = codec.EncodeMethodCall(call_listen);
  messenger.last_message_handler()(
      message->data(), message->size(),
      [](const uint8_t* reply, const size_t reply_size) {});
  EXPECT_EQ(on_listen_called, true);

  // Send dummy cancel message.
  MethodCall<flutter::EncodableValue> call_cancel("cancel", nullptr);
  message = codec.EncodeMethodCall(call_cancel);
  messenger.last_message_handler()(
      message->data(), message->size(),
      [](const uint8_t* reply, const size_t reply_size) {});

  // Check results.
  EXPECT_EQ(on_cancel_called, true);
}

// Test that consecutive call of OnListen.
TEST(EventChannelTest, ConsecutiveListen) {
  TestBinaryMessenger messenger;
  const std::string channel_name("some_channel");
  const StandardMethodCodec& codec = StandardMethodCodec::GetInstance();
  EventChannel channel(&messenger, channel_name, &codec);

  bool on_listen_called = false;
  bool on_cancel_called = false;
  auto handler = std::make_unique<
      flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
      [&on_listen_called](
          const flutter::EncodableValue* arguments,
          std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
          -> std::unique_ptr<StreamHandlerError<flutter::EncodableValue>> {
        on_listen_called = true;
        return nullptr;
      },
      [&on_cancel_called](const flutter::EncodableValue* arguments)
          -> std::unique_ptr<StreamHandlerError<flutter::EncodableValue>> {
        on_cancel_called = true;
        return nullptr;
      });
  channel.SetStreamHandler(std::move(handler));
  EXPECT_EQ(messenger.last_message_handler_channel(), channel_name);
  EXPECT_NE(messenger.last_message_handler(), nullptr);

  // Send dummy listen message.
  MethodCall<flutter::EncodableValue> call("listen", nullptr);
  auto message = codec.EncodeMethodCall(call);
  messenger.last_message_handler()(
      message->data(), message->size(),
      [](const uint8_t* reply, const size_t reply_size) {});
  EXPECT_EQ(on_listen_called, true);

  // Send second dummy message to test StreamHandler's OnCancel
  // method is called before OnListen method is called.
  on_listen_called = false;
  message = codec.EncodeMethodCall(call);
  messenger.last_message_handler()(
      message->data(), message->size(),
      [](const uint8_t* reply, const size_t reply_size) {});

  // Check results.
  EXPECT_EQ(on_cancel_called, true);
  EXPECT_EQ(on_listen_called, true);
}

}  // namespace flutter
