// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:test/bootstrap/browser.dart';
import 'package:test/test.dart';
import 'package:ui/src/engine.dart';
import 'package:ui/ui.dart';

void main() {
  internalBootstrapBrowserTest(() => testMain);
}

Future<void> testMain() async {
  setUpAll(() async {
    await webOnlyInitializePlatform();
    await renderer.fontCollection.debugDownloadTestFonts();
    renderer.fontCollection.registerDownloadedFonts();
  });

  Future<Image> createTestImageByColor(Color color) async {
    final EnginePictureRecorder recorder = EnginePictureRecorder();
    final RecordingCanvas canvas =
        recorder.beginRecording(const Rect.fromLTRB(0, 0, 2, 2));
    canvas.drawColor(color, BlendMode.srcOver);
    final Picture testPicture = recorder.endRecording();
    final Image testImage = await testPicture.toImage(2, 2);
    return testImage;
  }

  Future<Image> testDecodeFromPixels(Uint8List pixels, int width, int height) async {
    final Completer<Image> completer = Completer<Image>();
    decodeImageFromPixels(
      pixels,
      width,
      height,
      PixelFormat.rgba8888,
          (Image image) {
        completer.complete(image);
      },
    );
    return completer.future;
  }

  test('Picture.toImage().toByteData()', () async {
    final Image testImage = await createTestImageByColor(const Color(0xFFCCDD00));

    final ByteData bytes =
        (await testImage.toByteData())!;
    expect(
      bytes.buffer.asUint32List(),
      <int>[0xFF00DDCC, 0xFF00DDCC, 0xFF00DDCC, 0xFF00DDCC],
    );

    final ByteData pngBytes =
        (await testImage.toByteData(format: ImageByteFormat.png))!;

    // PNG-encoding is browser-specific, but the header is standard. We only
    // test the header.
    final List<int> pngHeader = <int>[137, 80, 78, 71, 13, 10, 26, 10];
    expect(
      pngBytes.buffer.asUint8List().sublist(0, pngHeader.length),
      pngHeader,
    );
  });

  test('Image.toByteData(format: ImageByteFormat.rawStraightRgba)', () async {
    final Image testImage = await createTestImageByColor(const Color(0xAAFFFF00));

    final ByteData bytes =
        (await testImage.toByteData(format: ImageByteFormat.rawStraightRgba))!;
    expect(
      bytes.buffer.asUint32List(),
      <int>[0xAA00FFFF, 0xAA00FFFF, 0xAA00FFFF, 0xAA00FFFF],
    );
  });

  test(
      'Image.toByteData(format: ImageByteFormat.rawStraightRgba) returns straight RGBA pixels',
      () async {
    final Uint8List pixels = Uint8List.fromList(<int>[255, 255, 255, 127]);
    final Image testImage = await testDecodeFromPixels(pixels, 1, 1);

    final ByteData bytes =
        (await testImage.toByteData(format: ImageByteFormat.rawStraightRgba))!;
    expect(
      bytes.buffer.asUint8List(),
      <int>[255, 255, 255, 127],
    );
  });

  test(
      'Image.toByteData(format: ImageByteFormat.rawRgba) returns premultiplied RGBA pixels',
      () async {
    final Uint8List pixels = Uint8List.fromList(<int>[255, 255, 255, 127]);
    final Image testImage = await testDecodeFromPixels(pixels, 1, 1);

    final ByteData bytes = (await testImage.toByteData())!;
    expect(
      bytes.buffer.asUint8List(),
      <int>[255 ~/ 2, 255 ~/ 2, 255 ~/ 2, 127],
    );
  });
}
