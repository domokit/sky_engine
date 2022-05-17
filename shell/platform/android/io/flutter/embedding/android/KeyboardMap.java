package io.flutter.embedding.android;

// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// DO NOT EDIT -- DO NOT EDIT -- DO NOT EDIT
// This file is generated by flutter/flutter@dev/tools/gen_keycodes/bin/gen_keycodes.dart and
// should not be edited directly.
//
// Edit the template dev/tools/gen_keycodes/data/android_keyboard_map_java.tmpl instead.
// See dev/tools/gen_keycodes/README.md for more information.

import android.view.KeyEvent;
import java.util.HashMap;

/** Static information used by {@link KeyEmbedderResponder}. */
public class KeyboardMap {
  /** A physicalKey-logicalKey pair used to define mappings. */
  public static class KeyPair {
    public KeyPair(long physicalKey, long logicalKey) {
      this.physicalKey = physicalKey;
      this.logicalKey = logicalKey;
    }

    public long physicalKey;
    public long logicalKey;
  }

  /**
   * An immutable configuration item that defines how to synchronize pressing modifiers (such as
   * Shift or Ctrl), so that the {@link KeyEmbedderResponder} must synthesize events until the
   * combined pressing state of {@link keys} matches the true meta state masked by {@link mask}.
   */
  public static class PressingGoal {
    public PressingGoal(int mask, KeyPair[] keys) {
      this.mask = mask;
      this.keys = keys;
    }

    public final int mask;
    public final KeyPair[] keys;
  }

  /**
   * A configuration item that defines how to synchronize toggling modifiers (such as CapsLock), so
   * that the {@link KeyEmbedderResponder} must synthesize events until the enabling state of the
   * key matches the true meta state masked by {@link mask}.
   *
   * <p>The object of this class is not immutable. The {@link enabled} field will be used to store
   * the current enabling state.
   */
  public static class TogglingGoal {
    public TogglingGoal(int mask, long physicalKey, long logicalKey) {
      this.mask = mask;
      this.physicalKey = physicalKey;
      this.logicalKey = logicalKey;
    }

    public final int mask;
    public final long physicalKey;
    public final long logicalKey;
    /**
     * Used by {@link KeyEmbedderResponder} to store the current enabling state of this modifier.
     *
     * <p>Initialized as false.
     */
    public boolean enabled = false;
  }

  /** Maps from Android scan codes {@link KeyEvent.getScanCode} to Flutter physical keys. */
  public static final HashMap<Long, Long> scanCodeToPhysical =
      new HashMap<Long, Long>() {
        private static final long serialVersionUID = 1L;

        {
          put(0x00000001d0L, 0x0000000012L); // fn
          put(0x00000000cdL, 0x0000000014L); // suspend
          put(0x000000008eL, 0x0000010082L); // sleep
          put(0x000000008fL, 0x0000010083L); // wakeUp
          put(0x0000000100L, 0x000005ff01L); // gameButton1
          put(0x0000000120L, 0x000005ff01L); // gameButton1
          put(0x0000000101L, 0x000005ff02L); // gameButton2
          put(0x0000000121L, 0x000005ff02L); // gameButton2
          put(0x0000000102L, 0x000005ff03L); // gameButton3
          put(0x0000000122L, 0x000005ff03L); // gameButton3
          put(0x0000000103L, 0x000005ff04L); // gameButton4
          put(0x0000000123L, 0x000005ff04L); // gameButton4
          put(0x0000000104L, 0x000005ff05L); // gameButton5
          put(0x0000000124L, 0x000005ff05L); // gameButton5
          put(0x0000000105L, 0x000005ff06L); // gameButton6
          put(0x0000000125L, 0x000005ff06L); // gameButton6
          put(0x0000000106L, 0x000005ff07L); // gameButton7
          put(0x0000000126L, 0x000005ff07L); // gameButton7
          put(0x0000000107L, 0x000005ff08L); // gameButton8
          put(0x0000000127L, 0x000005ff08L); // gameButton8
          put(0x0000000108L, 0x000005ff09L); // gameButton9
          put(0x0000000128L, 0x000005ff09L); // gameButton9
          put(0x0000000109L, 0x000005ff0aL); // gameButton10
          put(0x0000000129L, 0x000005ff0aL); // gameButton10
          put(0x000000010aL, 0x000005ff0bL); // gameButton11
          put(0x000000012aL, 0x000005ff0bL); // gameButton11
          put(0x000000010bL, 0x000005ff0cL); // gameButton12
          put(0x000000012bL, 0x000005ff0cL); // gameButton12
          put(0x000000010cL, 0x000005ff0dL); // gameButton13
          put(0x000000012cL, 0x000005ff0dL); // gameButton13
          put(0x000000010dL, 0x000005ff0eL); // gameButton14
          put(0x000000012dL, 0x000005ff0eL); // gameButton14
          put(0x000000010eL, 0x000005ff0fL); // gameButton15
          put(0x000000012eL, 0x000005ff0fL); // gameButton15
          put(0x000000010fL, 0x000005ff10L); // gameButton16
          put(0x000000012fL, 0x000005ff10L); // gameButton16
          put(0x0000000130L, 0x000005ff11L); // gameButtonA
          put(0x0000000131L, 0x000005ff12L); // gameButtonB
          put(0x0000000132L, 0x000005ff13L); // gameButtonC
          put(0x0000000136L, 0x000005ff14L); // gameButtonLeft1
          put(0x0000000138L, 0x000005ff15L); // gameButtonLeft2
          put(0x000000013cL, 0x000005ff16L); // gameButtonMode
          put(0x0000000137L, 0x000005ff17L); // gameButtonRight1
          put(0x0000000139L, 0x000005ff18L); // gameButtonRight2
          put(0x000000013aL, 0x000005ff19L); // gameButtonSelect
          put(0x000000013bL, 0x000005ff1aL); // gameButtonStart
          put(0x000000013dL, 0x000005ff1bL); // gameButtonThumbLeft
          put(0x000000013eL, 0x000005ff1cL); // gameButtonThumbRight
          put(0x0000000133L, 0x000005ff1dL); // gameButtonX
          put(0x0000000134L, 0x000005ff1eL); // gameButtonY
          put(0x0000000135L, 0x000005ff1fL); // gameButtonZ
          put(0x000000001eL, 0x0000070004L); // keyA
          put(0x0000000030L, 0x0000070005L); // keyB
          put(0x000000002eL, 0x0000070006L); // keyC
          put(0x0000000020L, 0x0000070007L); // keyD
          put(0x0000000012L, 0x0000070008L); // keyE
          put(0x0000000021L, 0x0000070009L); // keyF
          put(0x0000000022L, 0x000007000aL); // keyG
          put(0x0000000023L, 0x000007000bL); // keyH
          put(0x0000000017L, 0x000007000cL); // keyI
          put(0x0000000024L, 0x000007000dL); // keyJ
          put(0x0000000025L, 0x000007000eL); // keyK
          put(0x0000000026L, 0x000007000fL); // keyL
          put(0x0000000032L, 0x0000070010L); // keyM
          put(0x0000000031L, 0x0000070011L); // keyN
          put(0x0000000018L, 0x0000070012L); // keyO
          put(0x0000000019L, 0x0000070013L); // keyP
          put(0x0000000010L, 0x0000070014L); // keyQ
          put(0x0000000013L, 0x0000070015L); // keyR
          put(0x000000001fL, 0x0000070016L); // keyS
          put(0x0000000014L, 0x0000070017L); // keyT
          put(0x0000000016L, 0x0000070018L); // keyU
          put(0x000000002fL, 0x0000070019L); // keyV
          put(0x0000000011L, 0x000007001aL); // keyW
          put(0x000000002dL, 0x000007001bL); // keyX
          put(0x0000000015L, 0x000007001cL); // keyY
          put(0x000000002cL, 0x000007001dL); // keyZ
          put(0x0000000002L, 0x000007001eL); // digit1
          put(0x0000000003L, 0x000007001fL); // digit2
          put(0x0000000004L, 0x0000070020L); // digit3
          put(0x0000000005L, 0x0000070021L); // digit4
          put(0x0000000006L, 0x0000070022L); // digit5
          put(0x0000000007L, 0x0000070023L); // digit6
          put(0x0000000008L, 0x0000070024L); // digit7
          put(0x0000000009L, 0x0000070025L); // digit8
          put(0x000000000aL, 0x0000070026L); // digit9
          put(0x000000000bL, 0x0000070027L); // digit0
          put(0x000000001cL, 0x0000070028L); // enter
          put(0x0000000001L, 0x0000070029L); // escape
          put(0x000000000eL, 0x000007002aL); // backspace
          put(0x000000000fL, 0x000007002bL); // tab
          put(0x0000000039L, 0x000007002cL); // space
          put(0x000000000cL, 0x000007002dL); // minus
          put(0x000000000dL, 0x000007002eL); // equal
          put(0x000000001aL, 0x000007002fL); // bracketLeft
          put(0x000000001bL, 0x0000070030L); // bracketRight
          put(0x000000002bL, 0x0000070031L); // backslash
          put(0x0000000056L, 0x0000070031L); // backslash
          put(0x0000000027L, 0x0000070033L); // semicolon
          put(0x0000000028L, 0x0000070034L); // quote
          put(0x0000000029L, 0x0000070035L); // backquote
          put(0x0000000033L, 0x0000070036L); // comma
          put(0x0000000034L, 0x0000070037L); // period
          put(0x0000000035L, 0x0000070038L); // slash
          put(0x000000003aL, 0x0000070039L); // capsLock
          put(0x000000003bL, 0x000007003aL); // f1
          put(0x000000003cL, 0x000007003bL); // f2
          put(0x000000003dL, 0x000007003cL); // f3
          put(0x000000003eL, 0x000007003dL); // f4
          put(0x000000003fL, 0x000007003eL); // f5
          put(0x0000000040L, 0x000007003fL); // f6
          put(0x0000000041L, 0x0000070040L); // f7
          put(0x0000000042L, 0x0000070041L); // f8
          put(0x0000000043L, 0x0000070042L); // f9
          put(0x0000000044L, 0x0000070043L); // f10
          put(0x0000000057L, 0x0000070044L); // f11
          put(0x0000000058L, 0x0000070045L); // f12
          put(0x0000000063L, 0x0000070046L); // printScreen
          put(0x0000000046L, 0x0000070047L); // scrollLock
          put(0x0000000077L, 0x0000070048L); // pause
          put(0x000000019bL, 0x0000070048L); // pause
          put(0x000000006eL, 0x0000070049L); // insert
          put(0x0000000066L, 0x000007004aL); // home
          put(0x0000000068L, 0x000007004bL); // pageUp
          put(0x00000000b1L, 0x000007004bL); // pageUp
          put(0x000000006fL, 0x000007004cL); // delete
          put(0x000000006bL, 0x000007004dL); // end
          put(0x000000006dL, 0x000007004eL); // pageDown
          put(0x00000000b2L, 0x000007004eL); // pageDown
          put(0x000000006aL, 0x000007004fL); // arrowRight
          put(0x0000000069L, 0x0000070050L); // arrowLeft
          put(0x000000006cL, 0x0000070051L); // arrowDown
          put(0x0000000067L, 0x0000070052L); // arrowUp
          put(0x0000000045L, 0x0000070053L); // numLock
          put(0x0000000062L, 0x0000070054L); // numpadDivide
          put(0x0000000037L, 0x0000070055L); // numpadMultiply
          put(0x000000004aL, 0x0000070056L); // numpadSubtract
          put(0x000000004eL, 0x0000070057L); // numpadAdd
          put(0x0000000060L, 0x0000070058L); // numpadEnter
          put(0x000000004fL, 0x0000070059L); // numpad1
          put(0x0000000050L, 0x000007005aL); // numpad2
          put(0x0000000051L, 0x000007005bL); // numpad3
          put(0x000000004bL, 0x000007005cL); // numpad4
          put(0x000000004cL, 0x000007005dL); // numpad5
          put(0x000000004dL, 0x000007005eL); // numpad6
          put(0x0000000047L, 0x000007005fL); // numpad7
          put(0x0000000048L, 0x0000070060L); // numpad8
          put(0x0000000049L, 0x0000070061L); // numpad9
          put(0x0000000052L, 0x0000070062L); // numpad0
          put(0x0000000053L, 0x0000070063L); // numpadDecimal
          put(0x000000007fL, 0x0000070065L); // contextMenu
          put(0x000000008bL, 0x0000070065L); // contextMenu
          put(0x0000000074L, 0x0000070066L); // power
          put(0x0000000098L, 0x0000070066L); // power
          put(0x0000000075L, 0x0000070067L); // numpadEqual
          put(0x00000000b7L, 0x0000070068L); // f13
          put(0x00000000b8L, 0x0000070069L); // f14
          put(0x00000000b9L, 0x000007006aL); // f15
          put(0x00000000baL, 0x000007006bL); // f16
          put(0x00000000bbL, 0x000007006cL); // f17
          put(0x00000000bcL, 0x000007006dL); // f18
          put(0x00000000bdL, 0x000007006eL); // f19
          put(0x00000000beL, 0x000007006fL); // f20
          put(0x00000000bfL, 0x0000070070L); // f21
          put(0x00000000c0L, 0x0000070071L); // f22
          put(0x00000000c1L, 0x0000070072L); // f23
          put(0x00000000c2L, 0x0000070073L); // f24
          put(0x0000000086L, 0x0000070074L); // open
          put(0x000000008aL, 0x0000070075L); // help
          put(0x0000000161L, 0x0000070077L); // select
          put(0x0000000081L, 0x0000070079L); // again
          put(0x0000000083L, 0x000007007aL); // undo
          put(0x0000000089L, 0x000007007bL); // cut
          put(0x0000000085L, 0x000007007cL); // copy
          put(0x0000000087L, 0x000007007dL); // paste
          put(0x0000000088L, 0x000007007eL); // find
          put(0x0000000071L, 0x000007007fL); // audioVolumeMute
          put(0x0000000073L, 0x0000070080L); // audioVolumeUp
          put(0x0000000072L, 0x0000070081L); // audioVolumeDown
          put(0x000000005fL, 0x0000070085L); // numpadComma
          put(0x0000000079L, 0x0000070085L); // numpadComma
          put(0x0000000059L, 0x0000070087L); // intlRo
          put(0x000000007cL, 0x0000070089L); // intlYen
          put(0x000000005cL, 0x000007008aL); // convert
          put(0x000000005eL, 0x000007008bL); // nonConvert
          put(0x000000005aL, 0x0000070092L); // lang3
          put(0x000000005bL, 0x0000070093L); // lang4
          put(0x0000000082L, 0x00000700a3L); // props
          put(0x00000000b3L, 0x00000700b6L); // numpadParenLeft
          put(0x00000000b4L, 0x00000700b7L); // numpadParenRight
          put(0x000000001dL, 0x00000700e0L); // controlLeft
          put(0x000000002aL, 0x00000700e1L); // shiftLeft
          put(0x0000000038L, 0x00000700e2L); // altLeft
          put(0x000000007dL, 0x00000700e3L); // metaLeft
          put(0x0000000061L, 0x00000700e4L); // controlRight
          put(0x0000000036L, 0x00000700e5L); // shiftRight
          put(0x0000000064L, 0x00000700e6L); // altRight
          put(0x000000007eL, 0x00000700e7L); // metaRight
          put(0x0000000166L, 0x00000c0060L); // info
          put(0x0000000172L, 0x00000c0061L); // closedCaptionToggle
          put(0x00000000e1L, 0x00000c006fL); // brightnessUp
          put(0x00000000e0L, 0x00000c0070L); // brightnessDown
          put(0x0000000195L, 0x00000c0083L); // mediaLast
          put(0x00000000aeL, 0x00000c0094L); // exit
          put(0x0000000192L, 0x00000c009cL); // channelUp
          put(0x0000000193L, 0x00000c009dL); // channelDown
          put(0x00000000c8L, 0x00000c00b0L); // mediaPlay
          put(0x00000000cfL, 0x00000c00b0L); // mediaPlay
          put(0x00000000c9L, 0x00000c00b1L); // mediaPause
          put(0x00000000a7L, 0x00000c00b2L); // mediaRecord
          put(0x00000000d0L, 0x00000c00b3L); // mediaFastForward
          put(0x00000000a8L, 0x00000c00b4L); // mediaRewind
          put(0x00000000a3L, 0x00000c00b5L); // mediaTrackNext
          put(0x00000000a5L, 0x00000c00b6L); // mediaTrackPrevious
          put(0x0000000080L, 0x00000c00b7L); // mediaStop
          put(0x00000000a6L, 0x00000c00b7L); // mediaStop
          put(0x00000000a1L, 0x00000c00b8L); // eject
          put(0x00000000a2L, 0x00000c00b8L); // eject
          put(0x00000000a4L, 0x00000c00cdL); // mediaPlayPause
          put(0x00000000d1L, 0x00000c00e5L); // bassBoost
          put(0x000000009bL, 0x00000c018aL); // launchMail
          put(0x00000000d7L, 0x00000c018aL); // launchMail
          put(0x00000001adL, 0x00000c018dL); // launchContacts
          put(0x000000018dL, 0x00000c018eL); // launchCalendar
          put(0x0000000247L, 0x00000c01cbL); // launchAssistant
          put(0x00000000a0L, 0x00000c0203L); // close
          put(0x00000000ceL, 0x00000c0203L); // close
          put(0x00000000d2L, 0x00000c0208L); // print
          put(0x00000000d9L, 0x00000c0221L); // browserSearch
          put(0x000000009fL, 0x00000c0225L); // browserForward
          put(0x000000009cL, 0x00000c022aL); // browserFavorites
          put(0x00000000b6L, 0x00000c0279L); // redo
        }
      };

  /** Maps from Android key codes {@link KeyEvent.getKeyCode} to Flutter logical keys. */
  public static final HashMap<Long, Long> keyCodeToLogical =
      new HashMap<Long, Long>() {
        private static final long serialVersionUID = 1L;

        {
          put(0x000000003eL, 0x0000000020L); // space
          put(0x000000004bL, 0x0000000022L); // quote
          put(0x0000000012L, 0x0000000023L); // numberSign
          put(0x0000000011L, 0x000000002aL); // asterisk
          put(0x0000000051L, 0x000000002bL); // add
          put(0x0000000037L, 0x000000002cL); // comma
          put(0x0000000045L, 0x000000002dL); // minus
          put(0x0000000038L, 0x000000002eL); // period
          put(0x000000004cL, 0x000000002fL); // slash
          put(0x0000000007L, 0x0000000030L); // digit0
          put(0x0000000008L, 0x0000000031L); // digit1
          put(0x0000000009L, 0x0000000032L); // digit2
          put(0x000000000aL, 0x0000000033L); // digit3
          put(0x000000000bL, 0x0000000034L); // digit4
          put(0x000000000cL, 0x0000000035L); // digit5
          put(0x000000000dL, 0x0000000036L); // digit6
          put(0x000000000eL, 0x0000000037L); // digit7
          put(0x000000000fL, 0x0000000038L); // digit8
          put(0x0000000010L, 0x0000000039L); // digit9
          put(0x000000004aL, 0x000000003bL); // semicolon
          put(0x0000000046L, 0x000000003dL); // equal
          put(0x000000004dL, 0x0000000040L); // at
          put(0x0000000047L, 0x000000005bL); // bracketLeft
          put(0x0000000049L, 0x000000005cL); // backslash
          put(0x0000000048L, 0x000000005dL); // bracketRight
          put(0x0000000044L, 0x0000000060L); // backquote
          put(0x000000001dL, 0x0000000061L); // keyA
          put(0x000000001eL, 0x0000000062L); // keyB
          put(0x000000001fL, 0x0000000063L); // keyC
          put(0x0000000020L, 0x0000000064L); // keyD
          put(0x0000000021L, 0x0000000065L); // keyE
          put(0x0000000022L, 0x0000000066L); // keyF
          put(0x0000000023L, 0x0000000067L); // keyG
          put(0x0000000024L, 0x0000000068L); // keyH
          put(0x0000000025L, 0x0000000069L); // keyI
          put(0x0000000026L, 0x000000006aL); // keyJ
          put(0x0000000027L, 0x000000006bL); // keyK
          put(0x0000000028L, 0x000000006cL); // keyL
          put(0x0000000029L, 0x000000006dL); // keyM
          put(0x000000002aL, 0x000000006eL); // keyN
          put(0x000000002bL, 0x000000006fL); // keyO
          put(0x000000002cL, 0x0000000070L); // keyP
          put(0x000000002dL, 0x0000000071L); // keyQ
          put(0x000000002eL, 0x0000000072L); // keyR
          put(0x000000002fL, 0x0000000073L); // keyS
          put(0x0000000030L, 0x0000000074L); // keyT
          put(0x0000000031L, 0x0000000075L); // keyU
          put(0x0000000032L, 0x0000000076L); // keyV
          put(0x0000000033L, 0x0000000077L); // keyW
          put(0x0000000034L, 0x0000000078L); // keyX
          put(0x0000000035L, 0x0000000079L); // keyY
          put(0x0000000036L, 0x000000007aL); // keyZ
          put(0x0000000043L, 0x0100000008L); // backspace
          put(0x000000003dL, 0x0100000009L); // tab
          put(0x0000000042L, 0x010000000dL); // enter
          put(0x000000006fL, 0x010000001bL); // escape
          put(0x0000000070L, 0x010000007fL); // delete
          put(0x0000000073L, 0x0100000104L); // capsLock
          put(0x0000000077L, 0x0100000106L); // fn
          put(0x000000008fL, 0x010000010aL); // numLock
          put(0x0000000074L, 0x010000010cL); // scrollLock
          put(0x000000003fL, 0x010000010fL); // symbol
          put(0x0000000014L, 0x0100000301L); // arrowDown
          put(0x0000000015L, 0x0100000302L); // arrowLeft
          put(0x0000000016L, 0x0100000303L); // arrowRight
          put(0x0000000013L, 0x0100000304L); // arrowUp
          put(0x000000007bL, 0x0100000305L); // end
          put(0x000000007aL, 0x0100000306L); // home
          put(0x000000005dL, 0x0100000307L); // pageDown
          put(0x000000005cL, 0x0100000308L); // pageUp
          put(0x000000001cL, 0x0100000401L); // clear
          put(0x0000000116L, 0x0100000402L); // copy
          put(0x0000000115L, 0x0100000404L); // cut
          put(0x000000007cL, 0x0100000407L); // insert
          put(0x0000000117L, 0x0100000408L); // paste
          put(0x0000000052L, 0x0100000505L); // contextMenu
          put(0x0000000103L, 0x0100000508L); // help
          put(0x0000000079L, 0x0100000509L); // pause
          put(0x0000000017L, 0x010000050cL); // select
          put(0x00000000a8L, 0x010000050dL); // zoomIn
          put(0x00000000a9L, 0x010000050eL); // zoomOut
          put(0x00000000dcL, 0x0100000601L); // brightnessDown
          put(0x00000000ddL, 0x0100000602L); // brightnessUp
          put(0x000000001bL, 0x0100000603L); // camera
          put(0x0000000081L, 0x0100000604L); // eject
          put(0x000000001aL, 0x0100000606L); // power
          put(0x0000000078L, 0x0100000608L); // printScreen
          put(0x00000000e0L, 0x010000060bL); // wakeUp
          put(0x00000000d6L, 0x0100000705L); // convert
          put(0x00000000ccL, 0x0100000709L); // groupNext
          put(0x000000005fL, 0x010000070bL); // modeChange
          put(0x00000000d5L, 0x010000070dL); // nonConvert
          put(0x00000000d4L, 0x0100000714L); // eisu
          put(0x00000000d7L, 0x0100000717L); // hiraganaKatakana
          put(0x00000000daL, 0x0100000719L); // kanjiMode
          put(0x00000000d3L, 0x010000071dL); // zenkakuHankaku
          put(0x0000000083L, 0x0100000801L); // f1
          put(0x0000000084L, 0x0100000802L); // f2
          put(0x0000000085L, 0x0100000803L); // f3
          put(0x0000000086L, 0x0100000804L); // f4
          put(0x0000000087L, 0x0100000805L); // f5
          put(0x0000000088L, 0x0100000806L); // f6
          put(0x0000000089L, 0x0100000807L); // f7
          put(0x000000008aL, 0x0100000808L); // f8
          put(0x000000008bL, 0x0100000809L); // f9
          put(0x000000008cL, 0x010000080aL); // f10
          put(0x000000008dL, 0x010000080bL); // f11
          put(0x000000008eL, 0x010000080cL); // f12
          put(0x0000000080L, 0x0100000a01L); // close
          put(0x0000000055L, 0x0100000a05L); // mediaPlayPause
          put(0x0000000056L, 0x0100000a07L); // mediaStop
          put(0x0000000057L, 0x0100000a08L); // mediaTrackNext
          put(0x0000000058L, 0x0100000a09L); // mediaTrackPrevious
          put(0x0000000019L, 0x0100000a0fL); // audioVolumeDown
          put(0x0000000018L, 0x0100000a10L); // audioVolumeUp
          put(0x00000000a4L, 0x0100000a11L); // audioVolumeMute
          put(0x00000000d0L, 0x0100000b02L); // launchCalendar
          put(0x0000000041L, 0x0100000b03L); // launchMail
          put(0x00000000d1L, 0x0100000b05L); // launchMusicPlayer
          put(0x0000000040L, 0x0100000b09L); // launchWebBrowser
          put(0x00000000cfL, 0x0100000b0cL); // launchContacts
          put(0x00000000dbL, 0x0100000b0eL); // launchAssistant
          put(0x00000000aeL, 0x0100000c02L); // browserFavorites
          put(0x000000007dL, 0x0100000c03L); // browserForward
          put(0x0000000054L, 0x0100000c06L); // browserSearch
          put(0x00000000b6L, 0x0100000d08L); // avrInput
          put(0x00000000b5L, 0x0100000d09L); // avrPower
          put(0x00000000a7L, 0x0100000d0aL); // channelDown
          put(0x00000000a6L, 0x0100000d0bL); // channelUp
          put(0x00000000b7L, 0x0100000d0cL); // colorF0Red
          put(0x00000000b8L, 0x0100000d0dL); // colorF1Green
          put(0x00000000b9L, 0x0100000d0eL); // colorF2Yellow
          put(0x00000000baL, 0x0100000d0fL); // colorF3Blue
          put(0x00000000afL, 0x0100000d12L); // closedCaptionToggle
          put(0x00000000acL, 0x0100000d22L); // guide
          put(0x00000000a5L, 0x0100000d25L); // info
          put(0x000000005aL, 0x0100000d2cL); // mediaFastForward
          put(0x00000000e5L, 0x0100000d2dL); // mediaLast
          put(0x000000007fL, 0x0100000d2eL); // mediaPause
          put(0x000000007eL, 0x0100000d2fL); // mediaPlay
          put(0x0000000082L, 0x0100000d30L); // mediaRecord
          put(0x0000000059L, 0x0100000d31L); // mediaRewind
          put(0x00000000b0L, 0x0100000d43L); // settings
          put(0x00000000b4L, 0x0100000d45L); // stbInput
          put(0x00000000b3L, 0x0100000d46L); // stbPower
          put(0x00000000e9L, 0x0100000d48L); // teletext
          put(0x00000000aaL, 0x0100000d49L); // tv
          put(0x00000000b2L, 0x0100000d4aL); // tvInput
          put(0x00000000b1L, 0x0100000d4bL); // tvPower
          put(0x00000000ffL, 0x0100000d4eL); // zoomToggle
          put(0x00000000adL, 0x0100000d4fL); // dvr
          put(0x00000000deL, 0x0100000d50L); // mediaAudioTrack
          put(0x0000000111L, 0x0100000d51L); // mediaSkipBackward
          put(0x0000000110L, 0x0100000d52L); // mediaSkipForward
          put(0x0000000113L, 0x0100000d53L); // mediaStepBackward
          put(0x0000000112L, 0x0100000d54L); // mediaStepForward
          put(0x00000000e2L, 0x0100000d55L); // mediaTopMenu
          put(0x0000000106L, 0x0100000d56L); // navigateIn
          put(0x0000000105L, 0x0100000d57L); // navigateNext
          put(0x0000000107L, 0x0100000d58L); // navigateOut
          put(0x0000000104L, 0x0100000d59L); // navigatePrevious
          put(0x00000000e1L, 0x0100000d5aL); // pairing
          put(0x000000005bL, 0x0100000e09L); // microphoneVolumeMute
          put(0x00000000bbL, 0x0100001001L); // appSwitch
          put(0x0000000005L, 0x0100001002L); // call
          put(0x0000000050L, 0x0100001003L); // cameraFocus
          put(0x0000000006L, 0x0100001004L); // endCall
          put(0x0000000004L, 0x0100001005L); // goBack
          put(0x0000000003L, 0x0100001006L); // goHome
          put(0x000000004fL, 0x0100001007L); // headsetHook
          put(0x0000000053L, 0x0100001009L); // notification
          put(0x00000000cdL, 0x010000100aL); // mannerMode
          put(0x00000000ceL, 0x0100001101L); // tv3DMode
          put(0x00000000f2L, 0x0100001102L); // tvAntennaCable
          put(0x00000000fcL, 0x0100001103L); // tvAudioDescription
          put(0x00000000feL, 0x0100001104L); // tvAudioDescriptionMixDown
          put(0x00000000fdL, 0x0100001105L); // tvAudioDescriptionMixUp
          put(0x0000000100L, 0x0100001106L); // tvContentsMenu
          put(0x00000000e6L, 0x0100001107L); // tvDataService
          put(0x00000000f9L, 0x0100001108L); // tvInputComponent1
          put(0x00000000faL, 0x0100001109L); // tvInputComponent2
          put(0x00000000f7L, 0x010000110aL); // tvInputComposite1
          put(0x00000000f8L, 0x010000110bL); // tvInputComposite2
          put(0x00000000f3L, 0x010000110cL); // tvInputHDMI1
          put(0x00000000f4L, 0x010000110dL); // tvInputHDMI2
          put(0x00000000f5L, 0x010000110eL); // tvInputHDMI3
          put(0x00000000f6L, 0x010000110fL); // tvInputHDMI4
          put(0x00000000fbL, 0x0100001110L); // tvInputVGA1
          put(0x00000000f1L, 0x0100001112L); // tvNetwork
          put(0x00000000eaL, 0x0100001113L); // tvNumberEntry
          put(0x00000000e8L, 0x0100001114L); // tvRadioService
          put(0x00000000edL, 0x0100001115L); // tvSatellite
          put(0x00000000eeL, 0x0100001116L); // tvSatelliteBS
          put(0x00000000efL, 0x0100001117L); // tvSatelliteCS
          put(0x00000000f0L, 0x0100001118L); // tvSatelliteToggle
          put(0x00000000ebL, 0x0100001119L); // tvTerrestrialAnalog
          put(0x00000000ecL, 0x010000111aL); // tvTerrestrialDigital
          put(0x0000000102L, 0x010000111bL); // tvTimer
          put(0x00000000dfL, 0x0200000002L); // sleep
          put(0x00000000d9L, 0x0200000021L); // intlRo
          put(0x00000000d8L, 0x0200000022L); // intlYen
          put(0x0000000071L, 0x0200000100L); // controlLeft
          put(0x0000000072L, 0x0200000101L); // controlRight
          put(0x000000003bL, 0x0200000102L); // shiftLeft
          put(0x000000003cL, 0x0200000103L); // shiftRight
          put(0x0000000039L, 0x0200000104L); // altLeft
          put(0x000000003aL, 0x0200000105L); // altRight
          put(0x0000000075L, 0x0200000106L); // metaLeft
          put(0x0000000076L, 0x0200000107L); // metaRight
          put(0x00000000a0L, 0x020000020dL); // numpadEnter
          put(0x00000000a2L, 0x0200000228L); // numpadParenLeft
          put(0x00000000a3L, 0x0200000229L); // numpadParenRight
          put(0x000000009bL, 0x020000022aL); // numpadMultiply
          put(0x000000009dL, 0x020000022bL); // numpadAdd
          put(0x000000009fL, 0x020000022cL); // numpadComma
          put(0x000000009cL, 0x020000022dL); // numpadSubtract
          put(0x000000009eL, 0x020000022eL); // numpadDecimal
          put(0x000000009aL, 0x020000022fL); // numpadDivide
          put(0x0000000090L, 0x0200000230L); // numpad0
          put(0x0000000091L, 0x0200000231L); // numpad1
          put(0x0000000092L, 0x0200000232L); // numpad2
          put(0x0000000093L, 0x0200000233L); // numpad3
          put(0x0000000094L, 0x0200000234L); // numpad4
          put(0x0000000095L, 0x0200000235L); // numpad5
          put(0x0000000096L, 0x0200000236L); // numpad6
          put(0x0000000097L, 0x0200000237L); // numpad7
          put(0x0000000098L, 0x0200000238L); // numpad8
          put(0x0000000099L, 0x0200000239L); // numpad9
          put(0x00000000a1L, 0x020000023dL); // numpadEqual
          put(0x00000000bcL, 0x0200000301L); // gameButton1
          put(0x00000000bdL, 0x0200000302L); // gameButton2
          put(0x00000000beL, 0x0200000303L); // gameButton3
          put(0x00000000bfL, 0x0200000304L); // gameButton4
          put(0x00000000c0L, 0x0200000305L); // gameButton5
          put(0x00000000c1L, 0x0200000306L); // gameButton6
          put(0x00000000c2L, 0x0200000307L); // gameButton7
          put(0x00000000c3L, 0x0200000308L); // gameButton8
          put(0x00000000c4L, 0x0200000309L); // gameButton9
          put(0x00000000c5L, 0x020000030aL); // gameButton10
          put(0x00000000c6L, 0x020000030bL); // gameButton11
          put(0x00000000c7L, 0x020000030cL); // gameButton12
          put(0x00000000c8L, 0x020000030dL); // gameButton13
          put(0x00000000c9L, 0x020000030eL); // gameButton14
          put(0x00000000caL, 0x020000030fL); // gameButton15
          put(0x00000000cbL, 0x0200000310L); // gameButton16
          put(0x0000000060L, 0x0200000311L); // gameButtonA
          put(0x0000000061L, 0x0200000312L); // gameButtonB
          put(0x0000000062L, 0x0200000313L); // gameButtonC
          put(0x0000000066L, 0x0200000314L); // gameButtonLeft1
          put(0x0000000068L, 0x0200000315L); // gameButtonLeft2
          put(0x000000006eL, 0x0200000316L); // gameButtonMode
          put(0x0000000067L, 0x0200000317L); // gameButtonRight1
          put(0x0000000069L, 0x0200000318L); // gameButtonRight2
          put(0x000000006dL, 0x0200000319L); // gameButtonSelect
          put(0x000000006cL, 0x020000031aL); // gameButtonStart
          put(0x000000006aL, 0x020000031bL); // gameButtonThumbLeft
          put(0x000000006bL, 0x020000031cL); // gameButtonThumbRight
          put(0x0000000063L, 0x020000031dL); // gameButtonX
          put(0x0000000064L, 0x020000031eL); // gameButtonY
          put(0x0000000065L, 0x020000031fL); // gameButtonZ
        }
      };

  public static final PressingGoal[] pressingGoals =
      new PressingGoal[] {
        new PressingGoal(
            KeyEvent.META_CTRL_ON,
            new KeyPair[] {
              new KeyPair(0x000700e0L, 0x0200000100L), // ControlLeft
              new KeyPair(0x000700e4L, 0x0200000101L), // ControlRight
            }),
        new PressingGoal(
            KeyEvent.META_SHIFT_ON,
            new KeyPair[] {
              new KeyPair(0x000700e1L, 0x0200000102L), // ShiftLeft
              new KeyPair(0x000700e5L, 0x0200000103L), // ShiftRight
            }),
        new PressingGoal(
            KeyEvent.META_ALT_ON,
            new KeyPair[] {
              new KeyPair(0x000700e2L, 0x0200000104L), // AltLeft
              new KeyPair(0x000700e6L, 0x0200000105L), // AltRight
            }),
      };

  /**
   * A list of toggling modifiers that must be synchronized on each key event.
   *
   * <p>The list is not a static variable but constructed by a function, because {@link
   * TogglingGoal} is not immutable.
   */
  public static TogglingGoal[] getTogglingGoals() {
    return new TogglingGoal[] {
      new TogglingGoal(KeyEvent.META_CAPS_LOCK_ON, 0x00070039L, 0x0100000104L),
    };
  }

  public static final long kValueMask = 0x000ffffffffL;
  public static final long kUnicodePlane = 0x00000000000L;
  public static final long kAndroidPlane = 0x01100000000L;
}
