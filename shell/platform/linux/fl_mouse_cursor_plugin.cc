// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "flutter/shell/platform/linux/fl_mouse_cursor_plugin.h"

#include "flutter/shell/platform/linux/public/flutter_linux/fl_method_channel.h"
#include "flutter/shell/platform/linux/public/flutter_linux/fl_standard_method_codec.h"

#include <gtk/gtk.h>

static constexpr char kChannelName[] = "flutter/mousecursor";
static constexpr char kBadArgumentsError[] = "Bad Arguments";
static constexpr char kActivateSystemCursorMethod[] = "activateSystemCursor";
static constexpr char kKindKey[] = "kind";

static constexpr char kFallbackCursor[] = "default";

struct _FlMouseCursorPlugin {
  GObject parent_instance;

  FlMethodChannel* channel;

  FlView* view;

  GHashTable* system_cursor_table;
};

G_DEFINE_TYPE(FlMouseCursorPlugin, fl_mouse_cursor_plugin, G_TYPE_OBJECT)

// Insert a new entry into a hashtable from strings to strings.
//
// Returns whether the newly added value was already in the hash table or not.
static bool define_system_cursor(GHashTable* table, const gchar *key, const gchar *value) {
  return g_hash_table_insert(table, (gpointer)key, (gpointer)value);
}

// Populate the hash table so that it maps from Flutter's cursor kinds to GTK's
// cursor values.
//
// The table must have been created as a hashtable from strings to strings.
static void populate_system_cursor_table(GHashTable* table) {
  // The following mapping must be kept in sync with Flutter framework's
  // mouse_cursor.dart.
  define_system_cursor(table, "none", "none");
  define_system_cursor(table, "click", "pointer");
  define_system_cursor(table, "text", "text");
  define_system_cursor(table, "forbidden", "not-allowed");
  define_system_cursor(table, "grab", "grabbing");
  define_system_cursor(table, "resizeLeftRight", "ew-resize");
  define_system_cursor(table, "resizeUpDown", "ns-resize");
}

// Sets the mouse cursor.
FlMethodResponse* activate_system_cursor(FlMouseCursorPlugin* self,
                                         FlValue* args) {
  if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        kBadArgumentsError, "Argument map missing or malformed", nullptr));
  }

  FlValue* kind_value = fl_value_lookup_string(args, kKindKey);
  const gchar* kind = nullptr;
  if (fl_value_get_type(kind_value) == FL_VALUE_TYPE_STRING)
    kind = fl_value_get_string(kind_value);

  if (self->system_cursor_table == nullptr) {
    self->system_cursor_table = g_hash_table_new(g_str_hash, g_str_equal);
    populate_system_cursor_table(self->system_cursor_table);
  }

  const gchar* cursor_name = (const gchar*)g_hash_table_lookup(self->system_cursor_table, kind);
  if (cursor_name == nullptr)
    cursor_name = kFallbackCursor;

  GdkWindow* window =
      gtk_widget_get_window(gtk_widget_get_toplevel(GTK_WIDGET(self->view)));
  g_autoptr(GdkCursor) cursor =
      gdk_cursor_new_from_name(gdk_window_get_display(window), cursor_name);
  gdk_window_set_cursor(window, cursor);

  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

// Called when a method call is received from Flutter.
static void method_call_cb(FlMethodChannel* channel,
                           FlMethodCall* method_call,
                           gpointer user_data) {
  FlMouseCursorPlugin* self = FL_MOUSE_CURSOR_PLUGIN(user_data);

  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  g_autoptr(FlMethodResponse) response = nullptr;
  if (strcmp(method, kActivateSystemCursorMethod) == 0)
    response = activate_system_cursor(self, args);
  else
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());

  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(method_call, response, &error))
    g_warning("Failed to send method call response: %s", error->message);
}

static void view_weak_notify_cb(gpointer user_data, GObject* object) {
  FlMouseCursorPlugin* self = FL_MOUSE_CURSOR_PLUGIN(object);
  self->view = nullptr;
}

static void fl_mouse_cursor_plugin_dispose(GObject* object) {
  FlMouseCursorPlugin* self = FL_MOUSE_CURSOR_PLUGIN(object);

  g_clear_object(&self->channel);
  if (self->view != nullptr) {
    g_object_weak_unref(G_OBJECT(self->view), view_weak_notify_cb, self);
    self->view = nullptr;
  }

  if (self->system_cursor_table)
    g_hash_table_destroy(self->system_cursor_table);

  G_OBJECT_CLASS(fl_mouse_cursor_plugin_parent_class)->dispose(object);
}

static void fl_mouse_cursor_plugin_class_init(FlMouseCursorPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = fl_mouse_cursor_plugin_dispose;
}

static void fl_mouse_cursor_plugin_init(FlMouseCursorPlugin* self) {}

FlMouseCursorPlugin* fl_mouse_cursor_plugin_new(FlBinaryMessenger* messenger,
                                                FlView* view) {
  g_return_val_if_fail(FL_IS_BINARY_MESSENGER(messenger), nullptr);

  FlMouseCursorPlugin* self = FL_MOUSE_CURSOR_PLUGIN(
      g_object_new(fl_mouse_cursor_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->channel =
      fl_method_channel_new(messenger, kChannelName, FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(self->channel, method_call_cb, self,
                                            nullptr);
  self->view = view;
  g_object_weak_ref(G_OBJECT(view), view_weak_notify_cb, self);

  return self;
}
