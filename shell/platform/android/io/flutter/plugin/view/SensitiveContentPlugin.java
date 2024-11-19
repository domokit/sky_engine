// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugin.editing;

import androidx.annotation.NonNull;
import androidx.annotation.VisibleForTesting;
import io.flutter.embedding.engine.systemchannels.SensitiveContentChannel;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.localization.LocalizationPlugin;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Locale;

/**
 * {@link SensitiveContentPlugin} is the implementation of all functionality needed to
 * set content sensitive on a native Flutter Android {@code View}.
 *
 * <p>The plugin handles requests for setting content sensitivity sent by the {@link
 * io.flutter.embedding.engine.systemchannels.SensitiveContentChannel} via making a call to
 * the relevant {@code View}.
 */
public class SensitiveContentPlugin implements SensitiveContentChannel.SensitiveContentMethodHandler {

    private final SensitiveContentChannel mSensitiveContentChannel;

    public SensitiveContentPlugin(@NonNull Activity flutterActivity, @NonNull SensitiveContentChannel sensitiveContentChannel) {
        mSensitiveContentChannel = sensitiveContentChannel;
        mSensitiveContentChannel.setSensitiveContentMethodHandler(this);
    }

    /**
     * Sets content sensitivity level of the Android {@code View} with the specified {@code flutterViewId} 
     * to the level specified by {@contentSensitivity}.
    */
    @Override
    public void setContentSensitivity(@NonNull int flutterViewId, @NonNull int contentSensitivity, @NonNull MethodChannel.Result result) {
        final View flutterView = activity.findViewById(viewId);
        if (flutterView == null) {
            result.error("error", "Requested Flutter View to set content sensitivty of not found.");
        }

        flutterView.setContentSensitivity(contentSensitivity);
        result.success();
    }
}