// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: prefer_const_constructors
import 'dart:core';

import 'target.dart';

void main() {
  const Target target1 = Target('1', 1, null);
  final Target target2 = Target('2', 2, const Target('4', 4, null));

  // ignore: unused_local_variable
  final Target target3 = Target('3', 3, Target('5', 5, null)); // should be tree shaken out.
  // ignore: unused_local_variable
  final Target target6 = Target('6', 6, null); // should be tree shaken out.
  target1.hit();
  target2.hit();

  blah(const Target('6', 6, null));

  const IgnoreMe ignoreMe = IgnoreMe(Target('7', 7, null)); // IgnoreMe is ignored but 7 is not.
  print(ignoreMe);
}

class IgnoreMe {
  const IgnoreMe([this.target]);

  final Target target;
}

void blah(Target target) {
  print(target);
}
