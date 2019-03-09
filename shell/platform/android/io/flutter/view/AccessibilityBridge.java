// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.view;

import android.annotation.TargetApi;
import android.app.Activity;
import android.content.ContentResolver;
import android.database.ContentObserver;
import android.graphics.Rect;
import android.net.Uri;
import android.opengl.Matrix;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.provider.Settings;
import android.support.annotation.NonNull;
import android.support.annotation.Nullable;
import android.support.annotation.NonNull;
import android.support.annotation.RequiresApi;
import android.util.Log;
import android.view.MotionEvent;
import android.view.View;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityManager;
import android.view.accessibility.AccessibilityNodeInfo;
import android.view.accessibility.AccessibilityNodeProvider;

import io.flutter.embedding.engine.FlutterJNI;
import io.flutter.embedding.engine.systemchannels.AccessibilityChannel;
import io.flutter.util.Predicate;

import java.nio.ByteBuffer;
import java.util.*;

/**
 * Bridge between Android's OS accessibility system and Flutter's accessibility system.
 *
 * An {@code AccessibilityBridge} requires:
 * <ul>
 *   <li>A real Android {@link View}, called the {@link #rootAccessibilityView}, which contains a
 *   Flutter UI. The {@link #rootAccessibilityView} is required at the time of
 *   {@code AccessibilityBridge}'s instantiation and is held for the duration of
 *   {@code AccessibilityBridge}'s lifespan. {@code AccessibilityBridge} invokes various
 *   accessibility methods on the {@link #rootAccessibilityView}, e.g.,
 *   {@link View#onInitializeAccessibilityNodeInfo(AccessibilityNodeInfo)}. The
 *   {@link #rootAccessibilityView} is expected to notify the {@code AccessibilityBridge} of
 *   relevant interactions: {@link #onAccessibilityHoverEvent(MotionEvent)}, {@link #reset()},
 *   {@link #updateSemantics(ByteBuffer, String[])}, and {@link #updateCustomAccessibilityActions(ByteBuffer, String[])}</li>
 *   <li>A {@link FlutterJNI} instance, corresponding to the running Flutter app.</li>
 *   <li>An {@link AccessibilityChannel} that is connected to the running Flutter app.</li>
 *   <li>Android's {@link AccessibilityManager} to query and listen for accessibility settings.</li>
 *   <li>Android's {@link ContentResolver} to listen for changes to system animation settings.</li>
 * </ul>
 *
 * The {@code AccessibilityBridge} causes Android to treat Flutter {@code SemanticsNode}s as if
 * they were accessible Android {@link View}s. Accessibility requests may be sent from
 * a Flutter widget to the Android OS, as if it were an Android {@link View}, and
 * accessibility events may be consumed by a Flutter widget, as if it were an Android
 * {@link View}. {@code AccessibilityBridge} refers to Flutter's accessible widgets as
 * "virtual views" and identifies them with "virtual view IDs".
 *
 * Most communication between the Android OS accessibility system and Flutter's accessibility
 * system is achieved via the {@link AccessibilityChannel} system channel. However, some
 * information is exchanged directly between the Android embedding and Flutter framework
 * via {@link FlutterJNI}.
 * TODO(mattcarroll): consider moving FlutterJNI calls over to AccessibilityChannel
 */
public class AccessibilityBridge extends AccessibilityNodeProvider {
    private static final String TAG = "AccessibilityBridge";

    // Constants from higher API levels.
    // TODO(goderbauer): Get these from Android Support Library when
    // https://github.com/flutter/flutter/issues/11099 is resolved.
    private static final int ACTION_SHOW_ON_SCREEN = 16908342; // API level 23

    private static final float SCROLL_EXTENT_FOR_INFINITY = 100000.0f;
    private static final float SCROLL_POSITION_CAP_FOR_INFINITY = 70000.0f;
    private static final int ROOT_NODE_ID = 0;

    /// Value is derived from ACTION_TYPE_MASK in AccessibilityNodeInfo.java
    private static int FIRST_RESOURCE_ID = 267386881;

    // Real Android View, which internally holds a Flutter UI.
    @NonNull
    private final View rootAccessibilityView;

    // Direct interface between Flutter's Android embedding and the Flutter framework.
    @NonNull
    private final FlutterJNI flutterJNI;

    // The accessibility communication API between Flutter's Android embedding and
    // the Flutter framework.
    @NonNull
    private final AccessibilityChannel accessibilityChannel;

    // Android's {@link AccessibilityManager}, which we can query to see if accessibility is
    // turned on, as well as listen for changes to accessibility's activation.
    @NonNull
    private final AccessibilityManager accessibilityManager;

    // Android's {@link ContentResolver}, which is used to observe the global TRANSITION_ANIMATION_SCALE,
    // which determines whether Flutter's animations should be enabled or disabled for accessibility
    // purposes.
    @NonNull
    private final ContentResolver contentResolver;

    // The top-level Android View within the containing Window.
    // TODO(mattcarroll): Move communication with the decorView out to FlutterView, or even FlutterActivity.
    //                    The reason this is here is because when the device is in reverse-landscape
    //                    orientation, Android has a bug where it assumes the OS nav bar is on the
    //                    right side of the screen, not the left. As a result, accessibility borders
    //                    are drawn too far to the left. The AccessibilityBridge directly adjusts
    //                    for this Android bug. We still need to adjust, but this is the wrong place
    //                    to access a decorView. What if the FlutterView is only part of the UI
    //                    hierarchy, like a list item? We shouldn't touch the decor view.
    //                    https://github.com/flutter/flutter/issues/19967
    @NonNull
    private final View decorView;

    // The entire Flutter semantics tree of the running Flutter app, stored as a Map
    // from each SemanticsNode's ID to a Java representation of a Flutter SemanticsNode.
    //
    // Flutter's semantics tree is cached here because Android might ask for information about
    // a given SemanticsNode at any moment in time. Caching the tree allows for immediate
    // response to Android's request.
    //
    // The structure of flutterSemanticsTree may be 1 or 2 frames behind the Flutter app
    // due to the time required to communicate tree changes from Flutter to Android.
    //
    // See the Flutter docs on SemanticsNode:
    // https://docs.flutter.io/flutter/semantics/SemanticsNode-class.html
    @NonNull
    private final Map<Integer, SemanticsNode> flutterSemanticsTree = new HashMap<>();

    // The set of all custom Flutter accessibility actions that are present in the running
    // Flutter app, stored as a Map from each action's ID to the definition of the custom accessibility
    // action.
    //
    // Flutter and Android support a number of built-in accessibility actions. However, these
    // predefined actions are not always sufficient for a desired interaction. Android facilitates
    // custom accessibility actions, https://developer.android.com/reference/android/view/accessibility/AccessibilityNodeInfo.AccessibilityAction.
    // Flutter supports custom accessibility actions via {@code customSemanticsActions} within
    // a {@code Semantics} widget, https://docs.flutter.io/flutter/widgets/Semantics-class.html.
    // {@code customAccessibilityActions} are an Android-side cache of all custom accessibility
    // types declared within the running Flutter app.
    //
    // Custom accessibility actions are comprised of only a few fields, and therefore it is likely
    // that a given app may define the same custom accessibility action many times. Identical
    // custom accessibility actions are de-duped such that {@code customAccessibilityActions} only
    // caches unique custom accessibility actions.
    //
    // See the Android documentation for custom accessibility actions:
    // https://developer.android.com/reference/android/view/accessibility/AccessibilityNodeInfo.AccessibilityAction
    //
    // See the Flutter documentation for the Semantics widget:
    // https://docs.flutter.io/flutter/widgets/Semantics-class.html
    @NonNull
    private final Map<Integer, CustomAccessibilityAction> customAccessibilityActions = new HashMap<>();

    // The {@code SemanticsNode} within Flutter that currently has the focus of Android's
    // accessibility system.
    @Nullable
    private SemanticsNode accessibilityFocusedSemanticsNode;

    // The accessibility features that should currently be active within Flutter, represented as
    // a bitmask whose values comes from {@link AccessibilityFeature}.
    private int accessibilityFeatureFlags = 0;

    // The {@code SemanticsNode} within Flutter that currently has the focus of Android's input
    // system.
    //
    // Input focus is independent of accessibility focus. It is possible that accessibility focus
    // and input focus target the same {@code SemanticsNode}, but it is also possible that one
    // {@code SemanticsNode} has input focus while a different {@code SemanticsNode} has
    // accessibility focus. For example, a user may use a D-Pad to navigate to a text field, giving
    // it accessibility focus, and then enable input on that text field, giving it input focus. Then
    // the user moves the accessibility focus to a nearby label to get info about the label, while
    // maintaining input focus on the original text field.
    @Nullable
    private SemanticsNode inputFocusedSemanticsNode;

    // The widget within Flutter that currently sits beneath a cursor, e.g,
    // beneath a stylus or mouse cursor.
    @Nullable
    private SemanticsNode hoveredObject;

    // A Java/Android cached representation of the Flutter app's navigation stack. The Flutter
    // navigation stack is tracked so that accessibility announcements can be made during Flutter's
    // navigation changes.
    // TODO(mattcarroll): take this cache into account for new routing solution so accessibility does
    //                    not get left behind.
    @NonNull
    private final List<Integer> flutterNavigationStack = new ArrayList<>();

    // TODO(mattcarroll): why do we need previouseRouteId if we have flutterNavigationStack
    private int previousRouteId = ROOT_NODE_ID;

    // TODO(mattcarroll): is this for the decor view adjustment?
    @NonNull
    private Integer lastLeftFrameInset = 0;

    @Nullable
    private OnAccessibilityChangeListener onAccessibilityChangeListener;

    // Handler for all messages received from Flutter via the {@code accessibilityChannel}
    private final AccessibilityChannel.AccessibilityMessageHandler accessibilityMessageHandler = new AccessibilityChannel.AccessibilityMessageHandler() {
        /**
         * The Dart application would like the given {@code message} to be announced.
         */
        @Override
        public void announce(@NonNull String message) {
            rootAccessibilityView.announceForAccessibility(message);
        }

        /**
         * The user has tapped on the widget with the given {@code nodeId}.
         */
        @Override
        public void onTap(int nodeId) {
            sendAccessibilityEvent(nodeId, AccessibilityEvent.TYPE_VIEW_CLICKED);
        }

        /**
         * The user has long pressed on the widget with the given {@code nodeId}.
         */
        @Override
        public void onLongPress(int nodeId) {
            sendAccessibilityEvent(nodeId, AccessibilityEvent.TYPE_VIEW_LONG_CLICKED);
        }

        /**
         * The user has opened a tooltip.
         */
        @Override
        public void onTooltip(@NonNull String message) {
            AccessibilityEvent e = obtainAccessibilityEvent(ROOT_NODE_ID, AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED);
            e.getText().add(message);
            sendAccessibilityEvent(e);
        }
    };

    // Listener that is notified when accessibility is turned on/off.
    private final AccessibilityManager.AccessibilityStateChangeListener accessibilityStateChangeListener = new AccessibilityManager.AccessibilityStateChangeListener() {
        @Override
        public void onAccessibilityStateChanged(boolean accessibilityEnabled) {
            if (accessibilityEnabled) {
                accessibilityChannel.setAccessibilityMessageHandler(accessibilityMessageHandler);
                flutterJNI.setSemanticsEnabled(true);
            } else {
                accessibilityChannel.setAccessibilityMessageHandler(null);
                flutterJNI.setSemanticsEnabled(false);
            }

            if (onAccessibilityChangeListener != null) {
                onAccessibilityChangeListener.onAccessibilityChanged(
                    accessibilityEnabled,
                    accessibilityManager.isTouchExplorationEnabled()
                );
            }
        }
    };

    // Listener that is notified when accessibility touch exploration is turned on/off.
    // This is guarded at instantiation time.
    @TargetApi(19)
    @RequiresApi(19)
    private final AccessibilityManager.TouchExplorationStateChangeListener touchExplorationStateChangeListener;

    // Listener that is notified when the global TRANSITION_ANIMATION_SCALE. When this scale goes
    // to zero, we instruct Flutter to disable animations.
    private final ContentObserver animationScaleObserver = new ContentObserver(new Handler()) {
        @Override
        public void onChange(boolean selfChange) {
            this.onChange(selfChange, null);
        }

        @Override
        public void onChange(boolean selfChange, Uri uri) {
            // Retrieve the current value of TRANSITION_ANIMATION_SCALE from the OS.
            String value = Build.VERSION.SDK_INT < Build.VERSION_CODES.JELLY_BEAN_MR1 ? null
                : Settings.Global.getString(
                    contentResolver,
                    Settings.Global.TRANSITION_ANIMATION_SCALE
                );

            boolean shouldAnimationsBeDisabled = value != null && value.equals("0");
            if (shouldAnimationsBeDisabled) {
                accessibilityFeatureFlags |= AccessibilityFeature.DISABLE_ANIMATIONS.value;
            } else {
                accessibilityFeatureFlags &= ~AccessibilityFeature.DISABLE_ANIMATIONS.value;
            }
            sendLatestAccessibilityFlagsToFlutter();
        }
    };

    AccessibilityBridge(
        @NonNull View rootAccessibilityView,
        @NonNull FlutterJNI flutterJNI,
        @NonNull AccessibilityChannel accessibilityChannel,
        @NonNull AccessibilityManager accessibilityManager,
        @NonNull ContentResolver contentResolver
    ) {
        this.rootAccessibilityView = rootAccessibilityView;
        this.flutterJNI = flutterJNI;
        this.accessibilityChannel = accessibilityChannel;
        this.accessibilityManager = accessibilityManager;
        this.contentResolver = contentResolver;

        decorView = ((Activity) rootAccessibilityView.getContext()).getWindow().getDecorView();

        // Tell Flutter whether accessibility is initially active or not. Then register a listener
        // to be notified of changes in the future.
        accessibilityStateChangeListener.onAccessibilityStateChanged(accessibilityManager.isEnabled());
        this.accessibilityManager.addAccessibilityStateChangeListener(accessibilityStateChangeListener);

        // Tell Flutter whether touch exploration is initially active or not. Then register a listener
        // to be notified of changes in the future.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            touchExplorationStateChangeListener.onTouchExplorationStateChanged(accessibilityManager.isTouchExplorationEnabled());
            this.accessibilityManager.addTouchExplorationStateChangeListener(touchExplorationStateChangeListener);
        }

        // Tell Flutter whether animations should initially be enabled or disabled. Then register a
        // listener to be notified of changes in the future.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
            animationScaleObserver.onChange(false);
            Uri transitionUri = Settings.Global.getUriFor(Settings.Global.TRANSITION_ANIMATION_SCALE);
            this.contentResolver.registerContentObserver(transitionUri, false, animationScaleObserver);
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            touchExplorationStateChangeListener = new AccessibilityManager.TouchExplorationStateChangeListener() {
                @Override
                public void onTouchExplorationStateChanged(boolean isTouchExplorationEnabled) {
                    if (isTouchExplorationEnabled) {
                        accessibilityFeatureFlags |= AccessibilityFeature.ACCESSIBLE_NAVIGATION.value;
                    } else {
                        onTouchExplorationExit();
                        accessibilityFeatureFlags &= ~AccessibilityFeature.ACCESSIBLE_NAVIGATION.value;
                    }
                    sendLatestAccessibilityFlagsToFlutter();

                    if (onAccessibilityChangeListener != null) {
                        onAccessibilityChangeListener.onAccessibilityChanged(
                            accessibilityManager.isEnabled(),
                            isTouchExplorationEnabled
                        );
                    }
                }
            };
        }
    }

    /**
     * Disconnects any listeners and/or delegates that were initialized in {@code AccessibilityBridge}'s
     * constructor, or added after.
     *
     * Do not use this instance after invoking {@code release}.  The behavior of any method invoked
     * on this {@code AccessibilityBridge} after invoking {@code release()} is undefined.
     */
    public void release() {
        setOnAccessibilityChangeListener(null);
        accessibilityManager.removeAccessibilityStateChangeListener(accessibilityStateChangeListener);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            accessibilityManager.removeTouchExplorationStateChangeListener(touchExplorationStateChangeListener);
        }
        contentResolver.unregisterContentObserver(animationScaleObserver);
    }

    /**
     * Returns true if the Android OS currently has accessibility enabled, false otherwise.
     */
    public boolean isAccessibilityEnabled() {
        return accessibilityManager.isEnabled();
    }

    /**
     * Returns true if the Android OS currently has touch exploration enabled, false otherwise.
     */
    public boolean isTouchExplorationEnabled() {
        return accessibilityManager.isTouchExplorationEnabled();
    }

    /**
     * Sets a listener on this {@code AccessibilityBridge}, which is notified whenever accessibility
     * activation, or touch exploration activation changes.
     */
    public void setOnAccessibilityChangeListener(@Nullable OnAccessibilityChangeListener listener) {
        this.onAccessibilityChangeListener = listener;
    }

    /**
     * Sends the current value of {@link #accessibilityFeatureFlags} to Flutter via {@link FlutterJNI}.
     */
    private void sendLatestAccessibilityFlagsToFlutter() {
        flutterJNI.setAccessibilityFeatures(accessibilityFeatureFlags);
    }

    private boolean shouldSetCollectionInfo(final SemanticsNode semanticsNode) {
        // TalkBack expects a number of rows and/or columns greater than 0 to announce
        // in list and out of list.  For an infinite or growing list, you have to
        // specify something > 0 to get "in list" announcements.
        // TalkBack will also only track one list at a time, so we only want to set this
        // for a list that contains the current a11y focused semanticsNode - otherwise, if there
        // are two lists or nested lists, we may end up with announcements for only the last
        // one that is currently available in the semantics tree.  However, we also want
        // to set it if we're exiting a list to a non-list, so that we can get the "out of list"
        // announcement when A11y focus moves out of a list and not into another list.
        return semanticsNode.scrollChildren > 0
                && (SemanticsNode.nullableHasAncestor(accessibilityFocusedSemanticsNode, o -> o == semanticsNode)
                    || !SemanticsNode.nullableHasAncestor(accessibilityFocusedSemanticsNode, o -> o.hasFlag(Flag.HAS_IMPLICIT_SCROLLING)));
    }

    /**
     * Returns {@link AccessibilityNodeInfo} for the view corresponding to the given {@code virtualViewId}.
     *
     * This method is invoked by Android's accessibility system when Android needs accessibility info
     * for a given view.
     *
     * When a {@code virtualViewId} of {@link View#NO_ID} is requested, accessibility node info is
     * returned for our {@link #rootAccessibilityView}. Otherwise, Flutter's semantics tree,
     * represented by {@link #flutterSemanticsTree}, is searched for a {@link SemanticsNode} with
     * the given {@code virtualViewId}. If no such {@link SemanticsNode} is found, then this method
     * returns null. If the desired {@link SemanticsNode} is found, then an {@link AccessibilityNodeInfo}
     * is obtained from the {@link #rootAccessibilityView}, filled with appropriate info, and then
     * returned.
     *
     * Depending on the type of Flutter {@code SemanticsNode} that is requested, the returned
     * {@link AccessibilityNodeInfo} pretends that the {@code SemanticsNode} in question comes from
     * a specialize Android view, e.g., {@link Flag#IS_TEXT_FIELD} maps to {@code android.widget.EditText},
     * {@link Flag#IS_BUTTON} maps to {@code android.widget.Button}, and {@link Flag#IS_IMAGE} maps
     * to {@code android.widget.ImageView}. In the case that no specialized view applies, the
     * returned {@link AccessibilityNodeInfo} pretends that it represents a {@code android.view.View}.
     */
    @Override
    @SuppressWarnings("deprecation")
    public AccessibilityNodeInfo createAccessibilityNodeInfo(int virtualViewId) {
        if (virtualViewId == View.NO_ID) {
            AccessibilityNodeInfo result = AccessibilityNodeInfo.obtain(rootAccessibilityView);
            rootAccessibilityView.onInitializeAccessibilityNodeInfo(result);
            // TODO(mattcarroll): what does it mean for the semantics tree to contain or not contain
            //                    the root node ID?
            if (flutterSemanticsTree.containsKey(ROOT_NODE_ID)) {
                result.addChild(rootAccessibilityView, ROOT_NODE_ID);
            }
            return result;
        }

        SemanticsNode semanticsNode = flutterSemanticsTree.get(virtualViewId);
        if (semanticsNode == null) {
            return null;
        }

        AccessibilityNodeInfo result = AccessibilityNodeInfo.obtain(rootAccessibilityView, virtualViewId);
        // Work around for https://github.com/flutter/flutter/issues/2101
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR2) {
            result.setViewIdResourceName("");
        }
        result.setPackageName(rootAccessibilityView.getContext().getPackageName());
        result.setClassName("android.view.View");
        result.setSource(rootAccessibilityView, virtualViewId);
        result.setFocusable(semanticsNode.isFocusable());
        if (inputFocusedSemanticsNode != null) {
            result.setFocused(inputFocusedSemanticsNode.id == virtualViewId);
        }

        if (accessibilityFocusedSemanticsNode != null) {
            result.setAccessibilityFocused(accessibilityFocusedSemanticsNode.id == virtualViewId);
        }

        if (semanticsNode.hasFlag(Flag.IS_TEXT_FIELD)) {
            result.setPassword(semanticsNode.hasFlag(Flag.IS_OBSCURED));
            result.setClassName("android.widget.EditText");
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR2) {
                result.setEditable(true);
                if (semanticsNode.textSelectionBase != -1 && semanticsNode.textSelectionExtent != -1) {
                    result.setTextSelection(semanticsNode.textSelectionBase, semanticsNode.textSelectionExtent);
                }
                // Text fields will always be created as a live region when they have input focus,
                // so that updates to the label trigger polite announcements. This makes it easy to
                // follow a11y guidelines for text fields on Android.
                if (Build.VERSION.SDK_INT > Build.VERSION_CODES.JELLY_BEAN_MR2 && accessibilityFocusedSemanticsNode != null && accessibilityFocusedSemanticsNode.id == virtualViewId) {
                    result.setLiveRegion(View.ACCESSIBILITY_LIVE_REGION_POLITE);
                }
            }

            // Cursor movements
            int granularities = 0;
            if (semanticsNode.hasAction(Action.MOVE_CURSOR_FORWARD_BY_CHARACTER)) {
                result.addAction(AccessibilityNodeInfo.ACTION_NEXT_AT_MOVEMENT_GRANULARITY);
                granularities |= AccessibilityNodeInfo.MOVEMENT_GRANULARITY_CHARACTER;
            }
            if (semanticsNode.hasAction(Action.MOVE_CURSOR_BACKWARD_BY_CHARACTER)) {
                result.addAction(AccessibilityNodeInfo.ACTION_PREVIOUS_AT_MOVEMENT_GRANULARITY);
                granularities |= AccessibilityNodeInfo.MOVEMENT_GRANULARITY_CHARACTER;
            }
            if (semanticsNode.hasAction(Action.MOVE_CURSOR_FORWARD_BY_WORD)) {
                result.addAction(AccessibilityNodeInfo.ACTION_NEXT_AT_MOVEMENT_GRANULARITY);
                granularities |= AccessibilityNodeInfo.MOVEMENT_GRANULARITY_WORD;
            }
            if (semanticsNode.hasAction(Action.MOVE_CURSOR_BACKWARD_BY_WORD)) {
                result.addAction(AccessibilityNodeInfo.ACTION_PREVIOUS_AT_MOVEMENT_GRANULARITY);
                granularities |= AccessibilityNodeInfo.MOVEMENT_GRANULARITY_WORD;
            }
            result.setMovementGranularities(granularities);
        }

        // These are non-ops on older devices. Attempting to interact with the text will cause Talkback to read the
        // contents of the text box instead.
        if (Build.VERSION.SDK_INT > Build.VERSION_CODES.JELLY_BEAN_MR2) {
            if (semanticsNode.hasAction(Action.SET_SELECTION)) {
                result.addAction(AccessibilityNodeInfo.ACTION_SET_SELECTION);
            }
            if (semanticsNode.hasAction(Action.COPY)) {
                result.addAction(AccessibilityNodeInfo.ACTION_COPY);
            }
            if (semanticsNode.hasAction(Action.CUT)) {
                result.addAction(AccessibilityNodeInfo.ACTION_CUT);
            }
            if (semanticsNode.hasAction(Action.PASTE)) {
                result.addAction(AccessibilityNodeInfo.ACTION_PASTE);
            }
        }

        if (semanticsNode.hasFlag(Flag.IS_BUTTON)) {
            result.setClassName("android.widget.Button");
        }
        if (semanticsNode.hasFlag(Flag.IS_IMAGE)) {
            result.setClassName("android.widget.ImageView");
            // TODO(jonahwilliams): Figure out a way conform to the expected id from TalkBack's
            // CustomLabelManager. talkback/src/main/java/labeling/CustomLabelManager.java#L525
        }
        if (Build.VERSION.SDK_INT > Build.VERSION_CODES.JELLY_BEAN_MR2 && semanticsNode.hasAction(Action.DISMISS)) {
            result.setDismissable(true);
            result.addAction(AccessibilityNodeInfo.ACTION_DISMISS);
        }

        if (semanticsNode.parent != null) {
            assert semanticsNode.id > ROOT_NODE_ID;
            result.setParent(rootAccessibilityView, semanticsNode.parent.id);
        } else {
            assert semanticsNode.id == ROOT_NODE_ID;
            result.setParent(rootAccessibilityView);
        }

        Rect bounds = semanticsNode.getGlobalRect();
        if (semanticsNode.parent != null) {
            Rect parentBounds = semanticsNode.parent.getGlobalRect();
            Rect boundsInParent = new Rect(bounds);
            boundsInParent.offset(-parentBounds.left, -parentBounds.top);
            result.setBoundsInParent(boundsInParent);
        } else {
            result.setBoundsInParent(bounds);
        }
        result.setBoundsInScreen(bounds);
        result.setVisibleToUser(true);
        result.setEnabled(
            !semanticsNode.hasFlag(Flag.HAS_ENABLED_STATE) || semanticsNode.hasFlag(Flag.IS_ENABLED)
        );

        if (semanticsNode.hasAction(Action.TAP)) {
            if (Build.VERSION.SDK_INT >= 21 && semanticsNode.onTapOverride != null) {
                result.addAction(new AccessibilityNodeInfo.AccessibilityAction(
                    AccessibilityNodeInfo.ACTION_CLICK,
                    semanticsNode.onTapOverride.hint
                ));
                result.setClickable(true);
            } else {
                result.addAction(AccessibilityNodeInfo.ACTION_CLICK);
                result.setClickable(true);
            }
        }
        if (semanticsNode.hasAction(Action.LONG_PRESS)) {
            if (Build.VERSION.SDK_INT >= 21 && semanticsNode.onLongPressOverride != null) {
                result.addAction(new AccessibilityNodeInfo.AccessibilityAction(
                    AccessibilityNodeInfo.ACTION_LONG_CLICK,
                    semanticsNode.onLongPressOverride.hint
                ));
                result.setLongClickable(true);
            } else {
                result.addAction(AccessibilityNodeInfo.ACTION_LONG_CLICK);
                result.setLongClickable(true);
            }
        }
        if (semanticsNode.hasAction(Action.SCROLL_LEFT) || semanticsNode.hasAction(Action.SCROLL_UP)
                || semanticsNode.hasAction(Action.SCROLL_RIGHT) || semanticsNode.hasAction(Action.SCROLL_DOWN)) {
            result.setScrollable(true);

            // This tells Android's a11y to send scroll events when reaching the end of
            // the visible viewport of a scrollable, unless the node itself does not
            // allow implicit scrolling - then we leave the className as view.View.
            //
            // We should prefer setCollectionInfo to the class names, as this way we get "In List"
            // and "Out of list" announcements.  But we don't always know the counts, so we
            // can fallback to the generic scroll view class names.
            //
            // On older APIs, we always fall back to the generic scroll view class names here.
            //
            // TODO(dnfield): We should add semantics properties for rows and columns in 2 dimensional lists, e.g.
            // GridView.  Right now, we're only supporting ListViews and only if they have scroll children.
            if (semanticsNode.hasFlag(Flag.HAS_IMPLICIT_SCROLLING)) {
                if (semanticsNode.hasAction(Action.SCROLL_LEFT) || semanticsNode.hasAction(Action.SCROLL_RIGHT)) {
                    if (Build.VERSION.SDK_INT > Build.VERSION_CODES.KITKAT && shouldSetCollectionInfo(semanticsNode)) {
                        result.setCollectionInfo(AccessibilityNodeInfo.CollectionInfo.obtain(
                            0, // rows
                            semanticsNode.scrollChildren, // columns
                            false // hierarchical
                        ));
                    } else {
                        result.setClassName("android.widget.HorizontalScrollView");
                    }
                } else {
                    if (Build.VERSION.SDK_INT > Build.VERSION_CODES.JELLY_BEAN_MR2 && shouldSetCollectionInfo(semanticsNode)) {
                        result.setCollectionInfo(AccessibilityNodeInfo.CollectionInfo.obtain(
                            semanticsNode.scrollChildren, // rows
                            0, // columns
                            false // hierarchical
                        ));
                    } else {
                        result.setClassName("android.widget.ScrollView");
                    }
                }
            }
            // TODO(ianh): Once we're on SDK v23+, call addAction to
            // expose AccessibilityAction.ACTION_SCROLL_LEFT, _RIGHT,
            // _UP, and _DOWN when appropriate.
            if (semanticsNode.hasAction(Action.SCROLL_LEFT) || semanticsNode.hasAction(Action.SCROLL_UP)) {
                result.addAction(AccessibilityNodeInfo.ACTION_SCROLL_FORWARD);
            }
            if (semanticsNode.hasAction(Action.SCROLL_RIGHT) || semanticsNode.hasAction(Action.SCROLL_DOWN)) {
                result.addAction(AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD);
            }
        }
        if (semanticsNode.hasAction(Action.INCREASE) || semanticsNode.hasAction(Action.DECREASE)) {
            // TODO(jonahwilliams): support AccessibilityAction.ACTION_SET_PROGRESS once SDK is
            // updated.
            result.setClassName("android.widget.SeekBar");
            if (semanticsNode.hasAction(Action.INCREASE)) {
                result.addAction(AccessibilityNodeInfo.ACTION_SCROLL_FORWARD);
            }
            if (semanticsNode.hasAction(Action.DECREASE)) {
                result.addAction(AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD);
            }
        }
        if (semanticsNode.hasFlag(Flag.IS_LIVE_REGION) && Build.VERSION.SDK_INT > Build.VERSION_CODES.JELLY_BEAN_MR2) {
            result.setLiveRegion(View.ACCESSIBILITY_LIVE_REGION_POLITE);
        }

        boolean hasCheckedState = semanticsNode.hasFlag(Flag.HAS_CHECKED_STATE);
        boolean hasToggledState = semanticsNode.hasFlag(Flag.HAS_TOGGLED_STATE);
        assert !(hasCheckedState && hasToggledState);
        result.setCheckable(hasCheckedState || hasToggledState);
        if (hasCheckedState) {
            result.setChecked(semanticsNode.hasFlag(Flag.IS_CHECKED));
            result.setContentDescription(semanticsNode.getValueLabelHint());
            if (semanticsNode.hasFlag(Flag.IS_IN_MUTUALLY_EXCLUSIVE_GROUP)) {
                result.setClassName("android.widget.RadioButton");
            } else {
                result.setClassName("android.widget.CheckBox");
            }
        } else if (hasToggledState) {
            result.setChecked(semanticsNode.hasFlag(Flag.IS_TOGGLED));
            result.setClassName("android.widget.Switch");
            result.setContentDescription(semanticsNode.getValueLabelHint());
        } else {
            // Setting the text directly instead of the content description
            // will replace the "checked" or "not-checked" label.
            result.setText(semanticsNode.getValueLabelHint());
        }

        result.setSelected(semanticsNode.hasFlag(Flag.IS_SELECTED));

        // Accessibility Focus
        if (accessibilityFocusedSemanticsNode != null && accessibilityFocusedSemanticsNode.id == virtualViewId) {
            result.addAction(AccessibilityNodeInfo.ACTION_CLEAR_ACCESSIBILITY_FOCUS);
        } else {
            result.addAction(AccessibilityNodeInfo.ACTION_ACCESSIBILITY_FOCUS);
        }

        // Actions on the local context menu
        if (Build.VERSION.SDK_INT >= 21) {
            if (semanticsNode.customAccessibilityActions != null) {
                for (CustomAccessibilityAction action : semanticsNode.customAccessibilityActions) {
                    result.addAction(new AccessibilityNodeInfo.AccessibilityAction(
                        action.resourceId,
                        action.label
                    ));
                }
            }
        }

        if (semanticsNode.childrenInTraversalOrder != null) {
            for (SemanticsNode child : semanticsNode.childrenInTraversalOrder) {
                if (!child.hasFlag(Flag.IS_HIDDEN)) {
                    result.addChild(rootAccessibilityView, child.id);
                }
            }
        }

        return result;
    }

    /**
     * Instructs the view represented by {@code virtualViewId} to carry out the desired {@code accessibilityAction},
     * perhaps configured by additional {@code arguments}.
     *
     * This method is invoked by Android's accessibility system. This method returns true if the
     * desired {@code SemanticsNode} was found and was capable of performing the desired action,
     * false otherwise.
     *
     * In a traditional Android app, the given view ID refers to a {@link View} within an Android
     * {@link View} hierarchy. Flutter does not have an Android {@link View} hierarchy, therefore
     * the given view ID is a {@code virtualViewId} that refers to a {@code SemanticsNode} within
     * a Flutter app. The given arguments of this method are forwarded from Android to Flutter
     * via {@link FlutterJNI}.
     */
    @Override
    public boolean performAction(int virtualViewId, int accessibilityAction, @Nullable Bundle arguments) {
        SemanticsNode semanticsNode = flutterSemanticsTree.get(virtualViewId);
        if (semanticsNode == null) {
            return false;
        }
        switch (accessibilityAction) {
            case AccessibilityNodeInfo.ACTION_CLICK: {
                // Note: TalkBack prior to Oreo doesn't use this handler and instead simulates a
                //     click event at the center of the SemanticsNode. Other a11y services might go
                //     through this handler though.
                flutterJNI.dispatchSemanticsAction(virtualViewId, Action.TAP);
                return true;
            }
            case AccessibilityNodeInfo.ACTION_LONG_CLICK: {
                // Note: TalkBack doesn't use this handler and instead simulates a long click event
                //     at the center of the SemanticsNode. Other a11y services might go through this
                //     handler though.
                flutterJNI.dispatchSemanticsAction(virtualViewId, Action.LONG_PRESS);
                return true;
            }
            case AccessibilityNodeInfo.ACTION_SCROLL_FORWARD: {
                if (semanticsNode.hasAction(Action.SCROLL_UP)) {
                    flutterJNI.dispatchSemanticsAction(virtualViewId, Action.SCROLL_UP);
                } else if (semanticsNode.hasAction(Action.SCROLL_LEFT)) {
                    // TODO(ianh): bidi support using textDirection
                    flutterJNI.dispatchSemanticsAction(virtualViewId, Action.SCROLL_LEFT);
                } else if (semanticsNode.hasAction(Action.INCREASE)) {
                    semanticsNode.value = semanticsNode.increasedValue;
                    // Event causes Android to read out the updated value.
                    sendAccessibilityEvent(virtualViewId, AccessibilityEvent.TYPE_VIEW_SELECTED);
                    flutterJNI.dispatchSemanticsAction(virtualViewId, Action.INCREASE);
                } else {
                    return false;
                }
                return true;
            }
            case AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD: {
                if (semanticsNode.hasAction(Action.SCROLL_DOWN)) {
                    flutterJNI.dispatchSemanticsAction(virtualViewId, Action.SCROLL_DOWN);
                } else if (semanticsNode.hasAction(Action.SCROLL_RIGHT)) {
                    // TODO(ianh): bidi support using textDirection
                    flutterJNI.dispatchSemanticsAction(virtualViewId, Action.SCROLL_RIGHT);
                } else if (semanticsNode.hasAction(Action.DECREASE)) {
                    semanticsNode.value = semanticsNode.decreasedValue;
                    // Event causes Android to read out the updated value.
                    sendAccessibilityEvent(virtualViewId, AccessibilityEvent.TYPE_VIEW_SELECTED);
                    flutterJNI.dispatchSemanticsAction(virtualViewId, Action.DECREASE);
                } else {
                    return false;
                }
                return true;
            }
            case AccessibilityNodeInfo.ACTION_PREVIOUS_AT_MOVEMENT_GRANULARITY: {
                // Text selection APIs aren't available until API 18. We can't handle the case here so return false
                // instead. It's extremely unlikely that this case would ever be triggered in the first place in API <
                // 18.
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.JELLY_BEAN_MR2) {
                    return false;
                }
                return performCursorMoveAction(semanticsNode, virtualViewId, arguments, false);
            }
            case AccessibilityNodeInfo.ACTION_NEXT_AT_MOVEMENT_GRANULARITY: {
                // Text selection APIs aren't available until API 18. We can't handle the case here so return false
                // instead. It's extremely unlikely that this case would ever be triggered in the first place in API <
                // 18.
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.JELLY_BEAN_MR2) {
                    return false;
                }
                return performCursorMoveAction(semanticsNode, virtualViewId, arguments, true);
            }
            case AccessibilityNodeInfo.ACTION_CLEAR_ACCESSIBILITY_FOCUS: {
                flutterJNI.dispatchSemanticsAction(
                    virtualViewId,
                    Action.DID_LOSE_ACCESSIBILITY_FOCUS
                );
                sendAccessibilityEvent(
                    virtualViewId,
                    AccessibilityEvent.TYPE_VIEW_ACCESSIBILITY_FOCUS_CLEARED
                );
                accessibilityFocusedSemanticsNode = null;
                return true;
            }
            case AccessibilityNodeInfo.ACTION_ACCESSIBILITY_FOCUS: {
                flutterJNI.dispatchSemanticsAction(
                    virtualViewId,
                    Action.DID_GAIN_ACCESSIBILITY_FOCUS
                );
                sendAccessibilityEvent(
                    virtualViewId,
                    AccessibilityEvent.TYPE_VIEW_ACCESSIBILITY_FOCUSED
                );

                if (accessibilityFocusedSemanticsNode == null) {
                    // When Android focuses a node, it doesn't invalidate the view.
                    // (It does when it sends ACTION_CLEAR_ACCESSIBILITY_FOCUS, so
                    // we only have to worry about this when the focused node is null.)
                    rootAccessibilityView.invalidate();
                }
                accessibilityFocusedSemanticsNode = semanticsNode;

                if (semanticsNode.hasAction(Action.INCREASE) || semanticsNode.hasAction(Action.DECREASE)) {
                    // SeekBars only announce themselves after this event.
                    sendAccessibilityEvent(virtualViewId, AccessibilityEvent.TYPE_VIEW_SELECTED);
                }

                return true;
            }
            case ACTION_SHOW_ON_SCREEN: {
                flutterJNI.dispatchSemanticsAction(virtualViewId, Action.SHOW_ON_SCREEN);
                return true;
            }
            case AccessibilityNodeInfo.ACTION_SET_SELECTION: {
                // Text selection APIs aren't available until API 18. We can't handle the case here so return false
                // instead. It's extremely unlikely that this case would ever be triggered in the first place in API <
                // 18.
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.JELLY_BEAN_MR2) {
                    return false;
                }
                final Map<String, Integer> selection = new HashMap<>();
                final boolean hasSelection = arguments != null
                        && arguments.containsKey(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_START_INT)
                        && arguments.containsKey(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_END_INT);
                if (hasSelection) {
                    selection.put(
                        "base",
                        arguments.getInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_START_INT)
                    );
                    selection.put(
                        "extent",
                        arguments.getInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_END_INT)
                    );
                } else {
                    // Clear the selection
                    selection.put("base", semanticsNode.textSelectionExtent);
                    selection.put("extent", semanticsNode.textSelectionExtent);
                }
                flutterJNI.dispatchSemanticsAction(virtualViewId, Action.SET_SELECTION, selection);
                return true;
            }
            case AccessibilityNodeInfo.ACTION_COPY: {
                flutterJNI.dispatchSemanticsAction(virtualViewId, Action.COPY);
                return true;
            }
            case AccessibilityNodeInfo.ACTION_CUT: {
                flutterJNI.dispatchSemanticsAction(virtualViewId, Action.CUT);
                return true;
            }
            case AccessibilityNodeInfo.ACTION_PASTE: {
                flutterJNI.dispatchSemanticsAction(virtualViewId, Action.PASTE);
                return true;
            }
            case AccessibilityNodeInfo.ACTION_DISMISS: {
                flutterJNI.dispatchSemanticsAction(virtualViewId, Action.DISMISS);
                return true;
            }
            default:
                // might be a custom accessibility accessibilityAction.
                final int flutterId = accessibilityAction - FIRST_RESOURCE_ID;
                CustomAccessibilityAction contextAction = customAccessibilityActions.get(flutterId);
                if (contextAction != null) {
                    flutterJNI.dispatchSemanticsAction(
                        virtualViewId,
                        Action.CUSTOM_ACTION,
                        contextAction.id
                    );
                    return true;
                }
        }
        return false;
    }

    /**
     * Handles the responsibilities of {@link #performAction(int, int, Bundle)} for the specific
     * scenario of cursor movement.
     */
    @TargetApi(18)
    @RequiresApi(18)
    private boolean performCursorMoveAction(
        @NonNull SemanticsNode semanticsNode,
        int virtualViewId,
        @NonNull Bundle arguments,
        boolean forward
    ) {
        final int granularity = arguments.getInt(
            AccessibilityNodeInfo.ACTION_ARGUMENT_MOVEMENT_GRANULARITY_INT
        );
        final boolean extendSelection = arguments.getBoolean(
            AccessibilityNodeInfo.ACTION_ARGUMENT_EXTEND_SELECTION_BOOLEAN
        );
        switch (granularity) {
            case AccessibilityNodeInfo.MOVEMENT_GRANULARITY_CHARACTER: {
                if (forward && semanticsNode.hasAction(Action.MOVE_CURSOR_FORWARD_BY_CHARACTER)) {
                    flutterJNI.dispatchSemanticsAction(
                        virtualViewId,
                        Action.MOVE_CURSOR_FORWARD_BY_CHARACTER,
                        extendSelection
                    );
                    return true;
                }
                if (!forward && semanticsNode.hasAction(Action.MOVE_CURSOR_BACKWARD_BY_CHARACTER)) {
                    flutterJNI.dispatchSemanticsAction(
                        virtualViewId,
                        Action.MOVE_CURSOR_BACKWARD_BY_CHARACTER,
                        extendSelection
                    );
                    return true;
                }
                break;
            }
            case AccessibilityNodeInfo.MOVEMENT_GRANULARITY_WORD:
                if (forward && semanticsNode.hasAction(Action.MOVE_CURSOR_FORWARD_BY_WORD)) {
                    flutterJNI.dispatchSemanticsAction(
                        virtualViewId,
                        Action.MOVE_CURSOR_FORWARD_BY_WORD,
                        extendSelection
                    );
                    return true;
                }
                if (!forward && semanticsNode.hasAction(Action.MOVE_CURSOR_BACKWARD_BY_WORD)) {
                    flutterJNI.dispatchSemanticsAction(
                        virtualViewId,
                        Action.MOVE_CURSOR_BACKWARD_BY_WORD,
                        extendSelection
                    );
                    return true;
                }
                break;
        }
        return false;
    }

    // TODO(ianh): implement findAccessibilityNodeInfosByText()

    /**
     * Finds the view in a hierarchy that currently has the given type of {@code focus}.
     *
     * This method is invoked by Android's accessibility system.
     *
     * Flutter does not have an Android {@link View} hierarchy. Therefore, Flutter conceptually
     * handles this request by searching its semantics tree for the given {@code focus}, represented
     * by {@link #flutterSemanticsTree}. In practice, this {@code AccessibilityBridge} always
     * caches any active {@link #accessibilityFocusedSemanticsNode} and {@link #inputFocusedSemanticsNode}.
     * Therefore, no searching is necessary. This method directly inspects the given {@code focus}
     * type to return one of the cached nodes, null if the cached node is null, or null if a different
     * {@code focus} type is requested.
     */
    @Override
    public AccessibilityNodeInfo findFocus(int focus) {
        switch (focus) {
            case AccessibilityNodeInfo.FOCUS_INPUT: {
                if (inputFocusedSemanticsNode != null) {
                    return createAccessibilityNodeInfo(inputFocusedSemanticsNode.id);
                }
            }
            // Fall through to check FOCUS_ACCESSIBILITY
            case AccessibilityNodeInfo.FOCUS_ACCESSIBILITY: {
                if (accessibilityFocusedSemanticsNode != null) {
                    return createAccessibilityNodeInfo(accessibilityFocusedSemanticsNode.id);
                }
            }
        }
        return null;
    }

    /**
     * Returns the {@link SemanticsNode} at the root of Flutter's semantics tree.
     */
    private SemanticsNode getRootSemanticsNode() {
        assert flutterSemanticsTree.containsKey(0);
        return flutterSemanticsTree.get(0);
    }

    /**
     * Returns an existing {@link SemanticsNode} with the given {@code id}, if it exists within
     * {@link #flutterSemanticsTree}, or creates and returns a new {@link SemanticsNode} with the
     * given {@code id}, adding the new {@link SemanticsNode} to the {@link #flutterSemanticsTree}.
     *
     * This method should only be invoked as a result of receiving new information from Flutter.
     * The {@link #flutterSemanticsTree} is an Android cache of the last known state of a Flutter
     * app's semantics tree, therefore, invoking this method in any other situation will result in
     * a corrupt cache of Flutter's semantics tree.
     */
    private SemanticsNode getOrCreateSemanticsNode(int id) {
        SemanticsNode semanticsNode = flutterSemanticsTree.get(id);
        if (semanticsNode == null) {
            semanticsNode = new SemanticsNode(this);
            semanticsNode.id = id;
            flutterSemanticsTree.put(id, semanticsNode);
        }
        return semanticsNode;
    }

    /**
     * Returns an existing {@link CustomAccessibilityAction} with the given {@code id}, if it exists
     * within {@link #customAccessibilityActions}, or creates and returns a new {@link CustomAccessibilityAction}
     * with the given {@code id}, adding the new {@link CustomAccessibilityAction} to the
     * {@link #customAccessibilityActions}.
     *
     * This method should only be invoked as a result of receiving new information from Flutter.
     * The {@link #customAccessibilityActions} is an Android cache of the last known state of a Flutter
     * app's registered custom accessibility actions, therefore, invoking this method in any other
     * situation will result in a corrupt cache of Flutter's accessibility actions.
     */
    private CustomAccessibilityAction getOrCreateAccessibilityAction(int id) {
        CustomAccessibilityAction action = customAccessibilityActions.get(id);
        if (action == null) {
            action = new CustomAccessibilityAction();
            action.id = id;
            action.resourceId = id + FIRST_RESOURCE_ID;
            customAccessibilityActions.put(id, action);
        }
        return action;
    }

    /**
     * A hover {@link MotionEvent} has occurred in the {@code View} that corresponds to this
     * {@code AccessibilityBridge}.
     *
     * This method returns true if Flutter's accessibility system handled the hover event, false
     * otherwise.
     *
     * This method should be invoked from the corresponding {@code View}'s
     * {@link View#onHoverEvent(MotionEvent)}.
     */
    public boolean onAccessibilityHoverEvent(MotionEvent event) {
        if (!accessibilityManager.isTouchExplorationEnabled()) {
            return false;
        }

        if (event.getAction() == MotionEvent.ACTION_HOVER_ENTER || event.getAction() == MotionEvent.ACTION_HOVER_MOVE) {
            handleTouchExploration(event.getX(), event.getY());
        } else if (event.getAction() == MotionEvent.ACTION_HOVER_EXIT) {
            onTouchExplorationExit();
        } else {
            Log.d("flutter", "unexpected accessibility hover event: " + event);
            return false;
        }
        return true;
    }

    /**
     * This method should be invoked when a hover interaction has the cursor move off of a
     * {@code SemanticsNode}.
     *
     * This method informs the Android accessibility system that a {@link AccessibilityEvent#TYPE_VIEW_HOVER_EXIT}
     * has occurred.
     */
    private void onTouchExplorationExit() {
        if (hoveredObject != null) {
            sendAccessibilityEvent(hoveredObject.id, AccessibilityEvent.TYPE_VIEW_HOVER_EXIT);
            hoveredObject = null;
        }
    }

    /**
     * This method should be invoked when a new hover interaction begins with a {@code SemanticsNode},
     * or when an existing hover interaction sees a movement of the cursor.
     *
     * This method checks to see if the cursor has moved from one {@code SemanticsNode} to another.
     * If it has, this method informs the Android accessibility system of the change by first sending
     * a {@link AccessibilityEvent#TYPE_VIEW_HOVER_ENTER} event for the new hover node, followed by
     * a {@link AccessibilityEvent#TYPE_VIEW_HOVER_EXIT} event for the old hover node.
     */
    private void handleTouchExploration(float x, float y) {
        if (flutterSemanticsTree.isEmpty()) {
            return;
        }
        SemanticsNode semanticsNodeUnderCursor = getRootSemanticsNode().hitTest(new float[] {x, y, 0, 1});
        if (semanticsNodeUnderCursor != hoveredObject) {
            // sending ENTER before EXIT is how Android wants it
            if (semanticsNodeUnderCursor != null) {
                sendAccessibilityEvent(semanticsNodeUnderCursor.id, AccessibilityEvent.TYPE_VIEW_HOVER_ENTER);
            }
            if (hoveredObject != null) {
                sendAccessibilityEvent(hoveredObject.id, AccessibilityEvent.TYPE_VIEW_HOVER_EXIT);
            }
            hoveredObject = semanticsNodeUnderCursor;
        }
    }

    /**
     * Updates the Android cache of Flutter's currently registered custom accessibility actions.
     */
    // TODO(mattcarroll): Consider introducing ability to delete custom actions because they can
    //                    probably come and go in Flutter, so we may want to reflect that here in
    //                    the Android cache as well.
    // TODO(mattcarroll): where is the encoding code for reference?
    void updateCustomAccessibilityActions(@NonNull ByteBuffer buffer, @NonNull String[] strings) {
        while (buffer.hasRemaining()) {
            int id = buffer.getInt();
            CustomAccessibilityAction action = getOrCreateAccessibilityAction(id);
            action.overrideId = buffer.getInt();
            int stringIndex = buffer.getInt();
            action.label = stringIndex == -1 ? null : strings[stringIndex];
            stringIndex = buffer.getInt();
            action.hint = stringIndex == -1 ? null : strings[stringIndex];
        }
    }

    /**
     * Updates {@link #flutterSemanticsTree} to reflect the latest state of Flutter's semantics tree.
     *
     * The latest state of Flutter's semantics tree is encoded in the given {@code buffer}.
     */
    // TODO(mattcarroll): where is the encoding code for reference?
    void updateSemantics(@NonNull ByteBuffer buffer, @NonNull String[] strings) {
        ArrayList<SemanticsNode> updated = new ArrayList<>();
        while (buffer.hasRemaining()) {
            int id = buffer.getInt();
            SemanticsNode semanticsNode = getOrCreateSemanticsNode(id);
            semanticsNode.updateWith(buffer, strings);
            if (semanticsNode.hasFlag(Flag.IS_HIDDEN)) {
                continue;
            }
            if (semanticsNode.hasFlag(Flag.IS_FOCUSED)) {
                inputFocusedSemanticsNode = semanticsNode;
            }
            if (semanticsNode.hadPreviousConfig) {
                updated.add(semanticsNode);
            }
        }

        Set<SemanticsNode> visitedObjects = new HashSet<>();
        SemanticsNode rootObject = getRootSemanticsNode();
        List<SemanticsNode> newRoutes = new ArrayList<>();
        if (rootObject != null) {
            final float[] identity = new float[16];
            Matrix.setIdentityM(identity, 0);
            // in android devices API 23 and above, the system nav bar can be placed on the left side
            // of the screen in landscape mode. We must handle the translation ourselves for the
            // a11y nodes.
            if (Build.VERSION.SDK_INT >= 23) {
                Rect visibleFrame = new Rect();
                decorView.getWindowVisibleDisplayFrame(visibleFrame);
                if (!lastLeftFrameInset.equals(visibleFrame.left)) {
                    rootObject.globalGeometryDirty = true;
                    rootObject.inverseTransformDirty = true;
                }
                lastLeftFrameInset = visibleFrame.left;
                Matrix.translateM(identity, 0, visibleFrame.left, 0, 0);
            }
            rootObject.updateRecursively(identity, visitedObjects, false);
            rootObject.collectRoutes(newRoutes);
        }

        // Dispatch a TYPE_WINDOW_STATE_CHANGED event if the most recent route id changed from the
        // previously cached route id.
        SemanticsNode lastAdded = null;
        for (SemanticsNode semanticsNode : newRoutes) {
            if (!flutterNavigationStack.contains(semanticsNode.id)) {
                lastAdded = semanticsNode;
            }
        }
        if (lastAdded == null && newRoutes.size() > 0) {
            lastAdded = newRoutes.get(newRoutes.size() - 1);
        }
        if (lastAdded != null && lastAdded.id != previousRouteId) {
            previousRouteId = lastAdded.id;
            createAndSendWindowChangeEvent(lastAdded);
        }
        flutterNavigationStack.clear();
        for (SemanticsNode semanticsNode : newRoutes) {
            flutterNavigationStack.add(semanticsNode.id);
        }

        Iterator<Map.Entry<Integer, SemanticsNode>> it = flutterSemanticsTree.entrySet().iterator();
        while (it.hasNext()) {
            Map.Entry<Integer, SemanticsNode> entry = it.next();
            SemanticsNode object = entry.getValue();
            if (!visitedObjects.contains(object)) {
                willRemoveSemanticsNode(object);
                it.remove();
            }
        }

        // TODO(goderbauer): Send this event only once (!) for changed subtrees,
        //     see https://github.com/flutter/flutter/issues/14534
        sendAccessibilityEvent(0, AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED);

        for (SemanticsNode object : updated) {
            if (object.didScroll()) {
                AccessibilityEvent event =
                        obtainAccessibilityEvent(object.id, AccessibilityEvent.TYPE_VIEW_SCROLLED);

                // Android doesn't support unbound scrolling. So we pretend there is a large
                // bound (SCROLL_EXTENT_FOR_INFINITY), which you can never reach.
                float position = object.scrollPosition;
                float max = object.scrollExtentMax;
                if (Float.isInfinite(object.scrollExtentMax)) {
                    max = SCROLL_EXTENT_FOR_INFINITY;
                    if (position > SCROLL_POSITION_CAP_FOR_INFINITY) {
                        position = SCROLL_POSITION_CAP_FOR_INFINITY;
                    }
                }
                if (Float.isInfinite(object.scrollExtentMin)) {
                    max += SCROLL_EXTENT_FOR_INFINITY;
                    if (position < -SCROLL_POSITION_CAP_FOR_INFINITY) {
                        position = -SCROLL_POSITION_CAP_FOR_INFINITY;
                    }
                    position += SCROLL_EXTENT_FOR_INFINITY;
                } else {
                    max -= object.scrollExtentMin;
                    position -= object.scrollExtentMin;
                }

                if (object.hadAction(Action.SCROLL_UP) || object.hadAction(Action.SCROLL_DOWN)) {
                    event.setScrollY((int) position);
                    event.setMaxScrollY((int) max);
                } else if (object.hadAction(Action.SCROLL_LEFT)
                        || object.hadAction(Action.SCROLL_RIGHT)) {
                    event.setScrollX((int) position);
                    event.setMaxScrollX((int) max);
                }
                if (object.scrollChildren > 0) {
                    // We don't need to add 1 to the scroll index because TalkBack does this automagically.
                    event.setItemCount(object.scrollChildren);
                    event.setFromIndex(object.scrollIndex);
                    int visibleChildren = 0;
                    // handle hidden children at the beginning and end of the list.
                    for (SemanticsNode child : object.childrenInHitTestOrder) {
                        if (!child.hasFlag(Flag.IS_HIDDEN)) {
                            visibleChildren += 1;
                        }
                    }
                    assert(object.scrollIndex + visibleChildren <= object.scrollChildren);
                    assert(!object.childrenInHitTestOrder.get(object.scrollIndex).hasFlag(Flag.IS_HIDDEN));
                    // The setToIndex should be the index of the last visible child. Because we counted all
                    // children, including the first index we need to subtract one.
                    //
                    //   [0, 1, 2, 3, 4, 5]
                    //    ^     ^
                    // In the example above where 0 is the first visible index and 2 is the last, we will
                    // count 3 total visible children. We then subtract one to get the correct last visible
                    // index of 2.
                    event.setToIndex(object.scrollIndex + visibleChildren - 1);
                }
                sendAccessibilityEvent(event);
            }
            if (object.hasFlag(Flag.IS_LIVE_REGION)) {
                String label = object.label == null ? "" : object.label;
                String previousLabel = object.previousLabel == null ? "" : object.label;
                if (!label.equals(previousLabel) || !object.hadFlag(Flag.IS_LIVE_REGION)) {
                    sendAccessibilityEvent(object.id, AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED);
                }
            } else if (object.hasFlag(Flag.IS_TEXT_FIELD) && object.didChangeLabel()
                    && inputFocusedSemanticsNode != null && inputFocusedSemanticsNode.id == object.id) {
                // Text fields should announce when their label changes while focused. We use a live
                // region tag to do so, and this event triggers that update.
                sendAccessibilityEvent(object.id, AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED);
            }
            if (accessibilityFocusedSemanticsNode != null && accessibilityFocusedSemanticsNode.id == object.id
                    && !object.hadFlag(Flag.IS_SELECTED) && object.hasFlag(Flag.IS_SELECTED)) {
                AccessibilityEvent event =
                        obtainAccessibilityEvent(object.id, AccessibilityEvent.TYPE_VIEW_SELECTED);
                event.getText().add(object.label);
                sendAccessibilityEvent(event);
            }
            if (inputFocusedSemanticsNode != null && inputFocusedSemanticsNode.id == object.id
                    && object.hadFlag(Flag.IS_TEXT_FIELD) && object.hasFlag(Flag.IS_TEXT_FIELD)
                    // If we have a TextField that has InputFocus, we should avoid announcing it if something
                    // else we track has a11y focus. This needs to still work when, e.g., IME has a11y focus
                    // or the "PASTE" popup is used though.
                    // See more discussion at https://github.com/flutter/flutter/issues/23180
                    && (accessibilityFocusedSemanticsNode == null || (accessibilityFocusedSemanticsNode.id == inputFocusedSemanticsNode.id))) {
                String oldValue = object.previousValue != null ? object.previousValue : "";
                String newValue = object.value != null ? object.value : "";
                AccessibilityEvent event = createTextChangedEvent(object.id, oldValue, newValue);
                if (event != null) {
                    sendAccessibilityEvent(event);
                }

                if (object.previousTextSelectionBase != object.textSelectionBase
                        || object.previousTextSelectionExtent != object.textSelectionExtent) {
                    AccessibilityEvent selectionEvent = obtainAccessibilityEvent(
                            object.id, AccessibilityEvent.TYPE_VIEW_TEXT_SELECTION_CHANGED);
                    selectionEvent.getText().add(newValue);
                    selectionEvent.setFromIndex(object.textSelectionBase);
                    selectionEvent.setToIndex(object.textSelectionExtent);
                    selectionEvent.setItemCount(newValue.length());
                    sendAccessibilityEvent(selectionEvent);
                }
            }
        }
    }

    private AccessibilityEvent createTextChangedEvent(int id, String oldValue, String newValue) {
        AccessibilityEvent e =
                obtainAccessibilityEvent(id, AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED);
        e.setBeforeText(oldValue);
        e.getText().add(newValue);

        int i;
        for (i = 0; i < oldValue.length() && i < newValue.length(); ++i) {
            if (oldValue.charAt(i) != newValue.charAt(i)) {
                break;
            }
        }
        if (i >= oldValue.length() && i >= newValue.length()) {
            return null; // Text did not change
        }
        int firstDifference = i;
        e.setFromIndex(firstDifference);

        int oldIndex = oldValue.length() - 1;
        int newIndex = newValue.length() - 1;
        while (oldIndex >= firstDifference && newIndex >= firstDifference) {
            if (oldValue.charAt(oldIndex) != newValue.charAt(newIndex)) {
                break;
            }
            --oldIndex;
            --newIndex;
        }
        e.setRemovedCount(oldIndex - firstDifference + 1);
        e.setAddedCount(newIndex - firstDifference + 1);

        return e;
    }

    /**
     * Sends an accessibility event of the given {@code eventType} to Android's accessibility
     * system with the given {@code viewId} represented as the source of the event.
     *
     * The given {@code viewId} may either belong to {@link #rootAccessibilityView}, or any
     * Flutter {@link SemanticsNode}.
     */
    private void sendAccessibilityEvent(int viewId, int eventType) {
        if (!accessibilityManager.isEnabled()) {
            return;
        }
        if (viewId == ROOT_NODE_ID) {
            rootAccessibilityView.sendAccessibilityEvent(eventType);
        } else {
            sendAccessibilityEvent(obtainAccessibilityEvent(viewId, eventType));
        }
    }

    /**
     * Sends the given {@link AccessibilityEvent} to Android's accessibility system for a given
     * Flutter {@link SemanticsNode}.
     *
     * This method should only be called for a Flutter {@link SemanticsNode}, not a traditional
     * Android {@code View}, i.e., {@link #rootAccessibilityView}.
     */
    private void sendAccessibilityEvent(@NonNull AccessibilityEvent event) {
        if (!accessibilityManager.isEnabled()) {
            return;
        }
        // TODO(mattcarroll): why are we explicitly talking to the root view's parent?
        rootAccessibilityView.getParent().requestSendAccessibilityEvent(rootAccessibilityView, event);
    }

    /**
     * Factory method that creates a {@link AccessibilityEvent#TYPE_WINDOW_STATE_CHANGED} and sends
     * the event to Android's accessibility system.
     *
     * The given {@code route} should be a {@link SemanticsNode} that represents a navigation route
     * in the Flutter app.
     */
    private void createAndSendWindowChangeEvent(@NonNull SemanticsNode route) {
        AccessibilityEvent event = obtainAccessibilityEvent(
            route.id,
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
        );
        String routeName = route.getRouteName();
        event.getText().add(routeName);
        sendAccessibilityEvent(event);
    }

    /**
     * Factory method that creates a new {@link AccessibilityEvent} that is configured to represent
     * the Flutter {@link SemanticsNode} represented by the given {@code virtualViewId}, categorized
     * as the given {@code eventType}.
     *
     * This method should *only* be called for Flutter {@link SemanticsNode}s. It should *not* be
     * invoked to create an {@link AccessibilityEvent} for the {@link #rootAccessibilityView}.
     */
    private AccessibilityEvent obtainAccessibilityEvent(int virtualViewId, int eventType) {
        assert virtualViewId != ROOT_NODE_ID;
        AccessibilityEvent event = AccessibilityEvent.obtain(eventType);
        event.setPackageName(rootAccessibilityView.getContext().getPackageName());
        event.setSource(rootAccessibilityView, virtualViewId);
        return event;
    }

    /**
     * Hook called just before a {@link SemanticsNode} is removed from the Android cache of Flutter's
     * semantics tree.
     */
    private void willRemoveSemanticsNode(SemanticsNode semanticsNodeToBeRemoved) {
        assert flutterSemanticsTree.containsKey(semanticsNodeToBeRemoved.id);
        assert flutterSemanticsTree.get(semanticsNodeToBeRemoved.id) == semanticsNodeToBeRemoved;
        // TODO(mattcarroll): should parent be set to "null" here? Changing the parent seems like the
        //                    behavior of a method called "removeSemanticsNode()". The same is true
        //                    for null'ing accessibilityFocusedSemanticsNode, inputFocusedSemanticsNode,
        //                    and hoveredObject.  Is this a hook method or a command?
        semanticsNodeToBeRemoved.parent = null;
        if (accessibilityFocusedSemanticsNode == semanticsNodeToBeRemoved) {
            sendAccessibilityEvent(
                accessibilityFocusedSemanticsNode.id,
                AccessibilityEvent.TYPE_VIEW_ACCESSIBILITY_FOCUS_CLEARED
            );
            accessibilityFocusedSemanticsNode = null;
        }
        if (inputFocusedSemanticsNode == semanticsNodeToBeRemoved) {
            inputFocusedSemanticsNode = null;
        }
        if (hoveredObject == semanticsNodeToBeRemoved) {
            hoveredObject = null;
        }
    }

    /**
     * Resets the {@code AccessibilityBridge}:
     * <ul>
     *   <li>Clears {@link #flutterSemanticsTree}, the Android cache of Flutter's semantics tree</li>
     *   <li>Releases focus on any active {@link #accessibilityFocusedSemanticsNode}</li>
     *   <li>Clears any hovered {@code SemanticsNode}</li>
     *   <li>Sends a {@link AccessibilityEvent#TYPE_WINDOW_CONTENT_CHANGED} event</li>
     * </ul>
     */
    // TODO(mattcarroll): under what conditions is this method expected to be invoked?
    public void reset() {
        flutterSemanticsTree.clear();
        if (accessibilityFocusedSemanticsNode != null) {
            sendAccessibilityEvent(
                accessibilityFocusedSemanticsNode.id,
                AccessibilityEvent.TYPE_VIEW_ACCESSIBILITY_FOCUS_CLEARED
            );
        }
        accessibilityFocusedSemanticsNode = null;
        hoveredObject = null;
        sendAccessibilityEvent(0, AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED);
    }

    /**
     * Listener that can be set on a {@link AccessibilityBridge}, which is invoked any time
     * accessibility is turned on/off, or touch exploration is turned on/off.
     */
    public interface OnAccessibilityChangeListener {
        void onAccessibilityChanged(boolean isAccessibilityEnabled, boolean isTouchExplorationEnabled);
    }

    // Must match SemanticsActions in semantics.dart
    // https://github.com/flutter/engine/blob/master/lib/ui/semantics.dart
    public enum Action {
        TAP(1 << 0),
        LONG_PRESS(1 << 1),
        SCROLL_LEFT(1 << 2),
        SCROLL_RIGHT(1 << 3),
        SCROLL_UP(1 << 4),
        SCROLL_DOWN(1 << 5),
        INCREASE(1 << 6),
        DECREASE(1 << 7),
        SHOW_ON_SCREEN(1 << 8),
        MOVE_CURSOR_FORWARD_BY_CHARACTER(1 << 9),
        MOVE_CURSOR_BACKWARD_BY_CHARACTER(1 << 10),
        SET_SELECTION(1 << 11),
        COPY(1 << 12),
        CUT(1 << 13),
        PASTE(1 << 14),
        DID_GAIN_ACCESSIBILITY_FOCUS(1 << 15),
        DID_LOSE_ACCESSIBILITY_FOCUS(1 << 16),
        CUSTOM_ACTION(1 << 17),
        DISMISS(1 << 18),
        MOVE_CURSOR_FORWARD_BY_WORD(1 << 19),
        MOVE_CURSOR_BACKWARD_BY_WORD(1 << 20);

        public final int value;

        Action(int value) {
            this.value = value;
        }
    }

    // Must match SemanticsFlag in semantics.dart
    // https://github.com/flutter/engine/blob/master/lib/ui/semantics.dart
    private enum Flag {
        HAS_CHECKED_STATE(1 << 0),
        IS_CHECKED(1 << 1),
        IS_SELECTED(1 << 2),
        IS_BUTTON(1 << 3),
        IS_TEXT_FIELD(1 << 4),
        IS_FOCUSED(1 << 5),
        HAS_ENABLED_STATE(1 << 6),
        IS_ENABLED(1 << 7),
        IS_IN_MUTUALLY_EXCLUSIVE_GROUP(1 << 8),
        IS_HEADER(1 << 9),
        IS_OBSCURED(1 << 10),
        SCOPES_ROUTE(1 << 11),
        NAMES_ROUTE(1 << 12),
        IS_HIDDEN(1 << 13),
        IS_IMAGE(1 << 14),
        IS_LIVE_REGION(1 << 15),
        HAS_TOGGLED_STATE(1 << 16),
        IS_TOGGLED(1 << 17),
        HAS_IMPLICIT_SCROLLING(1 << 18);

        final int value;

        Flag(int value) {
            this.value = value;
        }
    }

    // Must match the enum defined in window.dart.
    private enum AccessibilityFeature {
        ACCESSIBLE_NAVIGATION(1 << 0),
        INVERT_COLORS(1 << 1), // NOT SUPPORTED
        DISABLE_ANIMATIONS(1 << 2);

        final int value;

        AccessibilityFeature(int value) {
            this.value = value;
        }
    }

    private enum TextDirection {
        UNKNOWN,
        LTR,
        RTL;

        public static TextDirection fromInt(int value) {
            switch (value) {
                case 1:
                    return RTL;
                case 2:
                    return LTR;
            }
            return UNKNOWN;
        }
    }

    /**
     * Accessibility action that is defined within a given Flutter application, as opposed to the
     * standard accessibility actions that are available in the Flutter framework.
     *
     * Flutter and Android support a number of built-in accessibility actions. However, these
     * predefined actions are not always sufficient for a desired interaction. Android facilitates
     * custom accessibility actions, https://developer.android.com/reference/android/view/accessibility/AccessibilityNodeInfo.AccessibilityAction.
     * Flutter supports custom accessibility actions via {@code customSemanticsActions} within
     * a {@code Semantics} widget, https://docs.flutter.io/flutter/widgets/Semantics-class.html.
     *
     * See the Android documentation for custom accessibility actions:
     * https://developer.android.com/reference/android/view/accessibility/AccessibilityNodeInfo.AccessibilityAction
     *
     * See the Flutter documentation for the Semantics widget:
     * https://docs.flutter.io/flutter/widgets/Semantics-class.html
     */
    private static class CustomAccessibilityAction {
        CustomAccessibilityAction() {}

        // The ID of the custom action plus a minimum value so that the identifier
        // does not collide with existing Android accessibility actions. This ID
        // represents and Android resource ID, not a Flutter ID.
        private int resourceId = -1;

        // The Flutter ID of this custom accessibility action. See Flutter's Semantics widget for
        // custom accessibility action definitions: https://docs.flutter.io/flutter/widgets/Semantics-class.html
        private int id = -1;

        // The ID of the standard Flutter accessibility action that this {@code CustomAccessibilityAction}
        // overrides with a custom {@code label} and/or {@code hint}.
        private int overrideId = -1;

        // The user presented value which is displayed in the local context menu.
        private String label;

        // The text used in overridden standard actions.
        private String hint;
    }

    /**
     * Flutter {@code SemanticsNode} represented in Java/Android.
     *
     * Flutter maintains a semantics tree that is controlled by, but is independent of Flutter's
     * element tree, i.e., widgets/elements/render objects. Flutter's semantics tree must be cached
     * on the Android side so that Android can query any {@code SemanticsNode} at any time. This
     * class represents a single node in the semantics tree, and it is a Java representation of the
     * analogous concept within Flutter.
     *
     * To see how this {@code SemanticsNode}'s fields correspond to Flutter's semantics system, see
     * semantics.dart: https://github.com/flutter/engine/blob/master/lib/ui/semantics.dart
     */
    private static class SemanticsNode {
        private static boolean nullableHasAncestor(SemanticsNode target, Predicate<SemanticsNode> tester) {
            return target != null && target.getAncestor(tester) != null;
        }

        final AccessibilityBridge accessibilityBridge;

        // Flutter ID of this {@code SemanticsNode}.
        private int id = -1;

        private int flags;
        private int actions;
        private int textSelectionBase;
        private int textSelectionExtent;
        private int scrollChildren;
        private int scrollIndex;
        private float scrollPosition;
        private float scrollExtentMax;
        private float scrollExtentMin;
        private String label;
        private String value;
        private String increasedValue;
        private String decreasedValue;
        private String hint;

        // See Flutter's {@code SemanticsNode#textDirection}.
        private TextDirection textDirection;

        private boolean hadPreviousConfig = false;
        private int previousFlags;
        private int previousActions;
        private int previousTextSelectionBase;
        private int previousTextSelectionExtent;
        private float previousScrollPosition;
        private float previousScrollExtentMax;
        private float previousScrollExtentMin;
        private String previousValue;
        private String previousLabel;

        private float left;
        private float top;
        private float right;
        private float bottom;
        private float[] transform;

        private SemanticsNode parent;
        private List<SemanticsNode> childrenInTraversalOrder;
        private List<SemanticsNode> childrenInHitTestOrder;
        private List<CustomAccessibilityAction> customAccessibilityActions;
        private CustomAccessibilityAction onTapOverride;
        private CustomAccessibilityAction onLongPressOverride;

        private boolean inverseTransformDirty = true;
        private float[] inverseTransform;

        private boolean globalGeometryDirty = true;
        private float[] globalTransform;
        private Rect globalRect;

        SemanticsNode(@NonNull AccessibilityBridge accessibilityBridge) {
            this.accessibilityBridge = accessibilityBridge;
        }

        /**
         * Returns the ancestor of this {@code SemanticsNode} for which {@link Predicate#test(Object)}
         * returns true, or null if no such ancestor exists.
         */
        private SemanticsNode getAncestor(Predicate<SemanticsNode> tester) {
            SemanticsNode nextAncestor = parent;
            while (nextAncestor != null) {
                if (tester.test(nextAncestor)) {
                    return nextAncestor;
                }
                nextAncestor = nextAncestor.parent;
            }
            return null;
        }

        /**
         * Returns true if the given {@code action} is supported by this {@code SemanticsNode}.
         *
         * This method only applies to this {@code SemanticsNode} and does not implicitly search
         * its children.
         */
        private boolean hasAction(@NonNull Action action) {
            return (actions & action.value) != 0;
        }

        /**
         * Returns true if the given {@code action} was supported by the immediately previous
         * version of this {@code SemanticsNode}.
         */
        private boolean hadAction(@NonNull Action action) {
            return (previousActions & action.value) != 0;
        }

        private boolean hasFlag(@NonNull Flag flag) {
            return (flags & flag.value) != 0;
        }

        private boolean hadFlag(@NonNull Flag flag) {
            assert hadPreviousConfig;
            return (previousFlags & flag.value) != 0;
        }

        private boolean didScroll() {
            return !Float.isNaN(scrollPosition) && !Float.isNaN(previousScrollPosition)
                    && previousScrollPosition != scrollPosition;
        }

        private boolean didChangeLabel() {
            if (label == null && previousLabel == null) {
                return false;
            }
            return label == null || previousLabel == null || !label.equals(previousLabel);
        }

        private void log(@NonNull String indent, boolean recursive) {
            Log.i(TAG,
                    indent + "SemanticsNode id=" + id + " label=" + label + " actions=" + actions
                            + " flags=" + flags + "\n" + indent + "  +-- textDirection="
                            + textDirection + "\n" + indent + "  +-- rect.ltrb=(" + left + ", "
                            + top + ", " + right + ", " + bottom + ")\n" + indent
                            + "  +-- transform=" + Arrays.toString(transform) + "\n");
            if (childrenInTraversalOrder != null && recursive) {
                String childIndent = indent + "  ";
                for (SemanticsNode child : childrenInTraversalOrder) {
                    child.log(childIndent, recursive);
                }
            }
        }

        private void updateWith(@NonNull ByteBuffer buffer, @NonNull String[] strings) {
            hadPreviousConfig = true;
            previousValue = value;
            previousLabel = label;
            previousFlags = flags;
            previousActions = actions;
            previousTextSelectionBase = textSelectionBase;
            previousTextSelectionExtent = textSelectionExtent;
            previousScrollPosition = scrollPosition;
            previousScrollExtentMax = scrollExtentMax;
            previousScrollExtentMin = scrollExtentMin;

            flags = buffer.getInt();
            actions = buffer.getInt();
            textSelectionBase = buffer.getInt();
            textSelectionExtent = buffer.getInt();
            scrollChildren = buffer.getInt();
            scrollIndex = buffer.getInt();
            scrollPosition = buffer.getFloat();
            scrollExtentMax = buffer.getFloat();
            scrollExtentMin = buffer.getFloat();

            int stringIndex = buffer.getInt();
            label = stringIndex == -1 ? null : strings[stringIndex];

            stringIndex = buffer.getInt();
            value = stringIndex == -1 ? null : strings[stringIndex];

            stringIndex = buffer.getInt();
            increasedValue = stringIndex == -1 ? null : strings[stringIndex];

            stringIndex = buffer.getInt();
            decreasedValue = stringIndex == -1 ? null : strings[stringIndex];

            stringIndex = buffer.getInt();
            hint = stringIndex == -1 ? null : strings[stringIndex];

            textDirection = TextDirection.fromInt(buffer.getInt());

            left = buffer.getFloat();
            top = buffer.getFloat();
            right = buffer.getFloat();
            bottom = buffer.getFloat();

            if (transform == null) {
                transform = new float[16];
            }
            for (int i = 0; i < 16; ++i) {
                transform[i] = buffer.getFloat();
            }
            inverseTransformDirty = true;
            globalGeometryDirty = true;

            final int childCount = buffer.getInt();
            if (childCount == 0) {
                childrenInTraversalOrder = null;
                childrenInHitTestOrder = null;
            } else {
                if (childrenInTraversalOrder == null)
                    childrenInTraversalOrder = new ArrayList<>(childCount);
                else
                    childrenInTraversalOrder.clear();

                for (int i = 0; i < childCount; ++i) {
                    SemanticsNode child = accessibilityBridge.getOrCreateSemanticsNode(buffer.getInt());
                    child.parent = this;
                    childrenInTraversalOrder.add(child);
                }

                if (childrenInHitTestOrder == null)
                    childrenInHitTestOrder = new ArrayList<>(childCount);
                else
                    childrenInHitTestOrder.clear();

                for (int i = 0; i < childCount; ++i) {
                    SemanticsNode child = accessibilityBridge.getOrCreateSemanticsNode(buffer.getInt());
                    child.parent = this;
                    childrenInHitTestOrder.add(child);
                }
            }
            final int actionCount = buffer.getInt();
            if (actionCount == 0) {
                customAccessibilityActions = null;
            } else {
                if (customAccessibilityActions == null)
                    customAccessibilityActions = new ArrayList<>(actionCount);
                else
                    customAccessibilityActions.clear();

                for (int i = 0; i < actionCount; i++) {
                    CustomAccessibilityAction action = accessibilityBridge.getOrCreateAccessibilityAction(buffer.getInt());
                    if (action.overrideId == Action.TAP.value) {
                        onTapOverride = action;
                    } else if (action.overrideId == Action.LONG_PRESS.value) {
                        onLongPressOverride = action;
                    } else {
                        // If we receive a different overrideId it means that we were passed
                        // a standard action to override that we don't yet support.
                        assert action.overrideId == -1;
                        customAccessibilityActions.add(action);
                    }
                    customAccessibilityActions.add(action);
                }
            }
        }

        private void ensureInverseTransform() {
            if (!inverseTransformDirty) {
                return;
            }
            inverseTransformDirty = false;
            if (inverseTransform == null) {
                inverseTransform = new float[16];
            }
            if (!Matrix.invertM(inverseTransform, 0, transform, 0)) {
                Arrays.fill(inverseTransform, 0);
            }
        }

        private Rect getGlobalRect() {
            assert !globalGeometryDirty;
            return globalRect;
        }

        private SemanticsNode hitTest(float[] point) {
            final float w = point[3];
            final float x = point[0] / w;
            final float y = point[1] / w;
            if (x < left || x >= right || y < top || y >= bottom) return null;
            if (childrenInHitTestOrder != null) {
                final float[] transformedPoint = new float[4];
                for (int i = 0; i < childrenInHitTestOrder.size(); i += 1) {
                    final SemanticsNode child = childrenInHitTestOrder.get(i);
                    if (child.hasFlag(Flag.IS_HIDDEN)) {
                        continue;
                    }
                    child.ensureInverseTransform();
                    Matrix.multiplyMV(transformedPoint, 0, child.inverseTransform, 0, point, 0);
                    final SemanticsNode result = child.hitTest(transformedPoint);
                    if (result != null) {
                        return result;
                    }
                }
            }
            return this;
        }

        // TODO(goderbauer): This should be decided by the framework once we have more information
        //     about focusability there.
        private boolean isFocusable() {
            // We enforce in the framework that no other useful semantics are merged with these
            // nodes.
            if (hasFlag(Flag.SCOPES_ROUTE)) {
                return false;
            }
            int scrollableActions = Action.SCROLL_RIGHT.value | Action.SCROLL_LEFT.value
                    | Action.SCROLL_UP.value | Action.SCROLL_DOWN.value;
            return (actions & ~scrollableActions) != 0 || flags != 0
                    || (label != null && !label.isEmpty()) || (value != null && !value.isEmpty())
                    || (hint != null && !hint.isEmpty());
        }

        private void collectRoutes(List<SemanticsNode> edges) {
            if (hasFlag(Flag.SCOPES_ROUTE)) {
                edges.add(this);
            }
            if (childrenInTraversalOrder != null) {
                for (int i = 0; i < childrenInTraversalOrder.size(); ++i) {
                    childrenInTraversalOrder.get(i).collectRoutes(edges);
                }
            }
        }

        private String getRouteName() {
            // Returns the first non-null and non-empty semantic label of a child
            // with an NamesRoute flag. Otherwise returns null.
            if (hasFlag(Flag.NAMES_ROUTE)) {
                if (label != null && !label.isEmpty()) {
                    return label;
                }
            }
            if (childrenInTraversalOrder != null) {
                for (int i = 0; i < childrenInTraversalOrder.size(); ++i) {
                    String newName = childrenInTraversalOrder.get(i).getRouteName();
                    if (newName != null && !newName.isEmpty()) {
                        return newName;
                    }
                }
            }
            return null;
        }

        private void updateRecursively(float[] ancestorTransform, Set<SemanticsNode> visitedObjects,
                boolean forceUpdate) {
            visitedObjects.add(this);

            if (globalGeometryDirty) {
                forceUpdate = true;
            }

            if (forceUpdate) {
                if (globalTransform == null) {
                    globalTransform = new float[16];
                }
                Matrix.multiplyMM(globalTransform, 0, ancestorTransform, 0, transform, 0);

                final float[] sample = new float[4];
                sample[2] = 0;
                sample[3] = 1;

                final float[] point1 = new float[4];
                final float[] point2 = new float[4];
                final float[] point3 = new float[4];
                final float[] point4 = new float[4];

                sample[0] = left;
                sample[1] = top;
                transformPoint(point1, globalTransform, sample);

                sample[0] = right;
                sample[1] = top;
                transformPoint(point2, globalTransform, sample);

                sample[0] = right;
                sample[1] = bottom;
                transformPoint(point3, globalTransform, sample);

                sample[0] = left;
                sample[1] = bottom;
                transformPoint(point4, globalTransform, sample);

                if (globalRect == null) globalRect = new Rect();

                globalRect.set(Math.round(min(point1[0], point2[0], point3[0], point4[0])),
                        Math.round(min(point1[1], point2[1], point3[1], point4[1])),
                        Math.round(max(point1[0], point2[0], point3[0], point4[0])),
                        Math.round(max(point1[1], point2[1], point3[1], point4[1])));

                globalGeometryDirty = false;
            }

            assert globalTransform != null;
            assert globalRect != null;

            if (childrenInTraversalOrder != null) {
                for (int i = 0; i < childrenInTraversalOrder.size(); ++i) {
                    childrenInTraversalOrder.get(i).updateRecursively(
                            globalTransform, visitedObjects, forceUpdate);
                }
            }
        }

        private void transformPoint(float[] result, float[] transform, float[] point) {
            Matrix.multiplyMV(result, 0, transform, 0, point, 0);
            final float w = result[3];
            result[0] /= w;
            result[1] /= w;
            result[2] /= w;
            result[3] = 0;
        }

        private float min(float a, float b, float c, float d) {
            return Math.min(a, Math.min(b, Math.min(c, d)));
        }

        private float max(float a, float b, float c, float d) {
            return Math.max(a, Math.max(b, Math.max(c, d)));
        }

        private String getValueLabelHint() {
            StringBuilder sb = new StringBuilder();
            String[] array = {value, label, hint};
            for (String word : array) {
                if (word != null && word.length() > 0) {
                    if (sb.length() > 0) sb.append(", ");
                    sb.append(word);
                }
            }
            return sb.length() > 0 ? sb.toString() : null;
        }
    }
}
