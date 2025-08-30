#include "layer_shell.h"
#include <gtk4-layer-shell.h>

gboolean layer_shell_is_supported(void) {
    // Check if we're on Wayland and layer shell is available
    GdkDisplay *display = gdk_display_get_default();
    if (!display) {
        return FALSE;
    }
    
    // Try to detect if we're on Wayland
    const char *backend = g_type_name(G_TYPE_FROM_INSTANCE(display));
    gboolean is_wayland = g_str_has_suffix(backend, "WaylandDisplay");
    
    if (!is_wayland) {
        g_print("Layer shell not supported: Not running on Wayland (backend: %s)\n", backend);
        return FALSE;
    }
    
    return gtk_layer_is_supported();
}

void layer_shell_init_window_for_monitor(GtkWindow *window, const char *monitor_name) {
    if (!layer_shell_is_supported()) {
        g_print("Layer shell not supported, falling back to regular window mode\n");
        return;
    }
    
    // Initialize layer shell for this window
    gtk_layer_init_for_window(window);
    
    // Set layer to background (below everything)
    gtk_layer_set_layer(window, GTK_LAYER_SHELL_LAYER_BACKGROUND);
    
    // Set exclusive zone to -1 to indicate we want to be below other windows
    gtk_layer_set_exclusive_zone(window, -1);
    
    // Anchor to all edges (fullscreen on the specified monitor)
    gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_LEFT, TRUE);
    gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_RIGHT, TRUE);
    gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_TOP, TRUE);
    gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_BOTTOM, TRUE);
    
    // Set margins to 0 to ensure fullscreen coverage
    gtk_layer_set_margin(window, GTK_LAYER_SHELL_EDGE_LEFT, 0);
    gtk_layer_set_margin(window, GTK_LAYER_SHELL_EDGE_RIGHT, 0);
    gtk_layer_set_margin(window, GTK_LAYER_SHELL_EDGE_TOP, 0);
    gtk_layer_set_margin(window, GTK_LAYER_SHELL_EDGE_BOTTOM, 0);
    
    // Set keyboard mode to none (wallpaper doesn't need keyboard input)
    gtk_layer_set_keyboard_mode(window, GTK_LAYER_SHELL_KEYBOARD_MODE_NONE);
    
    // Set monitor if specified
    if (monitor_name && strlen(monitor_name) > 0) {
        GdkDisplay *display = gtk_widget_get_display(GTK_WIDGET(window));
        GListModel *monitors = gdk_display_get_monitors(display);
        guint n_monitors = g_list_model_get_n_items(monitors);
        
        for (guint i = 0; i < n_monitors; i++) {
            GdkMonitor *monitor = g_list_model_get_item(monitors, i);
            const char *connector = gdk_monitor_get_connector(monitor);
            
            if (connector && strcmp(connector, monitor_name) == 0) {
                gtk_layer_set_monitor(window, monitor);
                g_print("Layer shell configured for monitor: %s\n", monitor_name);
                g_object_unref(monitor);
                return;
            }
            g_object_unref(monitor);
        }
        g_print("Monitor '%s' not found, using default\n", monitor_name);
    }
    
    g_print("Layer shell successfully initialized for wallpaper mode\n");
}

void layer_shell_init_window(GtkWindow *window) {
    layer_shell_init_window_for_monitor(window, NULL);
}

void layer_shell_configure_wallpaper(GtkWindow *window) {
    // Configure window for wallpaper use
    gtk_window_set_decorated(window, FALSE);
    gtk_window_set_resizable(window, FALSE);
    
    if (layer_shell_is_supported()) {
        // Layer shell will handle sizing
        g_print("Layer shell wallpaper mode configured\n");
    } else {
        // Fallback to fullscreen mode
        gtk_window_fullscreen(window);
        g_print("Fallback fullscreen wallpaper mode configured\n");
    }
}
