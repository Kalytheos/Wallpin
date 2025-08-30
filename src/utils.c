#include <gtk/gtk.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <limits.h>
#include <time.h>
#include <glib.h>
#include "wallpaper.h"
#include "config.h"
#include "utils.h"
#include "layout.h"

void apply_css_to_window(GtkWidget *window) {
    g_print("=== APLICANDO CSS ===\n");
    
    GtkCssProvider *provider = gtk_css_provider_new();
    const char *css = 
        ".rounded {"
        "    border-radius: 16px;"
        "    background-color: #2c2c2c;"
        "    transition: transform 0.2s ease-in-out;"
        "    box-shadow: 0 2px 4px rgba(0,0,0,0.2);"
        "    margin: 8px;"
        "}"
        ".image-card {"
        "    transition: all 0.2s ease-in-out;"
        "    box-shadow: 0 2px 8px rgba(0,0,0,0.2);"
        "    transform: scale(1.0);"
        "}"
        ".image-card:hover {"
        "    transform: scale(1.0) translateY(-4px);"
        "    box-shadow: 0 12px 24px rgba(0,0,0,0.4);"
        "    z-index: 10;"
        "}"
        ".duplicate-separator {"
        "    background-color: transparent;"
        "    min-height: 1px;"
        "    opacity: 0;"
        "}"
        "window {"
        "    background: #121212;"
        "    background-color: #121212;"
        "}"
        ".dark-window {"
        "    background: #121212;"
        "    background-color: #121212;"
        "}"
        "picture {"
        "    background-color: #2c2c2c;"
        "    border-radius: 16px;"
        "}"
        "box {"
        "    background: #121212;"
        "    background-color: #121212;"
        "    padding: 8px;"
        "    margin: 0;"
        "}"
        "scrolledwindow {"
        "    background: #121212;"
        "    background-color: #121212;"
        "}";

    // En GTK4, gtk_css_provider_load_from_string no devuelve valor
    gtk_css_provider_load_from_string(provider, css);
    g_print("CSS cargado\n");
    
    // Aplicar CSS con máxima prioridad
    gtk_style_context_add_provider_for_display(
        gtk_widget_get_display(window),
        GTK_STYLE_PROVIDER(provider),
        GTK_STYLE_PROVIDER_PRIORITY_USER  // Máxima prioridad para forzar estilos
    );
    
    g_print("CSS aplicado al display con máxima prioridad\n");
    g_object_unref(provider);
    g_print("=== FIN APLICACIÓN CSS ===\n");
}

void shuffle_images(GList **images) {
    if (!images || !*images)
        return;

    GList *new_list = NULL;
    
    // Seed the random number generator
    srand(time(NULL));
    
    while (*images) {
        int index = rand() % g_list_length(*images);
        GList *item = g_list_nth(*images, index);
        gpointer data = item->data;
        
        *images = g_list_remove(*images, data);
        new_list = g_list_append(new_list, data);
    }
    
    *images = new_list;
}
