// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_IMPELLER_TOOLKIT_INTEROP_BACKEND_METAL_CONTEXT_MTL_H_
#define FLUTTER_IMPELLER_TOOLKIT_INTEROP_BACKEND_METAL_CONTEXT_MTL_H_

#include "impeller/toolkit/interop/context.h"

namespace impeller::interop {

class ContextMTL final : public Context {
 public:
  static ScopedObject<Context> Create();

  static ScopedObject<Context> Create(
      std::shared_ptr<impeller::Context> context);

  // |Context|
  ~ContextMTL() override;

  ContextMTL(const ContextMTL&) = delete;

  ContextMTL& operator=(const ContextMTL&) = delete;

 private:
  explicit ContextMTL(std::shared_ptr<impeller::Context> context);
};

}  // namespace impeller::interop

#endif  // FLUTTER_IMPELLER_TOOLKIT_INTEROP_BACKEND_METAL_CONTEXT_MTL_H_
