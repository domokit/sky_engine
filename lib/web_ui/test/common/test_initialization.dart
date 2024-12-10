// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:js_interop';

import 'package:js/js_util.dart';
import 'package:test/test.dart';
import 'package:ui/src/engine.dart' as engine;
import 'package:ui/src/engine/initialization.dart';
import 'package:ui/ui.dart' as ui;
import 'package:ui/ui_web/src/ui_web.dart' as ui_web;

import 'fake_asset_manager.dart';
import 'rendering.dart';

@JS('window.dartPrint')
external set dartPrint(JSFunction f);

void setUpUnitTests({
  bool withImplicitView = false,
  bool emulateTesterEnvironment = true,
  bool setUpTestViewDimensions = true,
}) {
  late final FakeAssetScope debugFontsScope;
  setUpAll(() async {
    // dartPrint = ((JSAny x) => print(x)).toJS;
    print('<=setUpAll');
    if (emulateTesterEnvironment) {
      ui_web.debugEmulateFlutterTesterEnvironment = true;
    }

    debugFontsScope = configureDebugFontsAssetScope(fakeAssetManager);
    debugOnlyAssetManager = fakeAssetManager;
    // print('  <=await bootstrapAndRunApp(withImplicitView: $withImplicitView);');
    await bootstrapAndRunApp(withImplicitView: withImplicitView);
    // print('  </await bootstrapAndRunApp(withImplicitView: $withImplicitView);');
    engine.debugOverrideJsConfiguration(<String, Object?>{
      'fontFallbackBaseUrl': 'assets/fallback_fonts/',
    }.jsify() as engine.JsFlutterConfiguration?);

    if (setUpTestViewDimensions) {
      // The following parameters are hard-coded in Flutter's test embedder. Since
      // we don't have an embedder yet this is the lowest-most layer we can put
      // this stuff in.
      const double devicePixelRatio = 3.0;
      engine.EngineFlutterDisplay.instance.debugOverrideDevicePixelRatio(devicePixelRatio);
      engine.EnginePlatformDispatcher.instance.implicitView?.debugPhysicalSizeOverride =
          const ui.Size(800 * devicePixelRatio, 600 * devicePixelRatio);
      engine.scheduleFrameCallback = () {};
    }

    setUpRenderingForTests();
    print('</setUpAll');
  });

  tearDownAll(() async {
    fakeAssetManager.popAssetScope(debugFontsScope);
  });
}

Future<void> bootstrapAndRunApp({bool withImplicitView = false}) async {
  final Completer<void> completer = Completer<void>();
  // print('    <=await ui_web.bootstrapEngine();');
  await ui_web.bootstrapEngine(runApp: () => completer.complete());
  // print('    </await ui_web.bootstrapEngine();');
  print('    <=await completer.future;');
  await completer.future;
  print('    </await completer.future;');
  if (!withImplicitView) {
    _disableImplicitView();
  }
}

void _disableImplicitView() {
  // TODO(mdebbar): Instead of disabling the implicit view, we should be able to
  //                initialize tests without an implicit view to begin with.
  //                https://github.com/flutter/flutter/issues/138906
  final engine.EngineFlutterWindow? implicitView = engine.EnginePlatformDispatcher.instance.implicitView;
  if (implicitView != null) {
    engine.EnginePlatformDispatcher.instance.viewManager.disposeAndUnregisterView(implicitView.viewId);
  }
}
