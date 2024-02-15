// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi' as ffi show Abi;

import 'package:engine_repo_tools/engine_repo_tools.dart';
import 'package:platform/platform.dart';
import 'package:process_runner/process_runner.dart';

/// This class encapsulates information about the host system.
///
/// Rather than being written directly against `dart:io`, implementations in the
/// tool should only access the system by way of the abstractions in this class.
/// This is so that unit tests can be hermetic by providing fake
/// implementations.
final class Environment {
  /// Constructs the environment.
  Environment({
    required this.abi,
    required this.engine,
    required this.platform,
    required this.processRunner,
    required this.stderr,
    required this.stdout,
  });

  /// The host OS and architecture that the tool is running on.
  final ffi.Abi abi;

  /// Information about paths in the engine repo.
  final Engine engine;

  /// More detailed information about the host platform.
  final Platform platform;

  /// Facility for commands to run subprocesses.
  final ProcessRunner processRunner;

  // TODO(zanderso): Replace stderr and stdout with a real logger.

  /// A sink for error messages from commands.
  final StringSink stderr;

  /// A sink for non-error messages from commands.
  final StringSink stdout;
}
