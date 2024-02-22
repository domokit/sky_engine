// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:litetest/litetest.dart';

int counter = 0;

void main() {
  test('PlatformIsolate isRunningInPlatformThread, false cases', () async {
    final bool isPlatThread =
        await Isolate.run(() => isRunningInPlatformThread());
    expect(isPlatThread, isFalse);
  });

  test('PlatformIsolate runInPlatformThread', () async {
    final bool isPlatThread =
        await runInPlatformThread(() => isRunningInPlatformThread());
    expect(isPlatThread, isTrue);
  });

  test('PlatformIsolate runInPlatformThread, async operations', () async {
    final bool isPlatThread = await runInPlatformThread(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return isRunningInPlatformThread();
    });
    expect(isPlatThread, isTrue);
  });

  test('PlatformIsolate runInPlatformThread, retains state', () async {
    await runInPlatformThread(() => ++counter);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await runInPlatformThread(() => ++counter);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await runInPlatformThread(() => ++counter);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final int counterValue = await runInPlatformThread(() => counter);
    expect(counterValue, 3);
  });

  test('PlatformIsolate runInPlatformThread, concurrent jobs', () async {
    final Future<int> future1 = runInPlatformThread(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return 1;
    });
    final Future<int> future2 = runInPlatformThread(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return 2;
    });
    final Future<int> future3 = runInPlatformThread(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return 3;
    });
    expect(await future1, 1);
    expect(await future2, 2);
    expect(await future3, 3);
  });

  test('PlatformIsolate runInPlatformThread, send and receive messages',
      () async {
    // Send numbers 1 to 10 to the platform isolate. The platform isolate
    // multiplies them by 100 and sends them back.
    int sum = 0;
    final RawReceivePort recvPort = RawReceivePort((Object message) {
      if (message is SendPort) {
        for (int i = 1; i <= 10; ++i) {
          message.send(i);
        }
      } else {
        sum += message as int;
      }
    });
    final SendPort sendPort = recvPort.sendPort;
    await runInPlatformThread(() async {
      final Completer<void> completer = Completer<void>();
      final RawReceivePort recvPort = RawReceivePort((Object message) {
        sendPort.send((message as int) * 100);
        if (message == 10) {
          completer.complete();
        }
      });
      sendPort.send(recvPort.sendPort);
      await completer.future;
      recvPort.close();
    });
    expect(sum, 5500); // sum(1 to 10) * 100
    recvPort.close();
  });

  test('PlatformIsolate runInPlatformThread, throws', () async {
    bool throws = false;
    try {
      await runInPlatformThread(() => throw 'Oh no!');
    } catch (error) {
      expect(error, 'Oh no!');
      throws = true;
    }
    expect(throws, true);
  });

  test('PlatformIsolate runInPlatformThread, async throws', () async {
    bool throws = false;
    try {
      await runInPlatformThread(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        throw 'Oh no!';
      });
    } catch (error) {
      expect(error, 'Oh no!');
      throws = true;
    }
    expect(throws, true);
  });

  test('PlatformIsolate runInPlatformThread, root isolate only', () async {
    await Isolate.run(() {
      expect(() => runInPlatformThread(() => print('Unreachable')), throws);
    });
  });

  test('PlatformIsolate runInPlatformThread, exit disabled', () async {
    await runInPlatformThread(() => expect(() => Isolate.exit(), throws));
  });
}
