// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' as html;

import 'package:ui/src/engine.dart';
import 'package:ui/ui.dart' as ui;

import 'package:test/test.dart';

void main() {
  group('Pointer Binding', () {
    html.Element glassPane = domRenderer.glassPaneElement;

    setUp(() {
      // Touching domRenderer creates PointerBinding.instance.
      domRenderer;

      // Set a new detector to reset the state of the listeners.
      PointerBinding.instance.debugOverrideDetector(TestPointerDetector());

      ui.window.onPointerDataPacket = null;
    });

    test('can receive pointer events on the glass pane', () {
      ui.PointerDataPacket receivedPacket;
      ui.window.onPointerDataPacket = (ui.PointerDataPacket packet) {
        receivedPacket = packet;
      };

      glassPane.dispatchEvent(html.PointerEvent('pointerdown', {
        'pointerId': 1,
        'button': 1,
      }));

      expect(receivedPacket, isNotNull);
      expect(receivedPacket.data[0].device, equals(1));
    });

    test('synthesizes a pointerup event on two pointerdowns in a row', () {
      List<ui.PointerDataPacket> packets = <ui.PointerDataPacket>[];
      ui.window.onPointerDataPacket = (ui.PointerDataPacket packet) {
        packets.add(packet);
      };

      glassPane.dispatchEvent(html.PointerEvent('pointerdown', {
        'pointerId': 1,
        'button': 0,
        'buttons': 1,
      }));

      glassPane.dispatchEvent(html.PointerEvent('pointerdown', {
        'pointerId': 1,
        'button': 0,
        'buttons': 1,
      }));

      expect(packets, hasLength(2));
      // An add will be synthesized.
      expect(packets[0].data, hasLength(2));
      expect(packets[0].data[0].change, equals(ui.PointerChange.add));
      expect(packets[0].data[0].synthesized, equals(true));
      expect(packets[0].data[1].change, equals(ui.PointerChange.down));
      expect(packets[1].data[0].change, equals(ui.PointerChange.up));
      expect(packets[1].data[1].change, equals(ui.PointerChange.down));
    });

    test('does not synthesize pointer up if from different device', () {
      List<ui.PointerDataPacket> packets = <ui.PointerDataPacket>[];
      ui.window.onPointerDataPacket = (ui.PointerDataPacket packet) {
        packets.add(packet);
      };

      glassPane.dispatchEvent(html.PointerEvent('pointerdown', {
        'pointerId': 1,
        'button': 0,
        'buttons': 1,
      }));

      glassPane.dispatchEvent(html.PointerEvent('pointerdown', {
        'pointerId': 2,
        'button': 0,
        'buttons': 1,
      }));

      expect(packets, hasLength(2));
      // An add will be synthesized.
      expect(packets[0].data, hasLength(2));
      expect(packets[0].data[0].change, equals(ui.PointerChange.add));
      expect(packets[0].data[0].synthesized, equals(true));
      expect(packets[0].data[0].device, equals(1));
      expect(packets[0].data[1].change, equals(ui.PointerChange.down));
      expect(packets[0].data[1].device, equals(1));
      // An add will be synthesized.
      expect(packets[1].data, hasLength(2));
      expect(packets[1].data[0].change, equals(ui.PointerChange.add));
      expect(packets[1].data[0].synthesized, equals(true));
      expect(packets[1].data[0].device, equals(2));
      expect(packets[1].data[1].change, equals(ui.PointerChange.down));
      expect(packets[1].data[1].device, equals(2));
    });

    test('creates an add event if the first pointer activity is a hover', () {
      List<ui.PointerDataPacket> packets = <ui.PointerDataPacket>[];
      ui.window.onPointerDataPacket = (ui.PointerDataPacket packet) {
        packets.add(packet);
      };

      glassPane.dispatchEvent(html.PointerEvent('pointermove', {
        'pointerId': 1,
        'button': -1,
        'buttons': 0,
      }));

      expect(packets, hasLength(1));
      expect(packets.single.data, hasLength(2));

      expect(packets.single.data[0].change, equals(ui.PointerChange.add));
      expect(packets.single.data[0].synthesized, equals(true));
      expect(packets.single.data[1].change, equals(ui.PointerChange.hover));
    });

    test('does create an add event if got a pointerdown', () {
      List<ui.PointerDataPacket> packets = <ui.PointerDataPacket>[];
      ui.window.onPointerDataPacket = (ui.PointerDataPacket packet) {
        packets.add(packet);
      };

      glassPane.dispatchEvent(html.PointerEvent('pointerdown', {
        'pointerId': 1,
        'button': 0,
        'buttons': 1,
      }));

      expect(packets, hasLength(1));
      expect(packets.single.data, hasLength(2));

      expect(packets.single.data[0].change, equals(ui.PointerChange.add));
      expect(packets.single.data[1].change, equals(ui.PointerChange.down));
    });

    test('does calculate delta and pointer identifier correctly', () {
      List<ui.PointerDataPacket> packets = <ui.PointerDataPacket>[];
      ui.window.onPointerDataPacket = (ui.PointerDataPacket packet) {
        packets.add(packet);
      };

      glassPane.dispatchEvent(html.PointerEvent('pointermove', {
        'pointerId': 1,
        'button': -1,
        'buttons': 0,
        'clientX': 10.0,
        'clientY': 10.0,
      }));

      glassPane.dispatchEvent(html.PointerEvent('pointermove', {
        'pointerId': 1,
        'button': -1,
        'buttons': 0,
        'clientX': 20.0,
        'clientY': 20.0,
      }));

      glassPane.dispatchEvent(html.PointerEvent('pointerdown', {
        'pointerId': 1,
        'button': 0,
        'buttons': 1,
        'clientX': 20.0,
        'clientY': 20.0,
      }));

      glassPane.dispatchEvent(html.PointerEvent('pointermove', {
        'pointerId': 1,
        'button': -1,
        'buttons': 1,
        'clientX': 40.0,
        'clientY': 30.0,
      }));

      glassPane.dispatchEvent(html.PointerEvent('pointerup', {
        'pointerId': 1,
        'button': 0,
        'buttons': 0,
        'clientX': 40.0,
        'clientY': 30.0,
      }));

      glassPane.dispatchEvent(html.PointerEvent('pointermove', {
        'pointerId': 1,
        'button': -1,
        'buttons': 0,
        'clientX': 20.0,
        'clientY': 10.0,
      }));

      glassPane.dispatchEvent(html.PointerEvent('pointerdown', {
        'pointerId': 1,
        'button': 0,
        'buttons': 1,
        'clientX': 20.0,
        'clientY': 10.0,
      }));

      expect(packets, hasLength(7));

      expect(packets[0].data, hasLength(2));
      expect(packets[0].data[0].change, equals(ui.PointerChange.add));
      expect(packets[0].data[0].pointerIdentifier, equals(0));
      expect(packets[0].data[0].synthesized, equals(true));
      expect(packets[0].data[0].physicalX, equals(10.0));
      expect(packets[0].data[0].physicalY, equals(10.0));
      expect(packets[0].data[0].physicalDeltaX, equals(0.0));
      expect(packets[0].data[0].physicalDeltaY, equals(0.0));

      expect(packets[0].data[1].change, equals(ui.PointerChange.hover));
      expect(packets[0].data[1].pointerIdentifier, equals(0));
      expect(packets[0].data[1].synthesized, equals(false));
      expect(packets[0].data[1].physicalX, equals(10.0));
      expect(packets[0].data[1].physicalY, equals(10.0));
      expect(packets[0].data[1].physicalDeltaX, equals(0.0));
      expect(packets[0].data[1].physicalDeltaY, equals(0.0));

      expect(packets[1].data, hasLength(1));
      expect(packets[1].data[0].change, equals(ui.PointerChange.hover));
      expect(packets[1].data[0].pointerIdentifier, equals(0));
      expect(packets[1].data[0].synthesized, equals(false));
      expect(packets[1].data[0].physicalX, equals(20.0));
      expect(packets[1].data[0].physicalY, equals(20.0));
      expect(packets[1].data[0].physicalDeltaX, equals(10.0));
      expect(packets[1].data[0].physicalDeltaY, equals(10.0));

      expect(packets[2].data, hasLength(1));
      expect(packets[2].data[0].change, equals(ui.PointerChange.down));
      expect(packets[2].data[0].pointerIdentifier, equals(1));
      expect(packets[2].data[0].synthesized, equals(false));
      expect(packets[2].data[0].physicalX, equals(20.0));
      expect(packets[2].data[0].physicalY, equals(20.0));
      expect(packets[2].data[0].physicalDeltaX, equals(0.0));
      expect(packets[2].data[0].physicalDeltaY, equals(0.0));

      expect(packets[3].data, hasLength(1));
      expect(packets[3].data[0].change, equals(ui.PointerChange.move));
      expect(packets[3].data[0].pointerIdentifier, equals(1));
      expect(packets[3].data[0].synthesized, equals(false));
      expect(packets[3].data[0].physicalX, equals(40.0));
      expect(packets[3].data[0].physicalY, equals(30.0));
      expect(packets[3].data[0].physicalDeltaX, equals(20.0));
      expect(packets[3].data[0].physicalDeltaY, equals(10.0));

      expect(packets[4].data, hasLength(1));
      expect(packets[4].data[0].change, equals(ui.PointerChange.up));
      expect(packets[4].data[0].pointerIdentifier, equals(1));
      expect(packets[4].data[0].synthesized, equals(false));
      expect(packets[4].data[0].physicalX, equals(40.0));
      expect(packets[4].data[0].physicalY, equals(30.0));
      expect(packets[4].data[0].physicalDeltaX, equals(0.0));
      expect(packets[4].data[0].physicalDeltaY, equals(0.0));

      expect(packets[5].data, hasLength(1));
      expect(packets[5].data[0].change, equals(ui.PointerChange.hover));
      expect(packets[5].data[0].pointerIdentifier, equals(1));
      expect(packets[5].data[0].synthesized, equals(false));
      expect(packets[5].data[0].physicalX, equals(20.0));
      expect(packets[5].data[0].physicalY, equals(10.0));
      expect(packets[5].data[0].physicalDeltaX, equals(-20.0));
      expect(packets[5].data[0].physicalDeltaY, equals(-20.0));

      expect(packets[6].data, hasLength(1));
      expect(packets[6].data[0].change, equals(ui.PointerChange.down));
      expect(packets[6].data[0].pointerIdentifier, equals(2));
      expect(packets[6].data[0].synthesized, equals(false));
      expect(packets[6].data[0].physicalX, equals(20.0));
      expect(packets[6].data[0].physicalY, equals(10.0));
      expect(packets[6].data[0].physicalDeltaX, equals(0.0));
      expect(packets[6].data[0].physicalDeltaY, equals(0.0));
    });

    test('does synthesize add or hover or more for scroll', () {
      List<ui.PointerDataPacket> packets = <ui.PointerDataPacket>[];
      ui.window.onPointerDataPacket = (ui.PointerDataPacket packet) {
        packets.add(packet);
      };

      glassPane.dispatchEvent(html.WheelEvent('wheel',
        button: 1,
        clientX: 10,
        clientY: 10,
        deltaX: 10,
        deltaY: 10,
      ));

      glassPane.dispatchEvent(html.WheelEvent('wheel',
        button: 1,
        clientX: 20,
        clientY: 50,
        deltaX: 10,
        deltaY: 10,
      ));

      glassPane.dispatchEvent(html.PointerEvent('pointerdown', {
        'pointerId': -1,
        'button': 1,
        'clientX': 20.0,
        'clientY': 50.0,
      }));

      glassPane.dispatchEvent(html.WheelEvent('wheel',
        button: 1,
        clientX: 30,
        clientY: 60,
        deltaX: 10,
        deltaY: 10,
      ));

      expect(packets, hasLength(4));

      // An add will be synthesized.
      expect(packets[0].data, hasLength(2));
      expect(packets[0].data[0].change, equals(ui.PointerChange.add));
      expect(packets[0].data[0].pointerIdentifier, equals(0));
      expect(packets[0].data[0].synthesized, equals(true));
      expect(packets[0].data[0].physicalX, equals(10.0));
      expect(packets[0].data[0].physicalY, equals(10.0));
      expect(packets[0].data[0].physicalDeltaX, equals(0.0));
      expect(packets[0].data[0].physicalDeltaY, equals(0.0));

      expect(packets[0].data[1].change, equals(ui.PointerChange.hover));
      expect(packets[0].data[1].signalKind, equals(ui.PointerSignalKind.scroll));
      expect(packets[0].data[1].pointerIdentifier, equals(0));
      expect(packets[0].data[1].synthesized, equals(false));
      expect(packets[0].data[1].physicalX, equals(10.0));
      expect(packets[0].data[1].physicalY, equals(10.0));
      expect(packets[0].data[1].physicalDeltaX, equals(0.0));
      expect(packets[0].data[1].physicalDeltaY, equals(0.0));

      // A hover will be synthesized.
      expect(packets[1].data, hasLength(2));
      expect(packets[1].data[0].change, equals(ui.PointerChange.hover));
      expect(packets[1].data[0].pointerIdentifier, equals(0));
      expect(packets[1].data[0].synthesized, equals(true));
      expect(packets[1].data[0].physicalX, equals(20.0));
      expect(packets[1].data[0].physicalY, equals(50.0));
      expect(packets[1].data[0].physicalDeltaX, equals(10.0));
      expect(packets[1].data[0].physicalDeltaY, equals(40.0));

      expect(packets[1].data[1].change, equals(ui.PointerChange.hover));
      expect(packets[1].data[1].signalKind, equals(ui.PointerSignalKind.scroll));
      expect(packets[1].data[1].pointerIdentifier, equals(0));
      expect(packets[1].data[1].synthesized, equals(false));
      expect(packets[1].data[1].physicalX, equals(20.0));
      expect(packets[1].data[1].physicalY, equals(50.0));
      expect(packets[1].data[1].physicalDeltaX, equals(0.0));
      expect(packets[1].data[1].physicalDeltaY, equals(0.0));

      // No synthetic pointer data for down event.
      expect(packets[2].data, hasLength(1));
      expect(packets[2].data[0].change, equals(ui.PointerChange.down));
      expect(packets[2].data[0].signalKind, equals(null));
      expect(packets[2].data[0].pointerIdentifier, equals(1));
      expect(packets[2].data[0].synthesized, equals(false));
      expect(packets[2].data[0].physicalX, equals(20.0));
      expect(packets[2].data[0].physicalY, equals(50.0));
      expect(packets[2].data[0].physicalDeltaX, equals(0.0));
      expect(packets[2].data[0].physicalDeltaY, equals(0.0));

      // A move will be synthesized instead of hover because the button is currently down.
      expect(packets[3].data, hasLength(2));
      expect(packets[3].data[0].change, equals(ui.PointerChange.move));
      expect(packets[3].data[0].pointerIdentifier, equals(1));
      expect(packets[3].data[0].synthesized, equals(true));
      expect(packets[3].data[0].physicalX, equals(30.0));
      expect(packets[3].data[0].physicalY, equals(60.0));
      expect(packets[3].data[0].physicalDeltaX, equals(10.0));
      expect(packets[3].data[0].physicalDeltaY, equals(10.0));

      expect(packets[3].data[1].change, equals(ui.PointerChange.hover));
      expect(packets[3].data[1].signalKind, equals(ui.PointerSignalKind.scroll));
      expect(packets[3].data[1].pointerIdentifier, equals(1));
      expect(packets[3].data[1].synthesized, equals(false));
      expect(packets[3].data[1].physicalX, equals(30.0));
      expect(packets[3].data[1].physicalY, equals(60.0));
      expect(packets[3].data[1].physicalDeltaX, equals(0.0));
      expect(packets[3].data[1].physicalDeltaY, equals(0.0));
    });

    test('correctly converts buttons of down, move and up events', () {
      List<ui.PointerDataPacket> packets = <ui.PointerDataPacket>[];
      ui.window.onPointerDataPacket = (ui.PointerDataPacket packet) {
        packets.add(packet);
      };

      // Add and hover
      glassPane.dispatchEvent(html.PointerEvent('pointermove', {
        'pointerType': 'mouse',
        'button': -1,
        'buttons': 0,
        'clientX': 10,
        'clientY': 11,
      }));

      expect(packets, hasLength(1));
      expect(packets[0].data, hasLength(2));
      expect(packets[0].data[0].change, equals(ui.PointerChange.add));
      expect(packets[0].data[0].synthesized, equals(true));
      expect(packets[0].data[0].physicalX, equals(10));
      expect(packets[0].data[0].physicalY, equals(11));

      expect(packets[0].data[1].change, equals(ui.PointerChange.hover));
      expect(packets[0].data[1].synthesized, equals(false));
      expect(packets[0].data[1].physicalX, equals(10));
      expect(packets[0].data[1].physicalY, equals(11));
      expect(packets[0].data[1].buttons, equals(0));
      packets.clear();

      // Drag with primary button
      glassPane.dispatchEvent(html.PointerEvent('pointerdown', {
        'pointerType': 'mouse',
        'button': 0,
        'buttons': 1,
        'clientX': 10.0,
        'clientY': 11.0,
      }));
      expect(packets, hasLength(1));
      expect(packets[0].data, hasLength(1));
      expect(packets[0].data[0].change, equals(ui.PointerChange.down));
      expect(packets[0].data[0].synthesized, equals(false));
      expect(packets[0].data[0].physicalX, equals(10));
      expect(packets[0].data[0].physicalY, equals(11));
      expect(packets[0].data[0].buttons, equals(1));
      packets.clear();

      glassPane.dispatchEvent(html.PointerEvent('pointermove', {
        'pointerType': 'mouse',
        'button': -1,
        'buttons': 1,
        'clientX': 20.0,
        'clientY': 21.0,
      }));
      expect(packets, hasLength(1));
      expect(packets[0].data, hasLength(1));
      expect(packets[0].data[0].change, equals(ui.PointerChange.move));
      expect(packets[0].data[0].synthesized, equals(false));
      expect(packets[0].data[0].physicalX, equals(20));
      expect(packets[0].data[0].physicalY, equals(21));
      expect(packets[0].data[0].buttons, equals(1));
      packets.clear();

      glassPane.dispatchEvent(html.PointerEvent('pointerup', {
        'pointerType': 'mouse',
        'button': 0,
        'buttons': 0,
        'clientX': 20.0,
        'clientY': 21.0,
      }));
      expect(packets, hasLength(1));
      expect(packets[0].data, hasLength(1));
      expect(packets[0].data[0].change, equals(ui.PointerChange.up));
      expect(packets[0].data[0].synthesized, equals(false));
      expect(packets[0].data[0].physicalX, equals(20));
      expect(packets[0].data[0].physicalY, equals(21));
      expect(packets[0].data[0].buttons, equals(0));
      packets.clear();

      // Drag with secondary button
      glassPane.dispatchEvent(html.PointerEvent('pointerdown', {
        'pointerType': 'mouse',
        'button': 2,
        'buttons': 2,
        'clientX': 20.0,
        'clientY': 21.0,
      }));
      expect(packets, hasLength(1));
      expect(packets[0].data, hasLength(1));
      expect(packets[0].data[0].change, equals(ui.PointerChange.down));
      expect(packets[0].data[0].synthesized, equals(false));
      expect(packets[0].data[0].physicalX, equals(20));
      expect(packets[0].data[0].physicalY, equals(21));
      expect(packets[0].data[0].buttons, equals(2));
      packets.clear();

      glassPane.dispatchEvent(html.PointerEvent('pointermove', {
        'pointerType': 'mouse',
        'button': -1,
        'buttons': 2,
        'clientX': 30.0,
        'clientY': 31.0,
      }));
      expect(packets, hasLength(1));
      expect(packets[0].data, hasLength(1));
      expect(packets[0].data[0].change, equals(ui.PointerChange.move));
      expect(packets[0].data[0].synthesized, equals(false));
      expect(packets[0].data[0].physicalX, equals(30));
      expect(packets[0].data[0].physicalY, equals(31));
      expect(packets[0].data[0].buttons, equals(2));
      packets.clear();

      glassPane.dispatchEvent(html.PointerEvent('pointerup', {
        'pointerType': 'mouse',
        'button': 2,
        'buttons': 0,
        'clientX': 30.0,
        'clientY': 31.0,
      }));
      expect(packets, hasLength(1));
      expect(packets[0].data, hasLength(1));
      expect(packets[0].data[0].change, equals(ui.PointerChange.up));
      expect(packets[0].data[0].synthesized, equals(false));
      expect(packets[0].data[0].physicalX, equals(30));
      expect(packets[0].data[0].physicalY, equals(31));
      expect(packets[0].data[0].buttons, equals(0));
      packets.clear();

      // Drag with middle button
      glassPane.dispatchEvent(html.PointerEvent('pointerdown', {
        'pointerType': 'mouse',
        'button': 1,
        'buttons': 4,
        'clientX': 30.0,
        'clientY': 31.0,
      }));
      expect(packets, hasLength(1));
      expect(packets[0].data, hasLength(1));
      expect(packets[0].data[0].change, equals(ui.PointerChange.down));
      expect(packets[0].data[0].synthesized, equals(false));
      expect(packets[0].data[0].physicalX, equals(30));
      expect(packets[0].data[0].physicalY, equals(31));
      expect(packets[0].data[0].buttons, equals(4));
      packets.clear();

      glassPane.dispatchEvent(html.PointerEvent('pointermove', {
        'pointerType': 'mouse',
        'button': -1,
        'buttons': 4,
        'clientX': 40.0,
        'clientY': 41.0,
      }));
      expect(packets, hasLength(1));
      expect(packets[0].data, hasLength(1));
      expect(packets[0].data[0].change, equals(ui.PointerChange.move));
      expect(packets[0].data[0].synthesized, equals(false));
      expect(packets[0].data[0].physicalX, equals(40));
      expect(packets[0].data[0].physicalY, equals(41));
      expect(packets[0].data[0].buttons, equals(4));
      packets.clear();

      glassPane.dispatchEvent(html.PointerEvent('pointerup', {
        'pointerType': 'mouse',
        'button': 1,
        'buttons': 0,
        'clientX': 40.0,
        'clientY': 41.0,
      }));
      expect(packets, hasLength(1));
      expect(packets[0].data, hasLength(1));
      expect(packets[0].data[0].change, equals(ui.PointerChange.up));
      expect(packets[0].data[0].synthesized, equals(false));
      expect(packets[0].data[0].physicalX, equals(40));
      expect(packets[0].data[0].physicalY, equals(41));
      expect(packets[0].data[0].buttons, equals(0));
      packets.clear();
    });

    test('correctly handles button changes during a down sequence', () {
      List<ui.PointerDataPacket> packets = <ui.PointerDataPacket>[];
      ui.window.onPointerDataPacket = (ui.PointerDataPacket packet) {
        packets.add(packet);
      };

      // Press LMB.
      glassPane.dispatchEvent(html.PointerEvent('pointerdown', {
        'pointerType': 'mouse',
        'button': 0,
        'buttons': 1,
      }));
      expect(packets, hasLength(1));
      expect(packets[0].data, hasLength(2));
      expect(packets[0].data[0].change, equals(ui.PointerChange.add));
      expect(packets[0].data[0].synthesized, equals(true));

      expect(packets[0].data[1].change, equals(ui.PointerChange.down));
      expect(packets[0].data[1].synthesized, equals(false));
      expect(packets[0].data[1].buttons, equals(1));
      packets.clear();

      // Press MMB.
      glassPane.dispatchEvent(html.PointerEvent('pointermove', {
        'pointerType': 'mouse',
        'button': 1,
        'buttons': 5,
      }));
      expect(packets, hasLength(1));
      expect(packets[0].data, hasLength(1));
      expect(packets[0].data[0].change, equals(ui.PointerChange.move));
      expect(packets[0].data[0].synthesized, equals(false));
      expect(packets[0].data[0].buttons, equals(5));
      packets.clear();

      // Release LMB.
      glassPane.dispatchEvent(html.PointerEvent('pointermove', {
        'pointerType': 'mouse',
        'button': 0,
        'buttons': 4,
      }));
      expect(packets, hasLength(1));
      expect(packets[0].data, hasLength(1));
      expect(packets[0].data[0].change, equals(ui.PointerChange.move));
      expect(packets[0].data[0].synthesized, equals(false));
      expect(packets[0].data[0].buttons, equals(4));
      packets.clear();

      // Release MMB.
      glassPane.dispatchEvent(html.PointerEvent('pointerup', {
        'pointerType': 'mouse',
        'button': 1,
        'buttons': 0,
      }));
      expect(packets, hasLength(1));
      expect(packets[0].data, hasLength(1));
      expect(packets[0].data[0].change, equals(ui.PointerChange.up));
      expect(packets[0].data[0].synthesized, equals(false));
      expect(packets[0].data[0].buttons, equals(0));
      packets.clear();
    });

    test('synthesizes a pointerup event when pointermove comes before the up', () {
      // This can happen when the user pops up the context menu by right
      // clicking, then dismisses it with a left click.

      List<ui.PointerDataPacket> packets = <ui.PointerDataPacket>[];
      ui.window.onPointerDataPacket = (ui.PointerDataPacket packet) {
        packets.add(packet);
      };

      glassPane.dispatchEvent(html.PointerEvent('pointerdown', {
        'pointerId': 1,
        'pointerType': 'mouse',
        'button': 2,
        'buttons': 2,
        'clientX': 10,
        'clientY': 11,
      }));

      expect(packets, hasLength(1));
      expect(packets[0].data, hasLength(2));
      expect(packets[0].data[0].change, equals(ui.PointerChange.add));
      expect(packets[0].data[0].synthesized, equals(true));
      expect(packets[0].data[0].physicalX, equals(10));
      expect(packets[0].data[0].physicalY, equals(11));

      expect(packets[0].data[1].change, equals(ui.PointerChange.down));
      expect(packets[0].data[1].synthesized, equals(false));
      expect(packets[0].data[1].physicalX, equals(10));
      expect(packets[0].data[1].physicalY, equals(11));
      expect(packets[0].data[1].buttons, equals(2));
      packets.clear();

      glassPane.dispatchEvent(html.PointerEvent('pointermove', {
        'pointerId': 1,
        'pointerType': 'mouse',
        'button': -1,
        'buttons': 2,
        'clientX': 20.0,
        'clientY': 21.0,
      }));

      expect(packets, hasLength(1));
      expect(packets[0].data, hasLength(1));
      expect(packets[0].data[0].change, equals(ui.PointerChange.move));
      expect(packets[0].data[0].synthesized, equals(false));
      expect(packets[0].data[0].physicalX, equals(20));
      expect(packets[0].data[0].physicalY, equals(21));
      expect(packets[0].data[0].buttons, equals(2));
      packets.clear();

      glassPane.dispatchEvent(html.PointerEvent('pointermove', {
        'pointerId': 1,
        'pointerType': 'mouse',
        'button': -1,
        'buttons': 2,
        'clientX': 20.0,
        'clientY': 21.0,
      }));

      expect(packets, hasLength(1));
      expect(packets[0].data, hasLength(1));
      expect(packets[0].data[0].change, equals(ui.PointerChange.move));
      expect(packets[0].data[0].synthesized, equals(false));
      expect(packets[0].data[0].physicalX, equals(20));
      expect(packets[0].data[0].physicalY, equals(21));
      expect(packets[0].data[0].buttons, equals(2));
      packets.clear();

      glassPane.dispatchEvent(html.PointerEvent('pointerup', {
        'pointerId': 1,
        'pointerType': 'mouse',
        'button': 2,
        'buttons': 0,
        'clientX': 20.0,
        'clientY': 21.0,
      }));

      expect(packets, hasLength(1));
      expect(packets[0].data, hasLength(1));
      expect(packets[0].data[0].change, equals(ui.PointerChange.up));
      expect(packets[0].data[0].synthesized, equals(false));
      expect(packets[0].data[0].physicalX, equals(20));
      expect(packets[0].data[0].physicalY, equals(21));
      expect(packets[0].data[0].buttons, equals(0));
      packets.clear();
    });

    test('correctly handles uncontinuous button changes during a down sequence', () {
      // This can happen with the following gesture sequence:
      //
      //  - Pops up the context menu by right clicking, but holds RMB;
      //  - Clicks LMB;
      //  - Releases RMB.

      List<ui.PointerDataPacket> packets = <ui.PointerDataPacket>[];
      ui.window.onPointerDataPacket = (ui.PointerDataPacket packet) {
        packets.add(packet);
      };

      // Press RMB and hold, popping up the context menu.
      glassPane.dispatchEvent(html.PointerEvent('pointerdown', {
        'pointerType': 'mouse',
        'button': 2,
        'buttons': 2,
      }));
      expect(packets, hasLength(1));
      expect(packets[0].data, hasLength(2));
      expect(packets[0].data[0].change, equals(ui.PointerChange.add));
      expect(packets[0].data[0].synthesized, equals(true));

      expect(packets[0].data[1].change, equals(ui.PointerChange.down));
      expect(packets[0].data[1].synthesized, equals(false));
      expect(packets[0].data[1].buttons, equals(2));
      packets.clear();

      // Press LMB. The event will have "button: -1" here, despite the change
      // in "buttons", probably because the "press" gesture was absorbed by
      // dismissing the context menu.
      glassPane.dispatchEvent(html.PointerEvent('pointermove', {
        'pointerType': 'mouse',
        'button': -1,
        'buttons': 3,
      }));
      expect(packets, hasLength(1));
      expect(packets[0].data, hasLength(1));
      expect(packets[0].data[0].change, equals(ui.PointerChange.move));
      expect(packets[0].data[0].synthesized, equals(false));
      expect(packets[0].data[0].buttons, equals(3));
      packets.clear();

      // Release LMB.
      glassPane.dispatchEvent(html.PointerEvent('pointermove', {
        'pointerType': 'mouse',
        'button': 0,
        'buttons': 2,
      }));
      expect(packets, hasLength(1));
      expect(packets[0].data, hasLength(1));
      expect(packets[0].data[0].change, equals(ui.PointerChange.move));
      expect(packets[0].data[0].synthesized, equals(false));
      expect(packets[0].data[0].buttons, equals(2));
      packets.clear();

      // Release RMB.
      glassPane.dispatchEvent(html.PointerEvent('pointerup', {
        'pointerType': 'mouse',
        'button': 2,
        'buttons': 0,
      }));
      expect(packets, hasLength(1));
      expect(packets[0].data, hasLength(1));
      expect(packets[0].data[0].change, equals(ui.PointerChange.up));
      expect(packets[0].data[0].synthesized, equals(false));
      expect(packets[0].data[0].buttons, equals(0));
      packets.clear();
    });
  });
}

class TestPointerDetector extends PointerSupportDetector {
  @override
  final bool hasPointerEvents = true;

  @override
  final bool hasTouchEvents = false;

  @override
  final bool hasMouseEvents = false;
}
