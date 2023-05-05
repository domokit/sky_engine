// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@JS()
library js_loader;

import 'dart:js_interop';

import 'package:js/js_util.dart' as js_util;

import '../configuration.dart';
import 'js_promise.dart';

@JS()
@staticInterop
class FlutterJS {}

extension FlutterJSExtension on FlutterJS {
  external FlutterLoader? get loader;
}

// Both `flutter`, `loader`(_flutter.loader), must be checked for null before
// `didCreateEngineInitializer` can be safely accessed.
@JS('_flutter')
external FlutterJS? get flutter;

@JS()
@staticInterop
class FlutterLoader {}

extension FlutterLoaderExtension on FlutterLoader {
  external void didCreateEngineInitializer(FlutterEngineInitializer initializer);
  bool get isAutoStart => !js_util.hasProperty(this, 'didCreateEngineInitializer');
}

// FlutterEngineInitializer

/// An object that allows the user to initialize the Engine of a Flutter App.
///
/// As a convenience method, [autoStart] allows the user to immediately initialize
/// and run a Flutter Web app, from JavaScript.
@JS()
@anonymous
@staticInterop
abstract class FlutterEngineInitializer{
  external factory FlutterEngineInitializer({
    required InitializeEngineFn initializeEngine,
    required ImmediateRunAppFn autoStart,
  });
}

/// Typedef for the function that initializes the flutter engine.
///
/// [JsFlutterConfiguration] comes from `../configuration.dart`. It is the same
/// object that can be used to configure flutter "inline", through the
/// (to be deprecated) `window.flutterConfiguration` object.
typedef InitializeEngineFn = Promise<FlutterAppRunner> Function([JsFlutterConfiguration?]);

/// Typedef for the `autoStart` function that can be called straight from an engine initializer instance.
/// (Similar to [RunAppFn], but taking no specific "runApp" parameters).
typedef ImmediateRunAppFn = Promise<FlutterApp> Function();

// FlutterAppRunner

/// A class that exposes a function that runs the Flutter app,
/// and returns a promise of a FlutterAppCleaner.
@JS()
@anonymous
@staticInterop
abstract class FlutterAppRunner {
  /// Runs a flutter app
  external factory FlutterAppRunner({
    required RunAppFn runApp, // Returns an App
  });
}

/// The shape of the object that can be passed as parameter to the
/// runApp function of the FlutterAppRunner object (from JS).
@JS()
@anonymous
@staticInterop
abstract class RunAppFnParameters {
}

/// Typedef for the function that runs the flutter app main entrypoint.
typedef RunAppFn = Promise<FlutterApp> Function([RunAppFnParameters?]);

// FlutterApp

/// A class that exposes the public API of a running Flutter Web App running.
@JS()
@anonymous
@staticInterop
abstract class FlutterApp {
  /// Cleans a Flutter app
  external factory FlutterApp();
}
