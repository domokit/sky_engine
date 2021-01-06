// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_SHELL_PLATFORM_WINDOWS_FLUTTER_KEY_MAP_H_
#define FLUTTER_SHELL_PLATFORM_WINDOWS_FLUTTER_KEY_MAP_H_

#include "flutter/shell/platform/windows/flutter_keyboard_manager.h"

#include <map>

// DO NOT EDIT -- DO NOT EDIT -- DO NOT EDIT
// This file is generated by flutter/flutter@dev/tools/gen_keycodes/bin/gen_keycodes.dart and
// should not be edited directly.
//
// Edit the template dev/tools/gen_keycodes/data/windows_flutter_key_map_cc.tmpl instead.
// See dev/tools/gen_keycodes/README.md for more information.

namespace flutter {

std::map<uint64_t, uint64_t> FlutterKeyboardManager::windowsToPhysicalMap_ = {
  { 0x0000e05f, 0x00010082 },    // sleep
  { 0x0000e063, 0x00010083 },    // wakeUp
  { 0x000000ff, 0x00070001 },    // usbErrorRollOver
  { 0x000000fc, 0x00070002 },    // usbPostFail
  { 0x0000001e, 0x00070004 },    // keyA
  { 0x00000030, 0x00070005 },    // keyB
  { 0x0000002e, 0x00070006 },    // keyC
  { 0x00000020, 0x00070007 },    // keyD
  { 0x00000012, 0x00070008 },    // keyE
  { 0x00000021, 0x00070009 },    // keyF
  { 0x00000022, 0x0007000a },    // keyG
  { 0x00000023, 0x0007000b },    // keyH
  { 0x00000017, 0x0007000c },    // keyI
  { 0x00000024, 0x0007000d },    // keyJ
  { 0x00000025, 0x0007000e },    // keyK
  { 0x00000026, 0x0007000f },    // keyL
  { 0x00000032, 0x00070010 },    // keyM
  { 0x00000031, 0x00070011 },    // keyN
  { 0x00000018, 0x00070012 },    // keyO
  { 0x00000019, 0x00070013 },    // keyP
  { 0x00000010, 0x00070014 },    // keyQ
  { 0x00000013, 0x00070015 },    // keyR
  { 0x0000001f, 0x00070016 },    // keyS
  { 0x00000014, 0x00070017 },    // keyT
  { 0x00000016, 0x00070018 },    // keyU
  { 0x0000002f, 0x00070019 },    // keyV
  { 0x00000011, 0x0007001a },    // keyW
  { 0x0000002d, 0x0007001b },    // keyX
  { 0x00000015, 0x0007001c },    // keyY
  { 0x0000002c, 0x0007001d },    // keyZ
  { 0x00000002, 0x0007001e },    // digit1
  { 0x00000003, 0x0007001f },    // digit2
  { 0x00000004, 0x00070020 },    // digit3
  { 0x00000005, 0x00070021 },    // digit4
  { 0x00000006, 0x00070022 },    // digit5
  { 0x00000007, 0x00070023 },    // digit6
  { 0x00000008, 0x00070024 },    // digit7
  { 0x00000009, 0x00070025 },    // digit8
  { 0x0000000a, 0x00070026 },    // digit9
  { 0x0000000b, 0x00070027 },    // digit0
  { 0x0000001c, 0x00070028 },    // enter
  { 0x00000001, 0x00070029 },    // escape
  { 0x0000000e, 0x0007002a },    // backspace
  { 0x0000000f, 0x0007002b },    // tab
  { 0x00000039, 0x0007002c },    // space
  { 0x0000000c, 0x0007002d },    // minus
  { 0x0000000d, 0x0007002e },    // equal
  { 0x0000001a, 0x0007002f },    // bracketLeft
  { 0x0000001b, 0x00070030 },    // bracketRight
  { 0x0000002b, 0x00070031 },    // backslash
  { 0x00000027, 0x00070033 },    // semicolon
  { 0x00000028, 0x00070034 },    // quote
  { 0x00000029, 0x00070035 },    // backquote
  { 0x00000033, 0x00070036 },    // comma
  { 0x00000034, 0x00070037 },    // period
  { 0x00000035, 0x00070038 },    // slash
  { 0x0000003a, 0x00070039 },    // capsLock
  { 0x0000003b, 0x0007003a },    // f1
  { 0x0000003c, 0x0007003b },    // f2
  { 0x0000003d, 0x0007003c },    // f3
  { 0x0000003e, 0x0007003d },    // f4
  { 0x0000003f, 0x0007003e },    // f5
  { 0x00000040, 0x0007003f },    // f6
  { 0x00000041, 0x00070040 },    // f7
  { 0x00000042, 0x00070041 },    // f8
  { 0x00000043, 0x00070042 },    // f9
  { 0x00000044, 0x00070043 },    // f10
  { 0x00000057, 0x00070044 },    // f11
  { 0x00000058, 0x00070045 },    // f12
  { 0x0000e037, 0x00070046 },    // printScreen
  { 0x00000046, 0x00070047 },    // scrollLock
  { 0x00000045, 0x00070048 },    // pause
  { 0x0000e052, 0x00070049 },    // insert
  { 0x0000e047, 0x0007004a },    // home
  { 0x0000e049, 0x0007004b },    // pageUp
  { 0x0000e053, 0x0007004c },    // delete
  { 0x0000e04f, 0x0007004d },    // end
  { 0x0000e051, 0x0007004e },    // pageDown
  { 0x0000e04d, 0x0007004f },    // arrowRight
  { 0x0000e04b, 0x00070050 },    // arrowLeft
  { 0x0000e050, 0x00070051 },    // arrowDown
  { 0x0000e048, 0x00070052 },    // arrowUp
  { 0x0000e045, 0x00070053 },    // numLock
  { 0x0000e035, 0x00070054 },    // numpadDivide
  { 0x00000037, 0x00070055 },    // numpadMultiply
  { 0x0000004a, 0x00070056 },    // numpadSubtract
  { 0x0000004e, 0x00070057 },    // numpadAdd
  { 0x0000e01c, 0x00070058 },    // numpadEnter
  { 0x0000004f, 0x00070059 },    // numpad1
  { 0x00000050, 0x0007005a },    // numpad2
  { 0x00000051, 0x0007005b },    // numpad3
  { 0x0000004b, 0x0007005c },    // numpad4
  { 0x0000004c, 0x0007005d },    // numpad5
  { 0x0000004d, 0x0007005e },    // numpad6
  { 0x00000047, 0x0007005f },    // numpad7
  { 0x00000048, 0x00070060 },    // numpad8
  { 0x00000049, 0x00070061 },    // numpad9
  { 0x00000052, 0x00070062 },    // numpad0
  { 0x00000053, 0x00070063 },    // numpadDecimal
  { 0x00000056, 0x00070064 },    // intlBackslash
  { 0x0000e05d, 0x00070065 },    // contextMenu
  { 0x0000e05e, 0x00070066 },    // power
  { 0x00000059, 0x00070067 },    // numpadEqual
  { 0x00000064, 0x00070068 },    // f13
  { 0x00000065, 0x00070069 },    // f14
  { 0x00000066, 0x0007006a },    // f15
  { 0x00000067, 0x0007006b },    // f16
  { 0x00000068, 0x0007006c },    // f17
  { 0x00000069, 0x0007006d },    // f18
  { 0x0000006a, 0x0007006e },    // f19
  { 0x0000006b, 0x0007006f },    // f20
  { 0x0000006c, 0x00070070 },    // f21
  { 0x0000006d, 0x00070071 },    // f22
  { 0x0000006e, 0x00070072 },    // f23
  { 0x00000076, 0x00070073 },    // f24
  { 0x0000e03b, 0x00070075 },    // help
  { 0x0000e008, 0x0007007a },    // undo
  { 0x0000e017, 0x0007007b },    // cut
  { 0x0000e018, 0x0007007c },    // copy
  { 0x0000e00a, 0x0007007d },    // paste
  { 0x0000e020, 0x0007007f },    // audioVolumeMute
  { 0x0000e030, 0x00070080 },    // audioVolumeUp
  { 0x0000e02e, 0x00070081 },    // audioVolumeDown
  { 0x0000007e, 0x00070085 },    // numpadComma
  { 0x00000073, 0x00070087 },    // intlRo
  { 0x00000070, 0x00070088 },    // kanaMode
  { 0x0000007d, 0x00070089 },    // intlYen
  { 0x00000079, 0x0007008a },    // convert
  { 0x0000007b, 0x0007008b },    // nonConvert
  { 0x00000072, 0x00070090 },    // lang1
  { 0x00000071, 0x00070091 },    // lang2
  { 0x00000078, 0x00070092 },    // lang3
  { 0x00000077, 0x00070093 },    // lang4
  { 0x0000001d, 0x000700e0 },    // controlLeft
  { 0x0000002a, 0x000700e1 },    // shiftLeft
  { 0x00000038, 0x000700e2 },    // altLeft
  { 0x0000e05b, 0x000700e3 },    // metaLeft
  { 0x0000e01d, 0x000700e4 },    // controlRight
  { 0x00000036, 0x000700e5 },    // shiftRight
  { 0x0000e038, 0x000700e6 },    // altRight
  { 0x0000e05c, 0x000700e7 },    // metaRight
  { 0x0000e019, 0x000c00b5 },    // mediaTrackNext
  { 0x0000e010, 0x000c00b6 },    // mediaTrackPrevious
  { 0x0000e024, 0x000c00b7 },    // mediaStop
  { 0x0000e02c, 0x000c00b8 },    // eject
  { 0x0000e022, 0x000c00cd },    // mediaPlayPause
  { 0x0000e06d, 0x000c0183 },    // mediaSelect
  { 0x0000e06c, 0x000c018a },    // launchMail
  { 0x0000e021, 0x000c0192 },    // launchApp2
  { 0x0000e06b, 0x000c0194 },    // launchApp1
  { 0x0000e065, 0x000c0221 },    // browserSearch
  { 0x0000e032, 0x000c0223 },    // browserHome
  { 0x0000e06a, 0x000c0224 },    // browserBack
  { 0x0000e069, 0x000c0225 },    // browserForward
  { 0x0000e068, 0x000c0226 },    // browserStop
  { 0x0000e067, 0x000c0227 },    // browserRefresh
  { 0x0000e066, 0x000c022a },    // browserFavorites
};

std::map<uint64_t, uint64_t> FlutterKeyboardManager::windowsToLogicalMap_ = {
  { 0x00000008, 0x00000000008 },    // BACK
  { 0x00000009, 0x00000000009 },    // TAB
  { 0x0000000d, 0x0000000000d },    // RETURN
  { 0x0000001b, 0x0000000001b },    // ESCAPE
  { 0x00000020, 0x00000000020 },    // SPACE
  { 0x000000de, 0x00000000022 },    // OEM_7
  { 0x000000bc, 0x0000000002c },    // OEM_COMMA
  { 0x000000bd, 0x0000000002d },    // OEM_MINUS
  { 0x000000be, 0x0000000002e },    // OEM_PERIOD
  { 0x000000bf, 0x0000000002f },    // OEM_2
  { 0x000000ba, 0x0000000003b },    // OEM_1
  { 0x000000bb, 0x0000000003d },    // OEM_PLUS
  { 0x000000db, 0x0000000005b },    // OEM_4
  { 0x000000dc, 0x0000000005c },    // OEM_5
  { 0x000000dd, 0x0000000005d },    // OEM_6
  { 0x000000c0, 0x00000000060 },    // OEM_3
  { 0x0000002e, 0x0000000007f },    // DELETE
  { 0x00000014, 0x00000000104 },    // CAPITAL
  { 0x00000090, 0x0000000010a },    // NUMLOCK
  { 0x00000091, 0x0000000010c },    // SCROLL
  { 0x00000028, 0x00000000301 },    // DOWN
  { 0x00000025, 0x00000000302 },    // LEFT
  { 0x00000027, 0x00000000303 },    // RIGHT
  { 0x00000026, 0x00000000304 },    // UP
  { 0x00000023, 0x00000000305 },    // END
  { 0x00000024, 0x00000000306 },    // HOME
  { 0x00000022, 0x00000000307 },    // NEXT
  { 0x00000021, 0x00000000308 },    // PRIOR
  { 0x0000000c, 0x00000000401 },    // CLEAR
  { 0x0000002d, 0x00000000407 },    // INSERT
  { 0x0000001e, 0x00000000501 },    // ACCEPT
  { 0x000000f6, 0x00000000503 },    // ATTN
  { 0x00000003, 0x00000000504 },    // CANCEL
  { 0x0000005d, 0x00000000505 },    // APPS
  { 0x0000002b, 0x00000000506 },    // EXECUTE
  { 0x0000002f, 0x00000000508 },    // HELP
  { 0x00000013, 0x00000000509 },    // PAUSE
  { 0x000000fa, 0x0000000050a },    // PLAY
  { 0x00000029, 0x0000000050c },    // SELECT
  { 0x0000001c, 0x00000000705 },    // CONVERT
  { 0x0000001f, 0x0000000070b },    // MODECHANGE
  { 0x00000070, 0x00000000801 },    // F1
  { 0x00000071, 0x00000000802 },    // F2
  { 0x00000072, 0x00000000803 },    // F3
  { 0x00000073, 0x00000000804 },    // F4
  { 0x00000074, 0x00000000805 },    // F5
  { 0x00000075, 0x00000000806 },    // F6
  { 0x00000076, 0x00000000807 },    // F7
  { 0x00000077, 0x00000000808 },    // F8
  { 0x00000078, 0x00000000809 },    // F9
  { 0x00000079, 0x0000000080a },    // F10
  { 0x0000007a, 0x0000000080b },    // F11
  { 0x0000007b, 0x0000000080c },    // F12
  { 0x0000007c, 0x0000000080d },    // F13
  { 0x0000007d, 0x0000000080e },    // F14
  { 0x0000007e, 0x0000000080f },    // F15
  { 0x0000007f, 0x00000000810 },    // F16
  { 0x00000080, 0x00000000811 },    // F17
  { 0x00000081, 0x00000000812 },    // F18
  { 0x00000082, 0x00000000813 },    // F19
  { 0x00000083, 0x00000000814 },    // F20
  { 0x00000084, 0x00000000815 },    // F21
  { 0x00000085, 0x00000000816 },    // F22
  { 0x00000086, 0x00000000817 },    // F23
  { 0x00000087, 0x00000000818 },    // F24
  { 0x000000b3, 0x00000000a05 },    // MEDIA_PLAY_PAUSE
  { 0x000000b2, 0x00000000a07 },    // MEDIA_STOP
  { 0x0000002a, 0x00000000a0c },    // PRINT
  { 0x000000ae, 0x00000000a0f },    // VOLUME_DOWN
  { 0x000000af, 0x00000000a10 },    // VOLUME_UP
  { 0x000000ad, 0x00000000a11 },    // VOLUME_MUTE
  { 0x000000b4, 0x00000000b03 },    // LAUNCH_MAIL
  { 0x000000a6, 0x00000000c01 },    // BROWSER_BACK
  { 0x000000ab, 0x00000000c02 },    // BROWSER_FAVORITES
  { 0x000000a7, 0x00000000c03 },    // BROWSER_FORWARD
  { 0x000000ac, 0x00000000c04 },    // BROWSER_HOME
  { 0x000000a8, 0x00000000c05 },    // BROWSER_REFRESH
  { 0x000000aa, 0x00000000c06 },    // BROWSER_SEARCH
  { 0x000000a9, 0x00000000c07 },    // BROWSER_STOP
  { 0x000000c3, 0x0000005ff08 },    // GAMEPAD_A
  { 0x000000c4, 0x0000005ff09 },    // GAMEPAD_B
  { 0x000000c5, 0x0000005ff0a },    // GAMEPAD_X
  { 0x000000c6, 0x0000005ff0b },    // GAMEPAD_Y
  { 0x000000c7, 0x0000005ff0c },    // GAMEPAD_RIGHT_SHOULDER
  { 0x000000c8, 0x0000005ff0d },    // GAMEPAD_LEFT_SHOULDER
  { 0x000000c9, 0x0000005ff0e },    // GAMEPAD_LEFT_TRIGGER
  { 0x000000ca, 0x0000005ff0f },    // GAMEPAD_RIGHT_TRIGGER
  { 0x000000cb, 0x0000005ff10 },    // GAMEPAD_DPAD_UP
  { 0x0000005f, 0x00100010082 },    // SLEEP
  { 0x00000015, 0x00100070090 },    // KANA
  { 0x00000015, 0x00100070090 },    // HANGEUL
  { 0x00000015, 0x00100070090 },    // HANGUL
  { 0x0000006a, 0x0020000002a },    // MULTIPLY
  { 0x0000006b, 0x0020000002b },    // ADD
  { 0x0000006d, 0x0020000002d },    // SUBTRACT
  { 0x0000006e, 0x0020000002e },    // DECIMAL
  { 0x0000006f, 0x0020000002f },    // DIVIDE
  { 0x00000060, 0x00200000030 },    // NUMPAD0
  { 0x00000061, 0x00200000031 },    // NUMPAD1
  { 0x00000062, 0x00200000032 },    // NUMPAD2
  { 0x00000063, 0x00200000033 },    // NUMPAD3
  { 0x00000064, 0x00200000034 },    // NUMPAD4
  { 0x00000065, 0x00200000035 },    // NUMPAD5
  { 0x00000066, 0x00200000036 },    // NUMPAD6
  { 0x00000067, 0x00200000037 },    // NUMPAD7
  { 0x00000068, 0x00200000038 },    // NUMPAD8
  { 0x00000069, 0x00200000039 },    // NUMPAD9
  { 0x00000092, 0x0020000003d },    // OEM_NEC_EQUAL
  { 0x000000a4, 0x00300000102 },    // LMENU
  { 0x00000011, 0x00300000105 },    // CONTROL
  { 0x000000a2, 0x00300000105 },    // LCONTROL
  { 0x0000005b, 0x00300000109 },    // LWIN
  { 0x00000010, 0x0030000010d },    // SHIFT
  { 0x000000a0, 0x0030000010d },    // LSHIFT
  { 0x000000a5, 0x00400000102 },    // RMENU
  { 0x000000a3, 0x00400000105 },    // RCONTROL
  { 0x0000005c, 0x00400000109 },    // RWIN
  { 0x000000a1, 0x0040000010d },    // RSHIFT
};

std::map<uint64_t, uint64_t> FlutterKeyboardManager::scanCodeToLogicalMap_ = {
  { 0x0000e01d, 0x0400000105 },    // ControlRight
  { 0x0000e038, 0x0400000102 },    // AltRight
  { 0x0000004f, 0x0200000031 },    // Numpad1
  { 0x00000050, 0x0200000032 },    // Numpad2
  { 0x00000051, 0x0200000033 },    // Numpad3
  { 0x0000004b, 0x0200000034 },    // Numpad4
  { 0x0000004c, 0x0200000035 },    // Numpad5
  { 0x0000004d, 0x0200000036 },    // Numpad6
  { 0x00000047, 0x0200000037 },    // Numpad7
  { 0x00000048, 0x0200000038 },    // Numpad8
  { 0x00000049, 0x0200000039 },    // Numpad9
  { 0x00000052, 0x0200000030 },    // Numpad0
  { 0x0000004e, 0x020000002b },    // NumpadAdd
  { 0x00000053, 0x020000002e },    // NumpadDecimal
  { 0x0000e035, 0x020000002f },    // NumpadDivide
  { 0x00000059, 0x020000003d },    // NumpadEqual
  { 0x00000037, 0x020000002a },    // NumpadMultiply
  { 0x0000004a, 0x020000002d },    // NumpadSubtract
};

}

#endif
