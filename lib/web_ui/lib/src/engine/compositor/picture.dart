// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.


part of engine;

class SkPicture implements ui.Picture {
  final js.JsObject? skPicture;
  final ui.Rect? cullRect;

  SkPicture(this.skPicture, this.cullRect);

  @override
  int get approximateBytesUsed => 0;

  @override
  void dispose() {
    // TODO: implement dispose
  }

  @override
  Future<ui.Image> toImage(int width, int height) {
    throw UnsupportedError('SkPicture.toImage not implemented');
  }
}
