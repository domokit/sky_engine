// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of engine;

/// The maximum [semanticsActivationAttempts] before we give up waiting for
/// the user to enable semantics.
///
/// This number is arbitrary and can be adjusted if it doesn't work well.
const int kMaxSemanticsActivationAttempts = 20;

/// The message in the label for the placeholder element used to enable
/// accessibility.
///
/// This uses US English as the default message. Set this value prior to
/// calling `runApp` to translate to another language.
String placeholderMessage = 'Enable accessibility';

class SemanticsHelper {
  final _EnableSemantics _enableSemantics =
      isDesktop ? DesktopEnableSemantics() : MobileEnableSemantics();

  bool shouldEnableSemantics(html.Event event) {
    return _enableSemantics.tryEnableSemantics(event);
  }

  html.Element prepareAccesibilityPlaceholder() {
    return _enableSemantics.prepareAccesibilityPlaceholder();
  }
}

abstract class _EnableSemantics {
  /// A temporary placeholder used to capture a request to activate semantics.
  html.Element _semanticsPlaceholder;

  /// We do not immediately enable semantics when the user requests it, but
  /// instead wait for a short period of time before doing it. This is because
  /// the request comes as a tap on the [_semanticsPlaceholder]. The tap,
  /// depending on the browser, comes as a burst of events. For example, Safari
  /// sends "touchstart", "touchend", and "click". So during a short time period
  /// we consume all events and prevent forwarding to the framework. Otherwise,
  /// the events will be interpreted twice, once as a request to activate
  /// semantics, and a second time by Flutter's gesture recognizers.
  @visibleForTesting
  Timer semanticsActivationTimer;

  /// The number of events we processed that could potentially activate
  /// semantics.
  int semanticsActivationAttempts = 0;

  /// Instructs [_tryEnableSemantics] to remove [_semanticsPlaceholder].
  ///
  /// On Chrome the placeholder is removed upon any next event.
  ///
  /// On Safari the placeholder is removed upon the next "touchend" event. This
  /// is to prevent Safari from swallowing the event that happens on an element
  /// that's being removed. Chrome doesn't have this issue.
  bool _schedulePlaceholderRemoval = false;

  /// Whether we are waiting for the user to enable semantics.
  bool get _isWaitingToEnableSemantics => _semanticsPlaceholder != null;

  bool shouldEnableSemantics(html.Event event) {
    if (!_isWaitingToEnableSemantics) {
      // Forward to framework as normal.
      return true;
    } else {
      return tryEnableSemantics(event);
    }
  }

  /// Attempts to activate semantics.
  ///
  /// Returns true if the `event` is not related to semantics activation and
  /// should be forwarded to the framework.
  bool tryEnableSemantics(html.Event event);

  /// Creates the placeholder for accesibility.
  ///
  /// Puts it inside the glasspane.
  ///
  /// On focus the element announces that accessibility can be enabled by
  /// tapping/clicking. (Announcement depends on the assistive technology)
  html.Element prepareAccesibilityPlaceholder();
}

@visibleForTesting
class DesktopEnableSemantics extends _EnableSemantics {
  @override
  bool tryEnableSemantics(html.Event event) {
    if (_schedulePlaceholderRemoval) {
      _semanticsPlaceholder.remove();
      _semanticsPlaceholder = null;
      semanticsActivationTimer = null;
      return true;
    }

    if (EngineSemanticsOwner.instance.semanticsEnabled) {
      // Semantics already enabled, forward to framework as normal.
      return true;
    }

    // In touch screen laptops, the touch is received as a mouse click
    const List<String> kInterestingEventTypes = <String>[
      'click',
      'keyup',
      'keydown',
      'mouseup',
      'mousedown',
      'pointerdown',
      'pointerup',
    ];

    if (!kInterestingEventTypes.contains(event.type)) {
      // The event is not relevant, forward to framework as normal.
      return true;
    }

    semanticsActivationAttempts += 1;
    if (semanticsActivationAttempts >= kMaxSemanticsActivationAttempts) {
      // We have received multiple user events, none of which resulted in
      // semantics activation. This is a signal that the user is not interested
      // in semantics, and so we will stop waiting for it.
      _schedulePlaceholderRemoval = true;
      return true;
    }

    if (semanticsActivationTimer != null) {
      // We are in a waiting period to activate a timer. While the timer is
      // active we should consume events pertaining to semantics activation.
      // Otherwise the event will also be interpreted by the framework and
      // potentially result in activating a gesture in the app.
      return false;
    }

    // Check for the event target.
    bool enableConditionPassed = (event.target == _semanticsPlaceholder);

    if (enableConditionPassed) {
      assert(semanticsActivationTimer == null);
      semanticsActivationTimer = Timer(const Duration(milliseconds: 300), () {
        EngineSemanticsOwner.instance.semanticsEnabled = true;
        _schedulePlaceholderRemoval = true;
      });
      return false;
    }

    // This was not a semantics activating event; forward as normal.
    return true;
  }

  @override
  html.Element prepareAccesibilityPlaceholder() {
    _semanticsPlaceholder = html.Element.tag('flt-semantics-placeholder');

    // Only listen to "click" because other kinds of events are reported via
    // PointerBinding.
    _semanticsPlaceholder.addEventListener('click', (html.Event event) {
      tryEnableSemantics(event);
    }, true);

    _semanticsPlaceholder
      ..setAttribute('role', 'button')
      ..setAttribute('aria-live', 'true')
      ..setAttribute('tabindex', '0')
      ..setAttribute('aria-label', placeholderMessage);
    _semanticsPlaceholder.style
      ..position = 'absolute'
      ..left = '-1px'
      ..top = '-1px'
      ..width = '1px'
      ..height = '1px';
    return _semanticsPlaceholder;
  }
}

@visibleForTesting
class MobileEnableSemantics extends _EnableSemantics {
  @override
  bool tryEnableSemantics(html.Event event) {
    if (_schedulePlaceholderRemoval) {
      final bool removeNow =
          (browserEngine != BrowserEngine.webkit || event.type == 'touchend');
      if (removeNow) {
        _semanticsPlaceholder.remove();
        _semanticsPlaceholder = null;
        semanticsActivationTimer = null;
      }
      return true;
    }

    if (EngineSemanticsOwner.instance.semanticsEnabled) {
      // Semantics already enabled, forward to framework as normal.
      return true;
    }

    semanticsActivationAttempts += 1;
    if (semanticsActivationAttempts >= kMaxSemanticsActivationAttempts) {
      // We have received multiple user events, none of which resulted in
      // semantics activation. This is a signal that the user is not interested
      // in semantics, and so we will stop waiting for it.
      _schedulePlaceholderRemoval = true;
      return true;
    }

    const List<String> kInterestingEventTypes = <String>[
      'click',
      'touchstart',
      'touchend',
    ];

    if (!kInterestingEventTypes.contains(event.type)) {
      // The event is not relevant, forward to framework as normal.
      return true;
    }

    if (semanticsActivationTimer != null) {
      // We are in a waiting period to activate a timer. While the timer is
      // active we should consume events pertaining to semantics activation.
      // Otherwise the event will also be interpreted by the framework and
      // potentially result in activating a gesture in the app.
      return false;
    }

    // In Chrome the debouncing works well enough to detect accessibility
    // request.
    final bool blinkEnableConditionPassed =
        browserEngine == BrowserEngine.blink &&
            EngineSemanticsOwner.instance.gestureMode ==
                GestureMode.browserGestures;

    // In Safari debouncing doesn't work. Instead we look at where exactly
    // (within 1 pixel) the event landed. If it landed exactly in the middle of
    // the placeholder we interpret it as a signal to enable accessibility. This
    // is because when VoiceOver generates a tap it lands it in the middle of
    // the focused element. This method is a bit flawed in that a user's finger
    // could theoretically land in the middle of the element too. However, the
    // chance of that happening is very small. Even low-end phones typically
    // have >2 million pixels (e.g. Moto G4). It is very unlikely that a user
    // will land their finger exactly in the middle. In the worst case an
    // unlucky user would accidentally enable accessibility and the app will be
    // slightly slower than normal, but the app will continue functioning as
    // normal. Our semantics tree is designed to not interfere with Flutter's
    // gesture detection.
    bool safariEnableConditionPassed = false;
    if (browserEngine == BrowserEngine.webkit) {
      html.Point<num> activationPoint;

      switch (event.type) {
        case 'click':
          final html.MouseEvent click = event;
          activationPoint = click.offset;
          break;
        case 'touchstart':
        case 'touchend':
          final html.TouchEvent touch = event;
          activationPoint = touch.changedTouches.first.client;
          break;
        default:
          // The event is not relevant, forward to framework as normal.
          return true;
      }

      assert(activationPoint != null);

      final html.Rectangle<num> activatingElementRect =
          domRenderer.glassPaneElement.getBoundingClientRect();
      final double midX = activatingElementRect.left +
          (activatingElementRect.right - activatingElementRect.left) / 2;
      final double midY = activatingElementRect.top +
          (activatingElementRect.bottom - activatingElementRect.top) / 2;
      final double deltaX = activationPoint.x - midX;
      final double deltaY = activationPoint.y - midY;
      final double deltaSquared = deltaX * deltaX + deltaY * deltaY;
      if (deltaSquared < 1.0) {
        safariEnableConditionPassed = true;
      }
    }

    if (blinkEnableConditionPassed || safariEnableConditionPassed) {
      assert(semanticsActivationTimer == null);
      semanticsActivationTimer = Timer(const Duration(milliseconds: 300), () {
        EngineSemanticsOwner.instance.semanticsEnabled = true;
        _schedulePlaceholderRemoval = true;
      });
      return false;
    }

    // This was not a semantics activating event; forward as normal.
    return true;
  }

  @override
  html.Element prepareAccesibilityPlaceholder() {
    _semanticsPlaceholder = html.Element.tag('flt-semantics-placeholder');

    // Only listen to "click" because other kinds of events are reported via
    // PointerBinding.
    _semanticsPlaceholder.addEventListener('click', (html.Event event) {
      tryEnableSemantics(event);
    }, true);

    _semanticsPlaceholder
      ..setAttribute('role', 'button')
      ..setAttribute('aria-label', placeholderMessage);
    _semanticsPlaceholder.style
      ..position = 'absolute'
      ..left = '0'
      ..top = '0'
      ..right = '0'
      ..bottom = '0';

    return _semanticsPlaceholder;
  }
}
