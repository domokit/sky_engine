// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ffi';
import 'dart:js_interop';

import 'package:ui/src/engine/skwasm/skwasm_impl.dart';

class SkwasmSurface {
  factory SkwasmSurface(String canvasQuerySelector) {
    final SurfaceHandle surfaceHandle = withStackScope((StackScope scope) {
      final Pointer<Int8> pointer = scope.convertStringToNative(canvasQuerySelector);
      return surfaceCreateFromCanvas(pointer);
    });
    final SkwasmSurface surface = SkwasmSurface._fromHandle(surfaceHandle);
    surface._initialize();
    return surface;
  }

  SkwasmSurface._fromHandle(this._handle);
  final SurfaceHandle _handle;
  OnRenderCallbackHandle _callbackHandle = nullptr;
  final Map<int, Completer<void>> _pendingCallbacks = <int, Completer<void>>{};

  void _initialize() {
    _callbackHandle =
      OnRenderCallbackHandle.fromAddress(
        skwasmInstance.addFunction(
          _onRender.toJS,
          'vi'.toJS
        ).toDart.toInt()
      );
    surfaceSetOnRenderCallback(_handle, _callbackHandle);
  }

  void setSize(int width, int height) =>
    surfaceSetCanvasSize(_handle, width, height);

  Future<void> renderPicture(SkwasmPicture picture) {
    final int callbackId = surfaceRenderPicture(_handle, picture.handle);
    final Completer<void> completer = Completer<void>();
    _pendingCallbacks[callbackId] = completer;
    return completer.future;
  }

  void _onRender(JSNumber jsCallbackId) {
    final int callbackId = jsCallbackId.toDart.toInt();
    final Completer<void> completer = _pendingCallbacks.remove(callbackId)!;
    completer.complete();
  }

  void dispose() {
    surfaceDestroy(_handle);
    skwasmInstance.removeFunction(_callbackHandle.address.toJS);
  }
}
