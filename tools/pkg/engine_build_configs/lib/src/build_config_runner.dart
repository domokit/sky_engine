// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io' as io show Directory, Process;

import 'package:path/path.dart' as p;
import 'package:platform/platform.dart';
import 'package:process_runner/process_runner.dart';

import 'build_config.dart';

/// The base clase for events generated by a command.
sealed class RunnerEvent {
  RunnerEvent(this.name, this.command, this.timestamp);

  /// The name of the task or command.
  final String name;

  /// The command and its arguments.
  final List<String> command;

  /// When the event happened.
  final DateTime timestamp;
}

/// A [RunnerEvent] representing the start of a command.
final class RunnerStart extends RunnerEvent {
  RunnerStart(super.name, super.command, super.timestamp);

  @override
  String toString() {
    return '[${_timestamp(timestamp)}][$name]: STARTING';
  }
}

/// A [RunnerEvent] representing the progress of a started command.
final class RunnerProgress extends RunnerEvent {
  RunnerProgress(
    super.name,
    super.command,
    super.timestamp,
    this.what,
    this.completed,
    this.total,
    this.done,
  ) : percent = (completed * 100) / total;

  /// What a command is currently working on, for example a build target or
  /// the name of a test.
  final String what;

  /// The number of steps completed.
  final int completed;

  /// The total number of steps in the task.
  final int total;

  /// How close is the task to being completed, for example the proportion of
  /// build targets that have finished building.
  final double percent;

  /// Whether the command is finished and this is the final progress event.
  final bool done;

  @override
  String toString() {
    final String ts = '[${_timestamp(timestamp)}]';
    final String pct = '${percent.toStringAsFixed(1)}%';
    return '$ts[$name]: $pct ($completed/$total) $what';
  }
}

/// A [RunnerEvent] representing the result of a command.
final class RunnerResult extends RunnerEvent {
  RunnerResult(
    super.name,
    super.command,
    super.timestamp,
    this.result, {
    this.okMessage = 'OK',
  });

  /// The resuilt of running the command.
  final ProcessRunnerResult result;

  /// Whether the command was successful.
  late final bool ok = result.exitCode == 0;

  /// The message to print on a successful result. The default is 'OK'.
  final String okMessage;

  @override
  String toString() {
    if (ok) {
      return '[${_timestamp(timestamp)}][$name]: $okMessage';
    }
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('[$timestamp][$name]: FAILED');
    buffer.writeln('COMMAND:\n${command.join(' ')}');
    buffer.writeln('STDOUT:\n${result.stdout}');
    buffer.writeln('STDERR:\n${result.stderr}');
    return buffer.toString();
  }
}

final class RunnerError extends RunnerEvent {
  RunnerError(super.name, super.command, super.timestamp, this.error);

  /// An error message.
  final String error;

  @override
  String toString() {
    return '[${_timestamp(timestamp)}][$name]: ERROR: $error';
  }
}

/// The type of a callback that handles [RunnerEvent]s while a [Runner]
/// is executing its `run()` method.
typedef RunnerEventHandler = void Function(RunnerEvent);

/// An abstract base clase for running the various tasks that a build config
/// specifies. Derived classes implement the `run()` method.
sealed class Runner {
  Runner(
    this.platform,
    this.processRunner,
    this.abi,
    this.engineSrcDir,
    this.dryRun,
  );

  /// Information about the platform that hosts the runner.
  final Platform platform;

  /// Runs the subprocesses required to run the element of the build config.
  final ProcessRunner processRunner;

  /// The [Abi] of the host platform.
  final ffi.Abi abi;

  /// The src/ directory of the engine checkout.
  final io.Directory engineSrcDir;

  /// Whether only a dry run is required. Subprocesses will not be spawned.
  final bool dryRun;

  /// Uses the [processRunner] to run the commands specified by the build
  /// config.
  Future<bool> run(RunnerEventHandler eventHandler);

  String _interpreter(String language) {
    // Force python to be python3.
    if (language.startsWith('python')) {
      return 'python3';
    }

    // If the language is 'dart', return the Dart binary that is running this
    // program.
    if (language == 'dart') {
      return platform.executable;
    }

    // Otherwise use the language verbatim as the interpreter.
    return language;
  }
}

final ProcessRunnerResult _dryRunResult = ProcessRunnerResult(
  0, // exit code.
  <int>[], // stdout.
  <int>[], // stderr.
  <int>[], // combined,
  pid: 0, // pid,
);

/// The [Runner] for a [Build].
///
/// Runs the specified `gn` and `ninja` commands, followed by generator tasks,
/// and finally tests.
final class BuildRunner extends Runner {
  BuildRunner({
    Platform? platform,
    ProcessRunner? processRunner,
    ffi.Abi? abi,
    required io.Directory engineSrcDir,
    required this.build,
    this.extraGnArgs = const <String>[],
    this.extraNinjaArgs = const <String>[],
    this.extraTestArgs = const <String>[],
    this.runGn = true,
    this.runNinja = true,
    this.runGenerators = true,
    this.runTests = true,
    bool dryRun = false,
  }) : super(
          platform ?? const LocalPlatform(),
          processRunner ?? ProcessRunner(),
          abi ?? ffi.Abi.current(),
          engineSrcDir,
          dryRun,
        );

  /// The [Build] to run.
  final Build build;

  /// Extra arguments to append to the `gn` command.
  final List<String> extraGnArgs;

  /// Extra arguments to append to the `ninja` command.
  final List<String> extraNinjaArgs;

  /// Extra arguments to append to *all* test commands.
  final List<String> extraTestArgs;

  /// Whether to run the GN step. Defaults to true.
  final bool runGn;

  /// Whether to run the ninja step. Defaults to true.
  final bool runNinja;

  /// Whether to run the generators. Defaults to true.
  final bool runGenerators;

  /// Whether to run the test step. Defaults to true.
  final bool runTests;

  @override
  Future<bool> run(RunnerEventHandler eventHandler) async {
    if (!build.canRunOn(platform)) {
      eventHandler(RunnerError(
        build.name,
        <String>[],
        DateTime.now(),
        'Build with drone_dimensions "{${build.droneDimensions.join(',')}}" '
        'cannot run on platform ${platform.operatingSystem}',
      ));
      return false;
    }

    if (runGn) {
      if (!await _runGn(eventHandler)) {
        return false;
      }
    }

    if (runNinja) {
      if (!await _runNinja(eventHandler)) {
        return false;
      }
    }

    if (runGenerators) {
      if (!await _runGenerators(eventHandler)) {
        return false;
      }
    }

    if (runTests) {
      if (!await _runTests(eventHandler)) {
        return false;
      }
    }

    return true;
  }

  // GN arguments from the build config that can be overridden by extraGnArgs.
  static const List<(String, String)> _overridableArgs = <(String, String)>[
    ('--lto', '--no-lto'),
    ('--rbe', '--no-rbe'),
  ];

  // extraGnArgs overrides the build config args.
  late final Set<String> _mergedGnArgs = () {
    // Put the union of the build config args and extraGnArgs in gnArgs.
    final Set<String> gnArgs = Set<String>.of(build.gn);
    gnArgs.addAll(extraGnArgs);

    // If extraGnArgs contains an arg, remove its opposite from gnArgs.
    for (final (String, String) arg in _overridableArgs) {
      if (extraGnArgs.contains(arg.$1)) {
        gnArgs.remove(arg.$2);
      }
      if (extraGnArgs.contains(arg.$2)) {
        gnArgs.remove(arg.$1);
      }
    }
    return gnArgs;
  }();

  Future<bool> _runGn(RunnerEventHandler eventHandler) async {
    final String gnPath = p.join(engineSrcDir.path, 'flutter', 'tools', 'gn');
    final Set<String> gnArgs = _mergedGnArgs;
    final List<String> command = <String>[gnPath, ...gnArgs];
    eventHandler(RunnerStart('${build.name}: GN', command, DateTime.now()));
    final ProcessRunnerResult processResult;
    if (dryRun) {
      processResult = _dryRunResult;
    } else {
      processResult = await processRunner.runProcess(
        command,
        workingDirectory: engineSrcDir,
        failOk: true,
      );
    }
    final RunnerResult result = RunnerResult(
      '${build.name}: GN',
      command,
      DateTime.now(),
      processResult,
    );
    eventHandler(result);
    return result.ok;
  }

  late final String _hostCpu = () {
    return switch (abi) {
      ffi.Abi.linuxArm64 ||
      ffi.Abi.macosArm64 ||
      ffi.Abi.windowsArm64 =>
        'arm64',
      ffi.Abi.linuxX64 || ffi.Abi.macosX64 || ffi.Abi.windowsX64 => 'x64',
      _ => throw StateError('This host platform "$abi" is not supported.'),
    };
  }();

  late final String _buildtoolsPath = () {
    final String os = platform.operatingSystem;
    final String platformDir = switch (os) {
      Platform.linux => 'linux-$_hostCpu',
      Platform.macOS => 'mac-$_hostCpu',
      Platform.windows => 'windows-$_hostCpu',
      _ => throw StateError('This host OS "$os" is not supported.'),
    };
    return p.join(engineSrcDir.path, 'flutter', 'buildtools', platformDir);
  }();

  // Returns the second line of output from reproxystatus, which contains
  // RBE statistics, or null if something goes wrong.
  Future<String?> _reproxystatus() async {
    final String reclientPath = p.join(_buildtoolsPath, 'reclient');
    final String exe = platform.isWindows ? '.exe' : '';
    final String restatsPath = p.join(reclientPath, 'reproxystatus$exe');
    final ProcessRunnerResult restatsResult;
    if (dryRun) {
      restatsResult = ProcessRunnerResult(
        0,                       // exit code.
        utf8.encode('OK\nOK\n'), // stdout.
        <int>[],                 // stderr.
        utf8.encode('OK\nOK\n'), // combined,
        pid: 0,                  // pid.
      );
    } else {
      restatsResult = await processRunner.runProcess(
        <String>[restatsPath, '-color', 'off'],
        failOk: true,
      );
    }
    if (restatsResult.exitCode != 0) {
      return null;
    }
    // The second line of output has the stats.
    final List<String> lines = restatsResult.stdout.split('\n');
    if (lines.length < 2) {
      return null;
    }
    return lines[1];
  }

  Future<bool> _bootstrapRbe(
    RunnerEventHandler eventHandler, {
    bool shutdown = false,
  }) async {
    final String reclientPath = p.join(_buildtoolsPath, 'reclient');
    final String exe = platform.isWindows ? '.exe' : '';
    final String bootstrapPath = p.join(reclientPath, 'bootstrap$exe');
    final String reproxyPath = p.join(reclientPath, 'reproxy$exe');
    final String os = platform.operatingSystem;
    final String reclientConfigFile = switch (os) {
      Platform.linux => 'reclient-linux.cfg',
      Platform.macOS => 'reclient-mac.cfg',
      Platform.windows => 'reclient-win.cfg',
      _ => throw StateError('This host OS "$os" is not supported.'),
    };
    final String reclientConfigPath = p.join(
      engineSrcDir.path,
      'flutter',
      'build',
      'rbe',
      reclientConfigFile,
    );
    final List<String> bootstrapCommand = <String>[
      bootstrapPath,
      '--re_proxy=$reproxyPath',
      '--use_application_default_credentials',
      if (shutdown) '--shutdown' else ...<String>['--cfg=$reclientConfigPath'],
    ];
    if (!processRunner.processManager.canRun(bootstrapPath)) {
      eventHandler(RunnerError(
        build.name,
        <String>[],
        DateTime.now(),
        '"$bootstrapPath" not found.',
      ));
      return false;
    }
    eventHandler(RunnerStart(
      '${build.name}: RBE ${shutdown ? 'shutdown' : 'startup'}',
      bootstrapCommand,
      DateTime.now(),
    ));
    final ProcessRunnerResult bootstrapResult;
    if (dryRun) {
      bootstrapResult = _dryRunResult;
    } else {
      bootstrapResult = await processRunner.runProcess(
        bootstrapCommand,
        failOk: true,
      );
    }
    String okMessage = bootstrapResult.stdout.trim();
    if (shutdown) {
      okMessage = await _reproxystatus() ?? okMessage;
    }
    eventHandler(RunnerResult(
      '${build.name}: RBE ${shutdown ? 'shutdown' : 'startup'}',
      bootstrapCommand,
      DateTime.now(),
      bootstrapResult,
      okMessage: okMessage,
    ));
    return bootstrapResult.exitCode == 0;
  }

  Future<bool> _runNinja(RunnerEventHandler eventHandler) async {
    if (_isRbe) {
      if (!await _bootstrapRbe(eventHandler)) {
        return false;
      }
    }
    bool success = false;
    try {
      final String ninjaPath = p.join(
        engineSrcDir.path,
        'flutter',
        'third_party',
        'ninja',
        'ninja',
      );
      final String outDir = p.join(
        engineSrcDir.path,
        'out',
        build.ninja.config,
      );
      final List<String> command = <String>[
        ninjaPath,
        '-C',
        outDir,
        if (_isRbe) ...<String>['-j', '200'],
        ...extraNinjaArgs,
        ...build.ninja.targets,
      ];
      eventHandler(
        RunnerStart('${build.name}: ninja', command, DateTime.now()),
      );
      final ProcessRunnerResult processResult;
      if (dryRun) {
        processResult = _dryRunResult;
      } else {
        final io.Process process = await processRunner.processManager.start(
          command,
          workingDirectory: engineSrcDir.path,
        );
        final List<int> stderrOutput = <int>[];
        final List<int> stdoutOutput = <int>[];
        final Completer<void> stdoutComplete = Completer<void>();
        final Completer<void> stderrComplete = Completer<void>();

        process.stdout
            .transform<String>(const Utf8Decoder())
            .transform(const LineSplitter())
            .listen(
          (String line) {
            if (_ninjaProgress(eventHandler, command, line)) {
              return;
            }
            final List<int> bytes = utf8.encode('$line\n');
            stdoutOutput.addAll(bytes);
          },
          onDone: () async => stdoutComplete.complete(),
        );

        process.stderr.listen(
          stderrOutput.addAll,
          onDone: () async => stderrComplete.complete(),
        );

        await Future.wait<void>(<Future<void>>[
          stdoutComplete.future,
          stderrComplete.future,
        ]);
        final int exitCode = await process.exitCode;

        processResult = ProcessRunnerResult(
          exitCode,
          stdoutOutput, // stdout.
          stderrOutput, // stderr.
          <int>[], // combined,
          pid: process.pid, // pid,
        );
      }
      eventHandler(RunnerResult(
        '${build.name}: ninja',
        command,
        DateTime.now(),
        processResult,
      ));
      success = processResult.exitCode == 0;
    } finally {
      if (_isRbe) {
        // Ignore failures to shutdown.
        await _bootstrapRbe(eventHandler, shutdown: true);
      }
    }
    return success;
  }

  // Parse lines of the form '[6232/6269] LINK ./accessibility_unittests'.
  // Returns false if the line is not a ninja progress line.
  bool _ninjaProgress(
    RunnerEventHandler eventHandler,
    List<String> command,
    String line,
  ) {
    // Grab the '[6232/6269]' part.
    final String maybeProgress = line.split(' ')[0];
    if (maybeProgress.length < 3 ||
        maybeProgress[0] != '[' ||
        maybeProgress[maybeProgress.length - 1] != ']') {
      return false;
    }
    // Extract the two numbers by stripping the '[' and ']' and splitting on
    // the '/'.
    final List<String> progress =
        maybeProgress.substring(1, maybeProgress.length - 1).split('/');
    if (progress.length < 2) {
      return false;
    }
    final int? completed = int.tryParse(progress[0]);
    final int? total = int.tryParse(progress[1]);
    if (completed == null || total == null) {
      return false;
    }
    eventHandler(RunnerProgress(
      '${build.name}: ninja',
      command,
      DateTime.now(),
      line.replaceFirst(maybeProgress, '').trim(),
      completed,
      total,
      completed == total, // True when done.
    ));
    return true;
  }

  late final bool _isRbe = _mergedGnArgs.contains('--rbe');

  Future<bool> _runGenerators(RunnerEventHandler eventHandler) async {
    for (final BuildTask task in build.generators) {
      final BuildTaskRunner runner = BuildTaskRunner(
        processRunner: processRunner,
        platform: platform,
        abi: abi,
        engineSrcDir: engineSrcDir,
        task: task,
        dryRun: dryRun,
      );
      if (!await runner.run(eventHandler)) {
        return false;
      }
    }
    return true;
  }

  Future<bool> _runTests(RunnerEventHandler eventHandler) async {
    for (final BuildTest test in build.tests) {
      final BuildTestRunner runner = BuildTestRunner(
        processRunner: processRunner,
        platform: platform,
        abi: abi,
        engineSrcDir: engineSrcDir,
        test: test,
        extraTestArgs: extraTestArgs,
        dryRun: dryRun,
      );
      if (!await runner.run(eventHandler)) {
        return false;
      }
    }
    return true;
  }
}

/// The [Runner] for a [BuildTask] of a generator of a [Build].
final class BuildTaskRunner extends Runner {
  BuildTaskRunner({
    Platform? platform,
    ProcessRunner? processRunner,
    ffi.Abi? abi,
    required io.Directory engineSrcDir,
    required this.task,
    bool dryRun = false,
  }) : super(
          platform ?? const LocalPlatform(),
          processRunner ?? ProcessRunner(),
          abi ?? ffi.Abi.current(),
          engineSrcDir,
          dryRun,
        );

  /// The task to run.
  final BuildTask task;

  @override
  Future<bool> run(RunnerEventHandler eventHandler) async {
    final String interpreter = _interpreter(task.language);
    for (final String script in task.scripts) {
      final List<String> command = <String>[
        if (interpreter.isNotEmpty) interpreter,
        script,
        ...task.parameters,
      ];
      eventHandler(RunnerStart(task.name, command, DateTime.now()));
      final ProcessRunnerResult processResult;
      if (dryRun) {
        processResult = _dryRunResult;
      } else {
        processResult = await processRunner.runProcess(
          command,
          workingDirectory: engineSrcDir,
          failOk: true,
        );
      }
      final RunnerResult result = RunnerResult(
        task.name,
        command,
        DateTime.now(),
        processResult,
      );
      eventHandler(result);
      if (!result.ok) {
        return false;
      }
    }
    return true;
  }
}

/// The [Runner] for a [BuildTest] of a [Build].
final class BuildTestRunner extends Runner {
  BuildTestRunner({
    Platform? platform,
    ProcessRunner? processRunner,
    ffi.Abi? abi,
    required io.Directory engineSrcDir,
    required this.test,
    this.extraTestArgs = const <String>[],
    bool dryRun = false,
  }) : super(
          platform ?? const LocalPlatform(),
          processRunner ?? ProcessRunner(),
          abi ?? ffi.Abi.current(),
          engineSrcDir,
          dryRun,
        );

  /// The test to run.
  final BuildTest test;

  /// Extra arguments to append to the test command.
  final List<String> extraTestArgs;

  @override
  Future<bool> run(RunnerEventHandler eventHandler) async {
    final String interpreter = _interpreter(test.language);
    final List<String> command = <String>[
      if (interpreter.isNotEmpty) interpreter,
      test.script,
      ...test.parameters,
      ...extraTestArgs,
    ];
    eventHandler(RunnerStart(test.name, command, DateTime.now()));
    final ProcessRunnerResult processResult;
    if (dryRun) {
      processResult = _dryRunResult;
    } else {
      // TODO(zanderso): We could detect here that we're running e.g. C++ unit
      // tests via run_tests.py, and parse the stdout to generate RunnerProgress
      // events.
      processResult = await processRunner.runProcess(
        command,
        workingDirectory: engineSrcDir,
        failOk: true,
        printOutput: true,
      );
    }
    final RunnerResult result = RunnerResult(
      test.name,
      command,
      DateTime.now(),
      processResult,
    );
    eventHandler(result);
    return result.ok;
  }
}

String _timestamp(DateTime time) {
  String threeDigits(int n) {
    return switch (n) {
      >= 100 => '$n',
      >= 10 => '0$n',
      _ => '00$n',
    };
  }

  String twoDigits(int n) {
    return switch (n) {
      >= 10 => '$n',
      _ => '0$n',
    };
  }

  final String y = time.year.toString();
  final String m = twoDigits(time.month);
  final String d = twoDigits(time.day);
  final String hh = twoDigits(time.hour);
  final String mm = twoDigits(time.minute);
  final String ss = twoDigits(time.second);
  final String ms = threeDigits(time.millisecond);
  return '$y-$m-${d}T$hh:$mm:$ss.$ms${time.isUtc ? 'Z' : ''}';
}
