package io.flutter.plugin.platform;

import android.annotation.TargetApi; 
import android.content.Context;
import android.content.ContextWrapper;
import android.graphics.Rect;
import android.support.annotation.NonNull;
import android.support.annotation.Nullable;
import android.util.Log;
import android.view.Display;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.view.accessibility.AccessibilityEvent;
import android.view.inputmethod.InputMethodManager;
import android.widget.FrameLayout;
import java.lang.reflect.InvocationHandler;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;

import static android.content.Context.WINDOW_SERVICE;
import static android.view.View.OnFocusChangeListener;

/*
 * A presentation used for hosting a single Android view in a virtual display.
 *
 * This presentation overrides the WindowManager's addView/removeView/updateViewLayout methods, such that views added
 * directly to the WindowManager are added as part of the presentation's view hierarchy (to fakeWindowViewGroup).
 *
 * The view hierarchy for the presentation is as following:
 *
 *          rootView
 *         /         \
 *        /           \
 *       /             \
 *   container       state.fakeWindowViewGroup
 *      |
 *   EmbeddedView
 */
@Keep
@TargetApi(Build.VERSION_CODES.JELLY_BEAN_MR1)

class SingleViewPresentationAlternative {
    
    private Context context;
    
    private ViewDrawingRerouter viewDrawingRerouter;
    
    // The Android view we are embedding in the Flutter app.
    private PlatformView platformView;

    // The InvocationHandler for a WindowManager proxy. This is essentially the custom window manager for the
    // presentation.
    private WindowManagerHandler windowManagerHandler;

    // Contains views that were added directly to the window manager (e.g android.widget.PopupWindow).
    private FakeWindowViewGroup fakeWindowViewGroup;

    container = new FrameLayout(getContext());

    // Our base mContext has already been wrapped with an IMM cache at instantiation time, but
    // we want to wrap it again here to also return state.windowManagerHandler.
    Context context = new PresentationContext(getContext(), state.windowManagerHandler);

    private final OnFocusChangeListener focusChangeListener;

    // This is the view id assigned by the Flutter framework to the embedded view, we keep it here
    // so when we create the platform view we can tell it its view id.
    private int viewId;

    // This is the creation parameters for the platform view, we keep it here
    // so when we create the platform view we can tell it its view id.
    private Object createParams;

    // The root view for the presentation, it has 2 childs: container which contains the embedded view, and
    // fakeWindowViewGroup which contains views that were added directly to the presentation's window manager.
    private AccessibilityDelegatingFrameLayout rootView;

    // Contains the embedded platform view (platformView.getView()) when it is attached to the presentation.
    private FrameLayout container;

    private boolean startFocused = false;



    public SingleViewPresentationAlternative(
        Context outerContext,
        ViewDrawingRerouter viewDrawingRerouter,
        PlatformViewFactory viewFactory,
        AccessibilityEventsDelegate accessibilityEventsDelegate,
        int viewId,
        Object createParams,
        OnFocusChangeListener focusChangeListener
    ) {
        this.context = new ImmContext(outerContext);

        this.viewDrawingRerouter = viewDrawingRerouter;
        this.viewFactory = viewFactory;
        this.accessibilityEventsDelegate = accessibilityEventsDelegate;
        this.viewId = viewId;
        this.createParams = createParams;
        this.focusChangeListener = focusChangeListener;
    }

    public void init() {

        if (fakeWindowViewGroup == null) {
            fakeWindowViewGroup = new FakeWindowViewGroup(getContext());
        }
        if (windowManagerHandler == null) {
            WindowManager windowManagerDelegate = (WindowManager) getContext().getSystemService(WINDOW_SERVICE);
            windowManagerHandler = new WindowManagerHandler(windowManagerDelegate, fakeWindowViewGroup);
        }

        container = new FrameLayout(getContext());

        // Our base mContext has already been wrapped with an IMM cache at instantiation time, but
        // we want to wrap it again here to also return state.windowManagerHandler.
        Context context = new PresentationContext(getContext(), windowManagerHandler);

        if (platformView == null) {
            platformView = viewFactory.create(context, viewId, createParams);
        }

        if(viewDrawingRerouter == null) {
            viewDrawingRerouter = viewDrawingRerouter;
        }

        View embeddedView = platformView.getView();
        container.addView(embeddedView);
        rootView = new AccessibilityDelegatingFrameLayout(getContext(), accessibilityEventsDelegate, embeddedView);
        rootView.addView(container);
        rootView.addView(fakeWindowViewGroup);

        embeddedView.setOnFocusChangeListener(focusChangeListener);
        rootView.setFocusableInTouchMode(true);
        if (startFocused) {
            embeddedView.requestFocus();
        } else {
            rootView.requestFocus();
        }
        viewDrawingRerouter.setContentView(rootView);
    }

    private Context getContext() {
        return context;
    }


	public PlatformView getView() {
		return platformView;
    }
    
    public void dispose() {
        viewDrawingRerouter.setContentView(null);
    }


        /*
     * A view group that implements the same layout protocol that exist between the WindowManager and its direct
     * children.
     *
     * Currently only a subset of the protocol is supported (gravity, x, and y).
     */
    static class FakeWindowViewGroup extends ViewGroup {
        // Used in onLayout to keep the bounds of the current view.
        // We keep it as a member to avoid object allocations during onLayout which are discouraged.
        private final Rect viewBounds;

        // Used in onLayout to keep the bounds of the child views.
        // We keep it as a member to avoid object allocations during onLayout which are discouraged.
        private final Rect childRect;

        public FakeWindowViewGroup(Context context) {
            super(context);
            viewBounds = new Rect();
            childRect = new Rect();
        }

        @Override
        protected void onLayout(boolean changed, int l, int t, int r, int b) {
            for(int i = 0; i < getChildCount(); i++) {
                View child = getChildAt(i);
                WindowManager.LayoutParams params = (WindowManager.LayoutParams) child.getLayoutParams();
                viewBounds.set(l, t, r, b);
                Gravity.apply(params.gravity, child.getMeasuredWidth(), child.getMeasuredHeight(), viewBounds, params.x,
                        params.y, childRect);
                child.layout(childRect.left, childRect.top, childRect.right, childRect.bottom);
            }
        }

        @Override
        protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
            for(int i = 0; i < getChildCount(); i++) {
                View child = getChildAt(i);
                child.measure(atMost(widthMeasureSpec), atMost(heightMeasureSpec));
            }
            super.onMeasure(widthMeasureSpec, heightMeasureSpec);
        }

        private static int atMost(int measureSpec) {
            return MeasureSpec.makeMeasureSpec(MeasureSpec.getSize(measureSpec), MeasureSpec.AT_MOST);
        }

		public void addView(View view, LayoutParams layoutParams) {
		}
    }

    @Override
    public Context createDisplayContext(Display display) {
      Context displayContext = super.createDisplayContext(display);
      return new ImmContext(displayContext, inputMethodManager);
    }
  }

  /** Proxies a Context replacing the WindowManager with our custom instance. */
  // TODO(mklim): This caches the IMM at construction time and won't pick up any changes. In rare
  // cases where the FlutterView changes windows this will return an outdated instance. This
  // should be fixed to instead defer returning the IMM to something that know's FlutterView's
  // true Context.
  private static class PresentationContext extends ContextWrapper {
    private @NonNull final WindowManagerHandler windowManagerHandler;
    private @Nullable WindowManager windowManager;

    PresentationContext(Context base, @NonNull WindowManagerHandler windowManagerHandler) {
      super(base);
      this.windowManagerHandler = windowManagerHandler;
    }

    @Override
    public Object getSystemService(String name) {
      if (WINDOW_SERVICE.equals(name)) {
        return getWindowManager();
      }
      return super.getSystemService(name);
    }

    private WindowManager getWindowManager() {
      if (windowManager == null) {
        windowManager = windowManagerHandler.getWindowManager();
      }
      return windowManager;
    }
  }

  /*
   * A dynamic proxy handler for a WindowManager with custom overrides.
   *
   * The presentation's window manager delegates all calls to the default window manager.
   * WindowManager#addView calls triggered by views that are attached to the virtual display are crashing
   * (see: https://github.com/flutter/flutter/issues/20714). This was triggered when selecting text in an embedded
   * WebView (as the selection handles are implemented as popup windows).
   *
   * This dynamic proxy overrides the addView, removeView, removeViewImmediate, and updateViewLayout methods
   * to prevent these crashes.
   *
   * This will be more efficient as a static proxy that's not using reflection, but as the engine is currently
   * not being built against the latest Android SDK we cannot override all relevant method.
   * Tracking issue for upgrading the engine's Android sdk: https://github.com/flutter/flutter/issues/20717
   */
  static class WindowManagerHandler implements InvocationHandler {
    private static final String TAG = "PlatformViewsController";

    private final WindowManager delegate;
    FakeWindowViewGroup fakeWindowRootView;

    WindowManagerHandler(WindowManager delegate, FakeWindowViewGroup fakeWindowViewGroup) {
      this.delegate = delegate;
      fakeWindowRootView = fakeWindowViewGroup;
    }

    public WindowManager getWindowManager() {
      return (WindowManager)
          Proxy.newProxyInstance(
              WindowManager.class.getClassLoader(), new Class<?>[] {WindowManager.class}, this);
    }

    @Override
    public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
      switch (method.getName()) {
        case "addView":
          addView(args);
          return null;
        case "removeView":
          removeView(args);
          return null;
        case "removeViewImmediate":
          removeViewImmediate(args);
          return null;
        case "updateViewLayout":
          updateViewLayout(args);
          return null;
      }
      try {
        return method.invoke(delegate, args);
      } catch (InvocationTargetException e) {
        throw e.getCause();
      }
    }

    private void addView(Object[] args) {
      if (fakeWindowRootView == null) {
        Log.w(TAG, "Embedded view called addView while detached from presentation");
        return;
      }
      View view = (View) args[0];
      WindowManager.LayoutParams layoutParams = (WindowManager.LayoutParams) args[1];
      fakeWindowRootView.addView(view, layoutParams);
    }

    private void removeView(Object[] args) {
      if (fakeWindowRootView == null) {
        Log.w(TAG, "Embedded view called removeView while detached from presentation");
        return;
      }
      View view = (View) args[0];
      fakeWindowRootView.removeView(view);
    }

    private void removeViewImmediate(Object[] args) {
      if (fakeWindowRootView == null) {
        Log.w(TAG, "Embedded view called removeViewImmediate while detached from presentation");
        return;
      }
      View view = (View) args[0];
      view.clearAnimation();
      fakeWindowRootView.removeView(view);
    }

    private void updateViewLayout(Object[] args) {
      if (fakeWindowRootView == null) {
        Log.w(TAG, "Embedded view called updateViewLayout while detached from presentation");
        return;
      }
      View view = (View) args[0];
      WindowManager.LayoutParams layoutParams = (WindowManager.LayoutParams) args[1];
      fakeWindowRootView.updateViewLayout(view, layoutParams);
    }
  }

  private static class AccessibilityDelegatingFrameLayout extends FrameLayout {
    private final AccessibilityEventsDelegate accessibilityEventsDelegate;
    private final View embeddedView;

    public AccessibilityDelegatingFrameLayout(
        Context context,
        AccessibilityEventsDelegate accessibilityEventsDelegate,
        View embeddedView) {
      super(context);
      this.accessibilityEventsDelegate = accessibilityEventsDelegate;
      this.embeddedView = embeddedView;
    }

    @Override
    public boolean requestSendAccessibilityEvent(View child, AccessibilityEvent event) {
      return accessibilityEventsDelegate.requestSendAccessibilityEvent(embeddedView, child, event);
    }

}
