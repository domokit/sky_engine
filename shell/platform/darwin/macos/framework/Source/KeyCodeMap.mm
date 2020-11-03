// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#include "./KeyCodeMap_internal.h"

// DO NOT EDIT -- DO NOT EDIT -- DO NOT EDIT
// This file is generated by flutter/flutter@dev/tools/gen_keycodes/bin/gen_keycodes.dart and
// should not be edited directly.
//
// Edit the template dev/tools/gen_keycodes/data/keyboard_map_macos_cc.tmpl instead.
// See dev/tools/gen_keycodes/README.md for more information.

/**
 * Mask for the 32-bit value portion of the key code.
 *
 * This is used by platform-specific code to generate Flutter key codes.
 */
const uint64_t kValueMask = 0x000FFFFFFFF;

/**
 * Mask for the platform prefix portion of the key code.
 *
 * This is used by platform-specific code to generate Flutter key codes.
 */
const uint64_t kPlatformMask = 0x0FF00000000;

/**
 * The code prefix for keys which have a Unicode representation.
 *
 * This is used by platform-specific code to generate Flutter key codes.
 */
const uint64_t kUnicodePlane = 0x00000000000;

/**
 * Mask for the auto-generated bit portion of the key code.
 *
 * This is used by platform-specific code to generate new Flutter key codes for
 * keys which are not recognized.
 */
const uint64_t kAutogeneratedMask = 0x10000000000;

/**
 * Mask for the synonym pseudo-keys generated for keys which appear in more than
 * one place on the keyboard.
 *
 * IDs in this range are used to represent keys which appear in multiple places
 * on the keyboard, such as the SHIFT, ALT, CTRL, and numeric keypad keys. These
 * key codes will never be generated by the key event system, but may be used in
 * key maps to represent the union of all the keys of each type in order to
 * match them.
 *
 * To look up the synonyms that are defined, look in the [synonyms] map.
 */
const uint64_t kSynonymMask = 0x20000000000;

/**
 * The code prefix for keys which do not have a Unicode representation.
 *
 * This is used by platform-specific code to generate Flutter key codes using
 * HID Usage codes.
 */
const uint64_t kHidPlane = 0x00100000000;

const NSDictionary* keyCodeToPhysicalKey = @{
  @0x00000000 : @0x00070004,    // keyA
  @0x0000000b : @0x00070005,    // keyB
  @0x00000008 : @0x00070006,    // keyC
  @0x00000002 : @0x00070007,    // keyD
  @0x0000000e : @0x00070008,    // keyE
  @0x00000003 : @0x00070009,    // keyF
  @0x00000005 : @0x0007000a,    // keyG
  @0x00000004 : @0x0007000b,    // keyH
  @0x00000022 : @0x0007000c,    // keyI
  @0x00000026 : @0x0007000d,    // keyJ
  @0x00000028 : @0x0007000e,    // keyK
  @0x00000025 : @0x0007000f,    // keyL
  @0x0000002e : @0x00070010,    // keyM
  @0x0000002d : @0x00070011,    // keyN
  @0x0000001f : @0x00070012,    // keyO
  @0x00000023 : @0x00070013,    // keyP
  @0x0000000c : @0x00070014,    // keyQ
  @0x0000000f : @0x00070015,    // keyR
  @0x00000001 : @0x00070016,    // keyS
  @0x00000011 : @0x00070017,    // keyT
  @0x00000020 : @0x00070018,    // keyU
  @0x00000009 : @0x00070019,    // keyV
  @0x0000000d : @0x0007001a,    // keyW
  @0x00000007 : @0x0007001b,    // keyX
  @0x00000010 : @0x0007001c,    // keyY
  @0x00000006 : @0x0007001d,    // keyZ
  @0x00000012 : @0x0007001e,    // digit1
  @0x00000013 : @0x0007001f,    // digit2
  @0x00000014 : @0x00070020,    // digit3
  @0x00000015 : @0x00070021,    // digit4
  @0x00000017 : @0x00070022,    // digit5
  @0x00000016 : @0x00070023,    // digit6
  @0x0000001a : @0x00070024,    // digit7
  @0x0000001c : @0x00070025,    // digit8
  @0x00000019 : @0x00070026,    // digit9
  @0x0000001d : @0x00070027,    // digit0
  @0x00000024 : @0x00070028,    // enter
  @0x00000035 : @0x00070029,    // escape
  @0x00000033 : @0x0007002a,    // backspace
  @0x00000030 : @0x0007002b,    // tab
  @0x00000031 : @0x0007002c,    // space
  @0x0000001b : @0x0007002d,    // minus
  @0x00000018 : @0x0007002e,    // equal
  @0x00000021 : @0x0007002f,    // bracketLeft
  @0x0000001e : @0x00070030,    // bracketRight
  @0x0000002a : @0x00070031,    // backslash
  @0x00000029 : @0x00070033,    // semicolon
  @0x00000027 : @0x00070034,    // quote
  @0x00000032 : @0x00070035,    // backquote
  @0x0000002b : @0x00070036,    // comma
  @0x0000002f : @0x00070037,    // period
  @0x0000002c : @0x00070038,    // slash
  @0x00000039 : @0x00070039,    // capsLock
  @0x0000007a : @0x0007003a,    // f1
  @0x00000078 : @0x0007003b,    // f2
  @0x00000063 : @0x0007003c,    // f3
  @0x00000076 : @0x0007003d,    // f4
  @0x00000060 : @0x0007003e,    // f5
  @0x00000061 : @0x0007003f,    // f6
  @0x00000062 : @0x00070040,    // f7
  @0x00000064 : @0x00070041,    // f8
  @0x00000065 : @0x00070042,    // f9
  @0x0000006d : @0x00070043,    // f10
  @0x00000067 : @0x00070044,    // f11
  @0x0000006f : @0x00070045,    // f12
  @0x00000072 : @0x00070049,    // insert
  @0x00000073 : @0x0007004a,    // home
  @0x00000074 : @0x0007004b,    // pageUp
  @0x00000075 : @0x0007004c,    // delete
  @0x00000077 : @0x0007004d,    // end
  @0x00000079 : @0x0007004e,    // pageDown
  @0x0000007c : @0x0007004f,    // arrowRight
  @0x0000007b : @0x00070050,    // arrowLeft
  @0x0000007d : @0x00070051,    // arrowDown
  @0x0000007e : @0x00070052,    // arrowUp
  @0x00000047 : @0x00070053,    // numLock
  @0x0000004b : @0x00070054,    // numpadDivide
  @0x00000043 : @0x00070055,    // numpadMultiply
  @0x0000004e : @0x00070056,    // numpadSubtract
  @0x00000045 : @0x00070057,    // numpadAdd
  @0x0000004c : @0x00070058,    // numpadEnter
  @0x00000053 : @0x00070059,    // numpad1
  @0x00000054 : @0x0007005a,    // numpad2
  @0x00000055 : @0x0007005b,    // numpad3
  @0x00000056 : @0x0007005c,    // numpad4
  @0x00000057 : @0x0007005d,    // numpad5
  @0x00000058 : @0x0007005e,    // numpad6
  @0x00000059 : @0x0007005f,    // numpad7
  @0x0000005b : @0x00070060,    // numpad8
  @0x0000005c : @0x00070061,    // numpad9
  @0x00000052 : @0x00070062,    // numpad0
  @0x00000041 : @0x00070063,    // numpadDecimal
  @0x0000000a : @0x00070064,    // intlBackslash
  @0x0000006e : @0x00070065,    // contextMenu
  @0x00000051 : @0x00070067,    // numpadEqual
  @0x00000069 : @0x00070068,    // f13
  @0x0000006b : @0x00070069,    // f14
  @0x00000071 : @0x0007006a,    // f15
  @0x0000006a : @0x0007006b,    // f16
  @0x00000040 : @0x0007006c,    // f17
  @0x0000004f : @0x0007006d,    // f18
  @0x00000050 : @0x0007006e,    // f19
  @0x0000005a : @0x0007006f,    // f20
  @0x0000004a : @0x0007007f,    // audioVolumeMute
  @0x00000048 : @0x00070080,    // audioVolumeUp
  @0x00000049 : @0x00070081,    // audioVolumeDown
  @0x0000005f : @0x00070085,    // numpadComma
  @0x0000005e : @0x00070087,    // intlRo
  @0x0000005d : @0x00070089,    // intlYen
  @0x00000068 : @0x00070090,    // lang1
  @0x00000066 : @0x00070091,    // lang2
  @0x0000003b : @0x000700e0,    // controlLeft
  @0x00000038 : @0x000700e1,    // shiftLeft
  @0x0000003a : @0x000700e2,    // altLeft
  @0x00000037 : @0x000700e3,    // metaLeft
  @0x0000003e : @0x000700e4,    // controlRight
  @0x0000003c : @0x000700e5,    // shiftRight
  @0x0000003d : @0x000700e6,    // altRight
  @0x00000036 : @0x000700e7,    // metaRight
  @0x0000003f : @0x00000012,    // fn
};

const NSDictionary* keyCodeToNumpad = @{
  @0x0000004b : @0x0100070054,    // numpadDivide
  @0x00000043 : @0x0100070055,    // numpadMultiply
  @0x0000004e : @0x0100070056,    // numpadSubtract
  @0x00000045 : @0x0100070057,    // numpadAdd
  @0x00000053 : @0x0100070059,    // numpad1
  @0x00000054 : @0x010007005a,    // numpad2
  @0x00000055 : @0x010007005b,    // numpad3
  @0x00000056 : @0x010007005c,    // numpad4
  @0x00000057 : @0x010007005d,    // numpad5
  @0x00000058 : @0x010007005e,    // numpad6
  @0x00000059 : @0x010007005f,    // numpad7
  @0x0000005b : @0x0100070060,    // numpad8
  @0x0000005c : @0x0100070061,    // numpad9
  @0x00000052 : @0x0100070062,    // numpad0
  @0x00000041 : @0x0100070063,    // numpadDecimal
  @0x00000051 : @0x0100070067,    // numpadEqual
  @0x0000005f : @0x0100070085,    // numpadComma
};

const NSDictionary* keyCodeToFunctionKey = @{
  @0x0000007a : @0x010007003a,    // f1
  @0x00000078 : @0x010007003b,    // f2
  @0x00000063 : @0x010007003c,    // f3
  @0x00000076 : @0x010007003d,    // f4
  @0x00000060 : @0x010007003e,    // f5
  @0x00000061 : @0x010007003f,    // f6
  @0x00000062 : @0x0100070040,    // f7
  @0x00000064 : @0x0100070041,    // f8
  @0x00000065 : @0x0100070042,    // f9
  @0x0000006d : @0x0100070043,    // f10
  @0x00000067 : @0x0100070044,    // f11
  @0x0000006f : @0x0100070045,    // f12
  @0x00000069 : @0x0100070068,    // f13
  @0x0000006b : @0x0100070069,    // f14
  @0x00000071 : @0x010007006a,    // f15
  @0x0000006a : @0x010007006b,    // f16
  @0x00000040 : @0x010007006c,    // f17
  @0x0000004f : @0x010007006d,    // f18
  @0x00000050 : @0x010007006e,    // f19
  @0x0000005a : @0x010007006f,    // f20
};

const NSDictionary* siblingPhysicalKeys = @{
  @0x000700e1 : @0x000700e5, // shift
  @0x000700e5 : @0x000700e1, // shift
  @0x000700e3 : @0x000700e7, // meta
  @0x000700e7 : @0x000700e3, // meta
  @0x000700e2 : @0x000700e6, // alt
  @0x000700e6 : @0x000700e2, // alt
  @0x000700e0 : @0x000700e4, // control
  @0x000700e4 : @0x000700e0, // control
};

const NSDictionary* modiferFlags = @{
  @0x000700e1 : @(NSEventModifierFlagShift),
  @0x000700e5 : @(NSEventModifierFlagShift),
  @0x000700e0 : @(NSEventModifierFlagControl),
  @0x000700e4 : @(NSEventModifierFlagControl),
  @0x000700e2 : @(NSEventModifierFlagOption),
  @0x000700e6 : @(NSEventModifierFlagOption),
  @0x000700e3 : @(NSEventModifierFlagCommand),
  @0x000700e7 : @(NSEventModifierFlagCommand),
};

const uint64_t kCapsLockPhysicalKey = 0x00070039;
