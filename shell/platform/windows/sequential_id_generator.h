// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#pragma once

#include <cstdint>
#include <unordered_map>

#include "flutter/fml/macros.h"

namespace flutter {

// This is used to generate a series of sequential ID numbers in a way that a
// new ID is always the lowest possible ID in the sequence.
//
// based on
// https://source.chromium.org/chromium/chromium/src/+/main:ui/gfx/sequential_id_generator.h
class SequentialIdGenerator {
 public:
  // Creates a new generator with the specified lower bound and uppoer bound for
  // the IDs.
  explicit SequentialIdGenerator(uint32_t min_id, uint32_t max_id);
  ~SequentialIdGenerator();

  // Generates a unique ID to represent |number|. The generated ID is the
  // smallest available ID greater than or equal to the |min_id| specified
  // during creation of the generator.
  uint32_t GetGeneratedId(uint32_t number);

  // Checks to see if the generator currently has a unique ID generated for
  // |number|.
  bool HasGeneratedIdFor(uint32_t number) const;

  // Removes the ID previously generated for |number| by calling
  // |GetGeneratedID()| - does nothing if the number is not mapped.
  void ReleaseNumber(uint32_t number);

  // Releases ID previously generated by calling |GetGeneratedID()|. Does
  // nothing if the ID is not mapped.
  void ReleaseId(uint32_t id);

 private:
  typedef std::unordered_map<uint32_t, uint32_t> IdMap;

  uint32_t GetNextAvailableId();

  void UpdateNextAvailableIdAfterRelease(uint32_t id);

  IdMap number_to_id_;
  IdMap id_to_number_;

  const uint32_t min_id_;
  const uint32_t max_id_;
  uint32_t min_available_id_;

  FML_DISALLOW_COPY_AND_ASSIGN(SequentialIdGenerator);
};

}  // namespace flutter
