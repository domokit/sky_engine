// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertThrows;

import io.flutter.embedding.engine.deferredcomponents.PlayStoreDeferredComponentManager;
import io.flutter.embedding.engine.loader.FlutterLoader;
import java.util.Arrays;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Future;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;

@Config(manifest = Config.NONE)
@RunWith(RobolectricTestRunner.class)
public class FlutterInjectorTest {
  @Mock FlutterLoader mockFlutterLoader;
  @Mock PlayStoreDeferredComponentManager mockDeferredComponentManager;
  @Mock ExecutorService mockExecutorService;

  @Before
  public void setUp() {
    // Since the intent is to have a convenient static class to use for production.
    FlutterInjector.reset();
    MockitoAnnotations.openMocks(this);
  }

  @After
  public void tearDown() {
    FlutterInjector.reset();
  }

  @Test
  public void itHasSomeReasonableDefaults() {
    // Implicitly builds when first accessed.
    FlutterInjector injector = FlutterInjector.instance();
    assertNotNull(injector.flutterLoader());
    assertNull(injector.deferredComponentManager());
    assertNotNull(injector.executorService());
  }

  @Test
  public void executorCreatesAndNamesNewThreadsByDefault()
      throws InterruptedException, ExecutionException {
    // Implicitly builds when first accessed.
    FlutterInjector injector = FlutterInjector.instance();

    List<Callable<String>> callables =
        Arrays.asList(
            () -> {
              return Thread.currentThread().getName();
            },
            () -> {
              return Thread.currentThread().getName();
            });

    List<Future<String>> threadNames;
    threadNames = injector.executorService().invokeAll(callables);

    assertEquals(threadNames.size(), 2);
    assertEquals(threadNames.get(0).get(), "flutter-worker-0");
    assertEquals(threadNames.get(1).get(), "flutter-worker-1");
  }

  @Test
  public void canPartiallyOverride() {
    FlutterInjector.setInstance(
        new FlutterInjector.Builder().setFlutterLoader(mockFlutterLoader).build());
    FlutterInjector injector = FlutterInjector.instance();
    assertEquals(injector.flutterLoader(), mockFlutterLoader);
  }

  @Test
  public void canInjectDeferredComponentManager() {
    FlutterInjector.setInstance(
        new FlutterInjector.Builder()
            .setDeferredComponentManager(mockDeferredComponentManager)
            .build());
    FlutterInjector injector = FlutterInjector.instance();
    assertEquals(injector.deferredComponentManager(), mockDeferredComponentManager);
  }

  @Test
  public void canInjectExecutorService() {
    FlutterInjector.setInstance(
        new FlutterInjector.Builder().setExecutorService(mockExecutorService).build());
    FlutterInjector injector = FlutterInjector.instance();
    assertEquals(injector.executorService(), mockExecutorService);
  }

  @Test()
  public void cannotBeChangedOnceRead() {
    FlutterInjector.instance();

    assertThrows(
        IllegalStateException.class,
        () -> {
          FlutterInjector.setInstance(
              new FlutterInjector.Builder().setFlutterLoader(mockFlutterLoader).build());
        });
  }
}
