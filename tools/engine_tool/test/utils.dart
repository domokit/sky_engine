// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi' as ffi show Abi;
import 'dart:io' as io;

import 'package:engine_repo_tools/engine_repo_tools.dart';
import 'package:engine_tool/src/environment.dart';
import 'package:engine_tool/src/logger.dart';
import 'package:litetest/litetest.dart' show Expect, Matcher;
import 'package:path/path.dart' as path;
import 'package:platform/platform.dart';
import 'package:process_fakes/process_fakes.dart';
import 'package:process_runner/process_runner.dart';

/// Each CannedProcess has a command matcher and the result of an executed
/// process. The matcher is used to determine when to use a registered
/// CannedProcess.
class CannedProcess {
  CannedProcess(
    this.commandMatcher, {
    int exitCode = 0,
    String stdout = '',
    String stderr = '',
  })  : _exitCode = exitCode,
        _stdout = stdout,
        _stderr = stderr;

  final bool Function(List<String> command) commandMatcher;
  final int _exitCode;
  final String _stdout;
  final String _stderr;

  FakeProcess get fakeProcess {
    return FakeProcess(exitCode: _exitCode, stdout: _stdout, stderr: _stderr);
  }
}

/// ExecutedProcess includes the command and the result.
class ExecutedProcess {
  ExecutedProcess(this.command, this.result, this.exitCode);
  final List<String> command;
  final FakeProcess result;
  final int exitCode;

  @override
  String toString() {
    return '${command.join(' ')} exitCode=$exitCode';
  }
}

/// TestEnvironment includes an Environment with some test-specific extras.
class TestEnvironment {
  TestEnvironment(
    Engine engine, {
    Logger? logger,
    ffi.Abi abi = ffi.Abi.macosArm64,
    bool verbose = false,
    this.cannedProcesses = const <CannedProcess>[],
  }) {
    logger ??= Logger.test();
    environment = Environment(
      abi: abi,
      engine: engine,
      platform: FakePlatform(
          operatingSystem: _operatingSystemForAbi(abi),
          resolvedExecutable: io.Platform.resolvedExecutable,
          pathSeparator: _pathSeparatorForAbi(abi)),
      processRunner: ProcessRunner(
          processManager: FakeProcessManager(onStart: (List<String> command) {
        final FakeProcess processResult =
            _getCannedResult(command, cannedProcesses);
        processResult.exitCode.then((int exitCode) {
          processHistory.add(ExecutedProcess(command, processResult, exitCode));
        });
        return processResult;
      }, onRun: (List<String> command) {
        throw UnimplementedError('onRun');
      })),
      logger: logger,
      verbose: verbose,
    );
  }

  factory TestEnvironment.withTestEngine({
    bool withRbe = false,
    ffi.Abi abi = ffi.Abi.linuxX64,
    List<CannedProcess> cannedProcesses = const <CannedProcess>[],
    bool verbose = false,
  }) {
    final io.Directory rootDir = io.Directory.systemTemp.createTempSync('et');
    final TestEngine engine = TestEngine.createTemp(rootDir: rootDir);
    if (withRbe) {
      io.Directory(path.join(
        engine.srcDir.path,
        'flutter',
        'build',
        'rbe',
      )).createSync(recursive: true);
    }
    // When GN runs, always try to create out/host_debug.
    final CannedProcess cannedGn = CannedProcess((List<String> command) {
      if (command[0].endsWith('/gn') && !command.contains('desc')) {
        io.Directory(path.join(
          engine.outDir.path,
          'host_debug',
        )).createSync(recursive: true);
        return true;
      }
      return false;
    });
    final TestEnvironment testEnvironment = TestEnvironment(
      engine,
      abi: abi,
      cannedProcesses: cannedProcesses + <CannedProcess>[cannedGn],
      verbose: verbose,
    );
    return testEnvironment;
  }

  void cleanup() {
    try {
      if (environment.engine is TestEngine) {
        environment.engine.srcDir.parent.deleteSync(recursive: true);
      }
    } catch (_) {
      // Ignore failure to clean up.
    }
  }

  /// Environment.
  late final Environment environment;

  /// List of CannedProcesses that are registered in this environment.
  final List<CannedProcess> cannedProcesses;

  /// A history of all executed processes.
  final List<ExecutedProcess> processHistory = <ExecutedProcess>[];
}

String _operatingSystemForAbi(ffi.Abi abi) {
  switch (abi) {
    case ffi.Abi.linuxArm:
    case ffi.Abi.linuxArm64:
    case ffi.Abi.linuxIA32:
    case ffi.Abi.linuxX64:
    case ffi.Abi.linuxRiscv32:
    case ffi.Abi.linuxRiscv64:
      return Platform.linux;
    case ffi.Abi.macosArm64:
    case ffi.Abi.macosX64:
      return Platform.macOS;
    default:
      throw UnimplementedError('Unhandled abi=$abi');
  }
}

String _pathSeparatorForAbi(ffi.Abi abi) {
  switch (abi) {
    case ffi.Abi.windowsArm64:
    case ffi.Abi.windowsIA32:
    case ffi.Abi.windowsX64:
      return r'\';
    default:
      return '/';
  }
}

FakeProcess _getCannedResult(
    List<String> command, List<CannedProcess> cannedProcesses) {
  for (final CannedProcess cp in cannedProcesses) {
    final bool matched = cp.commandMatcher(command);
    if (matched) {
      return cp.fakeProcess;
    }
  }
  return FakeProcess();
}

typedef CommandMatcher = bool Function(List<String> command);

/// Returns a [Matcher] that fails the test if no process has a matching command.
///
/// Usage:
///    expect(testEnv.processHistory,
///        containsCommand((List<String> command) {
///            return command.length > 5 &&
///                command[0].contains('ninja') &&
///                command[2].endsWith('/host_debug') &&
///                command[5] == 'flutter/fml:fml_arc_unittests';
///        })
///    );
Matcher containsCommand(CommandMatcher commandMatcher) => (dynamic processes) {
      Expect.type<List<ExecutedProcess>>(processes);
      final List<List<String>> commands = (processes as List<ExecutedProcess>)
          .map((ExecutedProcess process) => process.command)
          .toList();
      if (!commands.any(commandMatcher)) {
        Expect.fail('No process found with matching command');
      }
    };

/// Returns a [Matcher] that fails the test if any process has a matching
/// command.
///
/// Usage:
///    expect(testEnv.processHistory,
///        doesNotContainCommand((List<String> command) {
///            return command.length > 5 &&
///                command[0].contains('ninja') &&
///                command[2].endsWith('/host_debug') &&
///                command[5] == 'flutter/fml:fml_arc_unittests';
///        })
///    );
Matcher doesNotContainCommand(CommandMatcher commandMatcher) =>
    (dynamic processes) {
      Expect.type<List<ExecutedProcess>>(processes);
      final List<List<String>> commands = (processes as List<ExecutedProcess>)
          .map((ExecutedProcess process) => process.command)
          .toList();
      if (commands.any(commandMatcher)) {
        Expect.fail('Process found with matching command');
      }
    };
