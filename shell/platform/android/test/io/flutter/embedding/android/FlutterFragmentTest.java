package io.flutter.embedding.android;

import static org.junit.Assert.assertArrayEquals;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.spy;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;

import android.content.Context;
import androidx.fragment.app.FragmentActivity;
import androidx.activity.OnBackPressedCallback;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.FlutterEngineCache;
import io.flutter.embedding.engine.FlutterJNI;
import io.flutter.embedding.engine.loader.FlutterLoader;
import io.flutter.embedding.engine.systemchannels.NavigationChannel;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.Robolectric;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;

@Config(manifest = Config.NONE)
@RunWith(RobolectricTestRunner.class)
public class FlutterFragmentTest {
  @Test
  public void itCreatesDefaultFragmentWithExpectedDefaults() {
    FlutterFragment fragment = FlutterFragment.createDefault();
    fragment.setDelegate(new FlutterActivityAndFragmentDelegate(fragment));

    assertEquals("main", fragment.getDartEntrypointFunctionName());
    assertEquals("/", fragment.getInitialRoute());
    assertArrayEquals(new String[] {}, fragment.getFlutterShellArgs().toArray());
    assertTrue(fragment.shouldAttachEngineToActivity());
    assertFalse(fragment.shouldHandleDeeplinking());
    assertNull(fragment.getCachedEngineId());
    assertTrue(fragment.shouldDestroyEngineWithHost());
    assertEquals(RenderMode.surface, fragment.getRenderMode());
    assertEquals(TransparencyMode.transparent, fragment.getTransparencyMode());
  }

  @Test
  public void itCreatesNewEngineFragmentWithRequestedSettings() {
    FlutterFragment fragment =
        FlutterFragment.withNewEngine()
            .dartEntrypoint("custom_entrypoint")
            .initialRoute("/custom/route")
            .shouldAttachEngineToActivity(false)
            .handleDeeplinking(true)
            .renderMode(RenderMode.texture)
            .transparencyMode(TransparencyMode.opaque)
            .build();
    fragment.setDelegate(new FlutterActivityAndFragmentDelegate(fragment));

    assertEquals("custom_entrypoint", fragment.getDartEntrypointFunctionName());
    assertEquals("/custom/route", fragment.getInitialRoute());
    assertArrayEquals(new String[] {}, fragment.getFlutterShellArgs().toArray());
    assertFalse(fragment.shouldAttachEngineToActivity());
    assertTrue(fragment.shouldHandleDeeplinking());
    assertNull(fragment.getCachedEngineId());
    assertTrue(fragment.shouldDestroyEngineWithHost());
    assertEquals(RenderMode.texture, fragment.getRenderMode());
    assertEquals(TransparencyMode.opaque, fragment.getTransparencyMode());
  }

  @Test
  public void itCreatesCachedEngineFragmentThatDoesNotDestroyTheEngine() {
    FlutterFragment fragment = FlutterFragment.withCachedEngine("my_cached_engine").build();

    assertTrue(fragment.shouldAttachEngineToActivity());
    assertEquals("my_cached_engine", fragment.getCachedEngineId());
    assertFalse(fragment.shouldDestroyEngineWithHost());
  }

  @Test
  public void itCreatesCachedEngineFragmentThatDestroysTheEngine() {
    FlutterFragment fragment =
        FlutterFragment.withCachedEngine("my_cached_engine")
            .destroyEngineWithFragment(true)
            .build();

    assertTrue(fragment.shouldAttachEngineToActivity());
    assertEquals("my_cached_engine", fragment.getCachedEngineId());
    assertTrue(fragment.shouldDestroyEngineWithHost());
  }

  @Test
  public void itCanBeDetachedFromTheEngineAndStopSendingFurtherEvents() {
    FlutterActivityAndFragmentDelegate mockDelegate =
        mock(FlutterActivityAndFragmentDelegate.class);
    FlutterFragment fragment =
        FlutterFragment.withCachedEngine("my_cached_engine")
            .destroyEngineWithFragment(true)
            .build();
    fragment.setDelegate(mockDelegate);
    fragment.onStart();
    fragment.onResume();

    verify(mockDelegate, times(1)).onStart();
    verify(mockDelegate, times(1)).onResume();

    fragment.onPause();
    fragment.detachFromFlutterEngine();
    verify(mockDelegate, times(1)).onPause();
    verify(mockDelegate, times(1)).onDestroyView();
    verify(mockDelegate, times(1)).onDetach();

    fragment.onStop();
    fragment.onDestroy();

    verify(mockDelegate, never()).onStop();
    // 1 time same as before.
    verify(mockDelegate, times(1)).onDestroyView();
    verify(mockDelegate, times(1)).onDetach();
  }

  @Test
  public void itDoesNotRecurseSystemNavigatorPopWhenUsingOnBackPressedCallback() {
    NavigationChannel mockNavigationChannel = mock(NavigationChannel.class);
    FlutterEngine engine =
        new FlutterEngine(
            RuntimeEnvironment.application, mock(FlutterLoader.class), mock(FlutterJNI.class));
    NavigationChannel navigationChannel = spy(engine.getNavigationChannel());
    FlutterEngineCache.getInstance().put("my_cached_engine", engine);

    FlutterFragment fragment = FlutterFragment.withCachedEngine("my_cached_engine").build();
    FragmentActivity activity = Robolectric.setupActivity(FragmentActivity.class);
    activity
        .getSupportFragmentManager()
        .beginTransaction()
        .replace(android.R.id.content, fragment)
        .commitNow();
    engine.getPlatformChannel().channel.invokeMethod("SystemNavigator.pop", null);
    verify(navigationChannel, never()).popRoute();
    assertTrue(activity.isFinishing());
  }

  public static final class OnBackPressedCallbackFlutterFragment extends FlutterFragment {
    private final OnBackPressedCallback onBackPressedCallback =
        new OnBackPressedCallback(true) {
          @Override
          public void handleOnBackPressed() {
            onBackPressed();
          }
        };

    @Override
    public void onAttach(Context context) {
      super.onAttach(context);
      requireActivity().getOnBackPressedDispatcher().addCallback(this, onBackPressedCallback);
    }
  }
}
