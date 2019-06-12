// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "flutter/flow/embedded_views.h"

namespace flutter {

bool ExternalViewEmbedder::SubmitFrame(GrContext* context) {
  return false;
};

void MutatorsStack::pushClipRect(const SkRect& rect) {
  std::unique_ptr<Mutator> element = std::make_unique<Mutator>(rect);
  vector_.push_back(std::move(element));
};

void MutatorsStack::pushClipRRect(const SkRRect& rrect) {
  std::unique_ptr<Mutator> element = std::make_unique<Mutator>(rrect);
  vector_.push_back(std::move(element));
};

void MutatorsStack::pushTransform(const SkMatrix& matrix) {
  std::unique_ptr<Mutator> element = std::make_unique<Mutator>(matrix);
  vector_.push_back(std::move(element));
};

void MutatorsStack::pop() {
  vector_.pop_back();
};

const std::vector<std::unique_ptr<Mutator>>::const_reverse_iterator MutatorsStack::top() const {
  return vector_.rend();
};

const std::vector<std::unique_ptr<Mutator>>::const_reverse_iterator MutatorsStack::bottom()
    const {
  return vector_.rbegin();
};

}  // namespace flutter
