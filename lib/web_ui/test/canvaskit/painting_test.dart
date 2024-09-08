// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/bootstrap/browser.dart';
import 'package:test/test.dart';

import 'package:ui/src/engine.dart';

import 'common.dart';

void main() {
  internalBootstrapBrowserTest(() => testMain);
}

void testMain() {
  group('CkPaint', () {
    setUpCanvasKitTest();

    test('toSkPaint', () {
      final paint = CkPaint();

      expect(paint.debugRawSkPaint, isNull);

      final skPaint = paint.toSkPaint();

      expect(skPaint, isNotNull);
      expect(paint.debugRawSkPaint, same(skPaint));

      paint.disposeFrameResources();
      expect(paint.debugRawSkPaint, isNull);
    });

    test('is frame-scoped', () {
      final paint = CkPaint();
      final skPaint1 = paint.toSkPaint();
      final skPaint2 = paint.toSkPaint();

      expect(skPaint1, isNotNull);
      expect(skPaint1, same(skPaint2));

      expect(paint.debugRawSkPaint, same(skPaint1));
      endFrameScope();
      expect(paint.debugRawSkPaint, isNull);
    });
  });
}
