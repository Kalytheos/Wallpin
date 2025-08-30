#ifndef LAYER_SHELL_H
#define LAYER_SHELL_H

#include <gtk/gtk.h>
#include <gtk4-layer-shell.h>

// Layer shell initialization and configuration
gboolean layer_shell_is_supported(void);
void layer_shell_init_window(GtkWindow *window);
void layer_shell_init_window_for_monitor(GtkWindow *window, const char *monitor_name);
void layer_shell_configure_wallpaper(GtkWindow *window);

#endif // LAYER_SHELL_H
