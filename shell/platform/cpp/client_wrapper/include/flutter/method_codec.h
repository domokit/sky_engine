// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_SHELL_PLATFORM_CPP_CLIENT_WRAPPER_INCLUDE_FLUTTER_METHOD_CODEC_H_
#define FLUTTER_SHELL_PLATFORM_CPP_CLIENT_WRAPPER_INCLUDE_FLUTTER_METHOD_CODEC_H_

#include <memory>
#include <string>
#include <vector>

#include "method_call.h"

namespace flutter {

// Translates between a binary message and higher-level method call and
// response/error objects.
template <typename T>
class MethodCodec {
 public:
  MethodCodec() = default;
  virtual ~MethodCodec() = default;

  // Prevent copying.
  MethodCodec(MethodCodec<T> const &) = delete;
  MethodCodec &operator=(MethodCodec<T> const &) = delete;

  // Returns the MethodCall encoded in |message|, or nullptr if it cannot be
  // decoded.
  // TODO: Consider adding absl as a dependency and using absl::Span.
  std::unique_ptr<MethodCall<T>> DecodeMethodCall(
      const uint8_t *message, const size_t message_size) const {
    return std::move(DecodeMethodCallInternal(message, message_size));
  }

  // Returns a binary encoding of the given |method_call|, or nullptr if the
  // method call cannot be serialized by this codec.
  std::unique_ptr<std::vector<uint8_t>> EncodeMethodCall(
      const MethodCall<T> &method_call) const {
    return std::move(EncodeMethodCallInternal(method_call));
  }

  // Returns a binary encoding of |result|. |result| must be a type supported
  // by the codec.
  std::unique_ptr<std::vector<uint8_t>> EncodeSuccessEnvelope(
      const T *result = nullptr) const {
    return std::move(EncodeSuccessEnvelopeInternal(result));
  }

  // Returns a binary encoding of |error|. The |error_details| must be a type
  // supported by the codec.
  std::unique_ptr<std::vector<uint8_t>> EncodeErrorEnvelope(
      const std::string &error_code, const std::string &error_message = "",
      const T *error_details = nullptr) const {
    return std::move(
        EncodeErrorEnvelopeInternal(error_code, error_message, error_details));
  }

 protected:
  // Implementations of the public interface, to be provided by subclasses.
  virtual std::unique_ptr<MethodCall<T>> DecodeMethodCallInternal(
      const uint8_t *message, const size_t message_size) const = 0;
  virtual std::unique_ptr<std::vector<uint8_t>> EncodeMethodCallInternal(
      const MethodCall<T> &method_call) const = 0;
  virtual std::unique_ptr<std::vector<uint8_t>> EncodeSuccessEnvelopeInternal(
      const T *result) const = 0;
  virtual std::unique_ptr<std::vector<uint8_t>> EncodeErrorEnvelopeInternal(
      const std::string &error_code, const std::string &error_message,
      const T *error_details) const = 0;
};

}  // namespace flutter

#endif  // FLUTTER_SHELL_PLATFORM_CPP_CLIENT_WRAPPER_INCLUDE_FLUTTER_METHOD_CODEC_H_
