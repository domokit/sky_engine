// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#pragma once

#include <memory>

#include "flutter/fml/macros.h"
#include "impeller/entity/contents.h"
#include "impeller/renderer/texture.h"

namespace impeller {

class CanvasPassDelegate {
 public:
  static std::unique_ptr<CanvasPassDelegate> MakeDefault();

  CanvasPassDelegate();

  virtual ~CanvasPassDelegate();

  virtual bool CanCollapseIntoParentPass() = 0;

  virtual std::shared_ptr<Contents> CreateContentsForSubpassTarget(
      const Texture& target) = 0;

 private:
  FML_DISALLOW_COPY_AND_ASSIGN(CanvasPassDelegate);
};

}  // namespace impeller
