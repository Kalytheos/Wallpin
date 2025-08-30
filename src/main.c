// No optimizado

#include <gtk/gtk.h>
#include <dirent.h>
#include <string.h>
#include "wallpaper.h"
#include "config.h"
#include "utils.h"
#include "layout.h"

#define WINDOW_HEIGHT 1080
#define CORNER_RADIUS 16

static MasonryLayout layout;

static GtkWidget *create_image_grid(void);
static void load_images_from_directory(GtkBox *container, const char *dir_path);
static GtkWidget *create_rounded_image(const char *image_path, int target_width, int target_height);
static void render_layout(GtkBox *container);

// Variables para auto-scroll infinito
static GtkWidget *main_scroll_window = NULL;
static GtkAdjustment *scroll_adjustment = NULL;
static guint scroll_timer_id = 0;
static double current_scroll_position = 0.0;
static gboolean auto_scroll_enabled = TRUE;

// Configuración del auto-scroll
#define SCROLL_SPEED 0.3        // Velocidad en píxeles por frame (ajustable)
#define SCROLL_INTERVAL 8      // Milisegundos entre frames (60 FPS = 16ms)

static GtkWidget *create_image_grid(void) {
    GtkWidget *container = gtk_box_new(GTK_ORIENTATION_VERTICAL, IMAGE_SPACING);
    gtk_widget_set_margin_start(container, IMAGE_SPACING * 2);
    gtk_widget_set_margin_end(container, IMAGE_SPACING * 2);
    gtk_widget_set_margin_top(container, IMAGE_SPACING * 2);
    gtk_widget_set_margin_bottom(container, IMAGE_SPACING * 2);
    return container;
}

static void load_images_from_directory(GtkBox *container, const char *dir_path) {
    DIR *dir;
    struct dirent *entry;
    char full_path[PATH_MAX];
    GList *image_files = NULL;
    int image_count = 0;

    masonry_layout_init(&layout, WINDOW_WIDTH, STANDARD_WIDTH, IMAGE_SPACING);

    dir = opendir(dir_path);
    if (dir == NULL) {
        g_print("Error opening directory: %s\n", dir_path);
        return;
    }

    g_print("\nScanning directory: %s\n", dir_path);
    g_print("=== MODO SIN OPTIMIZACIÓN - CARGANDO IMÁGENES COMPLETAS ===\n");

    while ((entry = readdir(dir)) != NULL) {
        if (entry->d_type == DT_REG) {
            const char *ext = strrchr(entry->d_name, '.');
            if (ext && (strcasecmp(ext, ".jpg") == 0 ||
                       strcasecmp(ext, ".jpeg") == 0 ||
                       strcasecmp(ext, ".png") == 0)) {
                snprintf(full_path, PATH_MAX, "%s/%s", dir_path, entry->d_name);
                image_files = g_list_append(image_files, g_strdup(full_path));
                image_count++;
            }
        }
    }

    g_print("Found %d images\n", image_count);
    g_print("WARNING: Loading full resolution images - High memory usage expected!\n\n");

    image_files = g_list_sort(image_files, (GCompareFunc)g_strcmp0);

    for (GList *l = image_files; l != NULL; l = l->next) {
        masonry_layout_add_image(&layout, (const char *)l->data);
        g_free(l->data);
    }

    g_list_free(image_files);

    masonry_layout_calculate(&layout);
    render_layout(container);
    closedir(dir);
}

static GtkWidget *create_rounded_image(const char *image_path, int target_width, int target_height) {
    GError *error = NULL;
    
    // SIN OPTIMIZACIÓN: Cargar la imagen completa sin redimensionar
    GdkPixbuf *original_pixbuf = gdk_pixbuf_new_from_file(image_path, &error);
    
    if (error) {
        g_warning("Error loading image %s: %s", image_path, error->message);
        g_error_free(error);
        return gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    }

    // Obtener dimensiones originales para debug
    int orig_width = gdk_pixbuf_get_width(original_pixbuf);
    int orig_height = gdk_pixbuf_get_height(original_pixbuf);
    
    // Escalar la imagen DESPUÉS de cargarla (usa más memoria)
    GdkPixbuf *scaled_pixbuf = gdk_pixbuf_scale_simple(original_pixbuf, 
                                                        target_width, 
                                                        target_height,
                                                        GDK_INTERP_BILINEAR);
    
    // Log para ver el consumo de memoria
    g_print("Loaded FULL image: %s [Original: %dx%d, Display: %dx%d]\n", 
            image_path, orig_width, orig_height, target_width, target_height);
    
    // Liberar el pixbuf original (pero ya consumió memoria al cargarlo completo)
    g_object_unref(original_pixbuf);

    // Convertir a texture para GTK4
    GdkTexture *texture = gdk_texture_new_for_pixbuf(scaled_pixbuf);
    g_object_unref(scaled_pixbuf);

    // Crear GtkPicture con el texture
    GtkWidget *picture = gtk_picture_new_for_paintable(GDK_PAINTABLE(texture));
    g_object_unref(texture);

    // Configurar las propiedades del picture
    gtk_picture_set_can_shrink(GTK_PICTURE(picture), TRUE);
    gtk_picture_set_content_fit(GTK_PICTURE(picture), GTK_CONTENT_FIT_COVER);

    // Crear el frame contenedor con bordes redondeados
    GtkWidget *frame = gtk_frame_new(NULL);
    gtk_frame_set_child(GTK_FRAME(frame), picture);

    // Aplicar estilos CSS para bordes redondeados
    gtk_widget_set_overflow(frame, GTK_OVERFLOW_HIDDEN);
    gtk_widget_add_css_class(frame, "rounded");
    gtk_widget_add_css_class(frame, "image-card");

    return frame;
}

static void render_layout(GtkBox *container) {
    if (!layout.images) {
        g_print("No images to render\n");
        return;
    }

    int num_images = g_list_length(layout.images);
    g_print("\nRendering %d images in masonry layout...\n", num_images);
    g_print("⚠️  MEMORY WARNING: Each image is loaded at full resolution!\n\n");

    int container_width = WINDOW_WIDTH - (IMAGE_SPACING * 2);
    int num_columns = container_width / (STANDARD_WIDTH + IMAGE_SPACING);
    if (num_columns > 5) num_columns = 5;
    if (num_columns < 2) num_columns = 2;

    g_print("Using %d columns for masonry layout\n\n", num_columns);

    GtkWidget *columns_container = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, IMAGE_SPACING);
    gtk_widget_set_halign(columns_container, GTK_ALIGN_CENTER);
    gtk_box_append(container, columns_container);

    GtkWidget **columns = g_new0(GtkWidget*, num_columns);
    int *column_heights = g_new0(int, num_columns);

    for (int i = 0; i < num_columns; i++) {
        columns[i] = gtk_box_new(GTK_ORIENTATION_VERTICAL, IMAGE_SPACING);
        gtk_widget_set_halign(columns[i], GTK_ALIGN_START);
        gtk_widget_set_valign(columns[i], GTK_ALIGN_START);
        gtk_box_append(GTK_BOX(columns_container), columns[i]);
        column_heights[i] = 0;
    }

    int image_index = 0;
    for (GList *l = layout.images; l != NULL; l = l->next) {
        ImageInfo *info = (ImageInfo *)l->data;

        int shortest_column = 0;
        for (int i = 1; i < num_columns; i++) {
            if (column_heights[i] < column_heights[shortest_column]) {
                shortest_column = i;
            }
        }

        int widget_width = STANDARD_WIDTH;
        int widget_height = info->target_height;

        GtkWidget *image_widget = create_rounded_image(info->path, widget_width, widget_height);

        gtk_widget_set_size_request(image_widget, widget_width, widget_height);
        gtk_box_append(GTK_BOX(columns[shortest_column]), image_widget);
        column_heights[shortest_column] += widget_height + IMAGE_SPACING;

        image_index++;
        g_print("[%d/%d] Added to column %d (height: %d)\n",
                image_index, num_images, shortest_column, column_heights[shortest_column]);
    }

    g_print("\n=== ALL IMAGES LOADED (NO OPTIMIZATION) ===\n");
    g_print("Check system memory usage now with: ps aux | grep wallpin\n\n");

    g_free(columns);
    g_free(column_heights);
}

static gboolean auto_scroll_tick(G_GNUC_UNUSED gpointer user_data) {
    if (!auto_scroll_enabled || !scroll_adjustment) {
        return G_SOURCE_CONTINUE;
    }

    double upper = gtk_adjustment_get_upper(scroll_adjustment);
    double page_size = gtk_adjustment_get_page_size(scroll_adjustment);
    double max_scroll = upper - page_size;

    if (max_scroll <= 0) {
        return G_SOURCE_CONTINUE;
    }

    current_scroll_position += SCROLL_SPEED;

    if (current_scroll_position >= max_scroll) {
        current_scroll_position = 0.0;
    }

    gtk_adjustment_set_value(scroll_adjustment, current_scroll_position);

    return G_SOURCE_CONTINUE;
}

static void setup_infinite_scroll(GtkWidget *scroll_window) {
    main_scroll_window = scroll_window;
    scroll_adjustment = gtk_scrolled_window_get_vadjustment(GTK_SCROLLED_WINDOW(scroll_window));

    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scroll_window),
                                  GTK_POLICY_NEVER,
                                  GTK_POLICY_EXTERNAL);

    gtk_widget_set_can_focus(scroll_window, FALSE);

    if (scroll_timer_id > 0) {
        g_source_remove(scroll_timer_id);
    }

    scroll_timer_id = g_timeout_add(SCROLL_INTERVAL, auto_scroll_tick, NULL);

    g_print("Auto-scroll infinito iniciado (velocidad: %.1f px/frame)\n", SCROLL_SPEED);
}

static void toggle_auto_scroll(void) {
    auto_scroll_enabled = !auto_scroll_enabled;
    g_print("Auto-scroll %s\n", auto_scroll_enabled ? "activado" : "pausado");
}

static gboolean on_key_pressed(GtkEventControllerKey *controller,
                              guint keyval,
                              guint keycode,
                              GdkModifierType state,
                              gpointer user_data) {
    (void)controller;
    (void)keycode;
    (void)state;
    (void)user_data;

    switch (keyval) {
        case GDK_KEY_space:
            toggle_auto_scroll();
            return TRUE;
        case GDK_KEY_Escape:
            gtk_window_close(GTK_WINDOW(gtk_widget_get_root(GTK_WIDGET(controller))));
            return TRUE;
        case GDK_KEY_m:  // Tecla 'M' para mostrar uso de memoria
            system("ps aux | grep wallpin | grep -v grep");
            return TRUE;
    }
    return FALSE;
}

static void activate(GtkApplication *app, G_GNUC_UNUSED gpointer user_data) {
    GtkWidget *window;
    GtkWidget *scroll;
    GtkWidget *grid;

    window = gtk_application_window_new(app);
    gtk_window_set_title(GTK_WINDOW(window), "WallPin - NO OPTIMIZATION MODE");

    gtk_window_fullscreen(GTK_WINDOW(window));
    gtk_window_set_decorated(GTK_WINDOW(window), FALSE);

    apply_css_to_window(window);

    GtkSettings *settings = gtk_settings_get_default();
    g_object_set(settings, "gtk-application-prefer-dark-theme", TRUE, NULL);

    scroll = gtk_scrolled_window_new();
    gtk_window_set_child(GTK_WINDOW(window), scroll);

    grid = create_image_grid();
    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(scroll), grid);
    load_images_from_directory(GTK_BOX(grid), ASSETS_DIR);

    setup_infinite_scroll(scroll);

    GtkEventController *key_controller = gtk_event_controller_key_new();
    g_signal_connect(key_controller, "key-pressed", G_CALLBACK(on_key_pressed), NULL);
    gtk_widget_add_controller(window, key_controller);

    gtk_window_present(GTK_WINDOW(window));

    gtk_widget_add_css_class(window, "dark-window");
}

static void cleanup_auto_scroll(void) {
    if (scroll_timer_id > 0) {
        g_source_remove(scroll_timer_id);
        scroll_timer_id = 0;
    }
}

int main(int argc, char **argv) {
    GtkApplication *app;
    int status;

    app = gtk_application_new("org.gtk.wallpin", G_APPLICATION_DEFAULT_FLAGS);
    g_signal_connect(app, "activate", G_CALLBACK(activate), NULL);
    status = g_application_run(G_APPLICATION(app), argc, argv);

    cleanup_auto_scroll();
    masonry_layout_free(&layout);

    g_object_unref(app);
    return status;
}
