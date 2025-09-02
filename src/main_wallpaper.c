// WallPin - Wallpape// Función para configurar FPS sin afectar la velocidad de scroll
static void set_target_fps(int fps);

// Función para configurar velocidad de scroll sin afectar FPS
static void set_scroll_speed(double speed_per_second);

// Función para inicializar valores por defecto
static void init_scroll_config(void);

// Variables para auto-scroll infinitode with Layer Shell

#include <gtk/gtk.h>
#include <dirent.h>
#include <string.h>
#include "wallpaper.h"
#include "config.h"
#include "utils.h"
#include "layout.h"
#include "layer_shell.h"

#define WINDOW_HEIGHT 1080
#define CORNER_RADIUS 16

static MasonryLayout layout;

static GtkWidget *create_image_grid(void);
static void load_images_from_directory(GtkBox *container, const char *dir_path);
static GtkWidget *create_rounded_image(const char *image_path, int target_width, int target_height);
static void render_layout(GtkBox *container);

// Función para configurar FPS sin afectar la velocidad
static void set_target_fps(int fps);

// Variables para auto-scroll infinito
static GtkWidget *main_scroll_window = NULL;
static GtkAdjustment *scroll_adjustment = NULL;
static guint scroll_timer_id = 0;
static double current_scroll_position = 0.0;
static gboolean auto_scroll_enabled = TRUE;

// Variables configurables para FPS
static int current_target_fps = 60;      // Valor por defecto
static int current_scroll_interval = 16; // 60 FPS por defecto (1000/60)
static double current_scroll_speed = 0.3; // Se calculará en base a velocidad configurada

// Variables configurables para velocidad
static double current_speed_per_second = 18.0; // Velocidad configurable en px/s

// Configuración del auto-scroll para wallpaper
#define SCROLL_SPEED_PER_SECOND 18.0  // Velocidad en pixels por segundo (independiente de FPS)
#define TARGET_FPS 60                 // FPS deseados (60, 120, 144, 240, etc.)

// Cálculos automáticos basados en TARGET_FPS
#define SCROLL_INTERVAL (1000 / TARGET_FPS)                    // Intervalo en ms
#define SCROLL_SPEED (SCROLL_SPEED_PER_SECOND / TARGET_FPS)    // Pixels por frame

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
    g_print("=== WALLPAPER MODE - LOADING IMAGES ===\n");

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

    g_print("Found %d images for wallpaper\n", image_count);

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
    
    // Cargar la imagen completa
    GdkPixbuf *original_pixbuf = gdk_pixbuf_new_from_file(image_path, &error);
    
    if (error) {
        g_warning("Error loading image %s: %s", image_path, error->message);
        g_error_free(error);
        return gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    }

    // Escalar la imagen
    GdkPixbuf *scaled_pixbuf = gdk_pixbuf_scale_simple(original_pixbuf, 
                                                        target_width, 
                                                        target_height,
                                                        GDK_INTERP_BILINEAR);
    
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
    
    // Asegurar que las imágenes puedan recibir eventos hover en modo wallpaper
    gtk_widget_set_sensitive(frame, TRUE);
    gtk_widget_set_can_focus(frame, FALSE); // No queremos focus, solo hover

    return frame;
}

static void render_layout(GtkBox *container) {
    if (!layout.images) {
        g_print("No images to render\n");
        return;
    }

    int num_images = g_list_length(layout.images);
    g_print("\nRendering %d images in wallpaper masonry layout...\n", num_images);

    int container_width = WINDOW_WIDTH - (IMAGE_SPACING * 2);
    int num_columns = container_width / (STANDARD_WIDTH + IMAGE_SPACING);
    
    // Usar MAX_IMAGES_PER_ROW del layout.h
    if (num_columns > MAX_IMAGES_PER_ROW) num_columns = MAX_IMAGES_PER_ROW;
    if (num_columns < 2) num_columns = 2;

    g_print("Using %d columns for wallpaper layout (max allowed: %d)\n\n", num_columns, MAX_IMAGES_PER_ROW);

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
    }

    g_print("\n=== WALLPAPER IMAGES LOADED ===\n");

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

    // Incrementar posición de scroll por current_scroll_speed pixels por frame
    // La velocidad en pixels/segundo se mantiene constante independientemente de los FPS
    current_scroll_position += current_scroll_speed;

    if (current_scroll_position >= max_scroll) {
        current_scroll_position = 0.0;
    }

    gtk_adjustment_set_value(scroll_adjustment, current_scroll_position);

    return G_SOURCE_CONTINUE;
}

// Función para inicializar valores por defecto de scroll
static void init_scroll_config(void) {
    current_target_fps = TARGET_FPS;
    current_scroll_interval = SCROLL_INTERVAL;
    current_speed_per_second = SCROLL_SPEED_PER_SECOND;
    current_scroll_speed = current_speed_per_second / current_target_fps;
}

// Función para configurar FPS sin afectar la velocidad de scroll
static void set_target_fps(int fps) {
    if (fps < 30 || fps > 500) {
        g_print("⚠️  FPS fuera de rango válido (30-500), usando %d\n", current_target_fps);
        return;
    }
    
    // Detener el timer actual si existe
    if (scroll_timer_id > 0) {
        g_source_remove(scroll_timer_id);
        scroll_timer_id = 0;
    }
    
    // Actualizar configuración
    current_target_fps = fps;
    current_scroll_interval = 1000 / fps;  // ms por frame
    current_scroll_speed = current_speed_per_second / fps;  // pixels por frame usando velocidad actual
    
    // Reiniciar el timer con la nueva configuración
    if (auto_scroll_enabled && scroll_adjustment) {
        scroll_timer_id = g_timeout_add(current_scroll_interval, auto_scroll_tick, NULL);
        g_print("🎯 FPS configurados a %d (intervalo: %dms, velocidad: %.3f px/frame)\n", 
                current_target_fps, current_scroll_interval, current_scroll_speed);
        g_print("📈 Velocidad constante: %.1f pixels/segundo\n", current_speed_per_second);
    }
}

// Función para configurar velocidad de scroll sin afectar FPS
static void set_scroll_speed(double speed_per_second) {
    if (speed_per_second < 1.0 || speed_per_second > 100.0) {
        g_print("⚠️  Velocidad fuera de rango válido (1.0-100.0 px/s), usando %.1f\n", current_speed_per_second);
        return;
    }
    
    // Detener el timer actual si existe
    if (scroll_timer_id > 0) {
        g_source_remove(scroll_timer_id);
        scroll_timer_id = 0;
    }
    
    // Actualizar configuración de velocidad
    current_speed_per_second = speed_per_second;
    current_scroll_speed = current_speed_per_second / current_target_fps;  // Recalcular px/frame
    
    // Reiniciar el timer con la nueva configuración
    if (auto_scroll_enabled && scroll_adjustment) {
        scroll_timer_id = g_timeout_add(current_scroll_interval, auto_scroll_tick, NULL);
        g_print("🚀 Velocidad configurada: %.1f px/s (%.3f px/frame a %d FPS)\n", 
                current_speed_per_second, current_scroll_speed, current_target_fps);
    }
}

// Bloquear eventos de scroll del usuario
static gboolean block_scroll_events(GtkEventControllerScroll *controller, 
                                   gdouble dx, gdouble dy, gpointer user_data) {
    // Evitar warnings de parámetros no utilizados
    (void)controller;
    (void)dx;
    (void)dy;
    (void)user_data;
    
    // Bloquear completamente todos los eventos de scroll
    return TRUE; // TRUE = evento manejado, no propagar
}

// Bloquear eventos de drag
static gboolean block_drag_events(GtkGestureDrag *gesture, 
                                 gdouble start_x, gdouble start_y, gpointer user_data) {
    // Evitar warnings de parámetros no utilizados
    (void)gesture;
    (void)start_x;
    (void)start_y;
    (void)user_data;
    
    // Bloquear arrastre
    return TRUE;
}

static void setup_infinite_scroll(GtkWidget *scroll_window) {
    main_scroll_window = scroll_window;
    scroll_adjustment = gtk_scrolled_window_get_vadjustment(GTK_SCROLLED_WINDOW(scroll_window));

    // Configurar políticas de scroll
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scroll_window),
                                  GTK_POLICY_NEVER,
                                  GTK_POLICY_EXTERNAL);

    // Deshabilitar focus pero mantener sensibilidad para hover
    gtk_widget_set_can_focus(scroll_window, FALSE);
    gtk_widget_set_focusable(scroll_window, FALSE);
    
    // Bloquear eventos de scroll del usuario - con mayor prioridad
    GtkEventController *scroll_controller = gtk_event_controller_scroll_new(
        GTK_EVENT_CONTROLLER_SCROLL_VERTICAL | GTK_EVENT_CONTROLLER_SCROLL_DISCRETE);
    gtk_event_controller_set_propagation_phase(scroll_controller, GTK_PHASE_CAPTURE);
    gtk_widget_add_controller(scroll_window, scroll_controller);
    g_signal_connect(scroll_controller, "scroll", G_CALLBACK(block_scroll_events), NULL);
    
    // Bloquear gestos de arrastre con prioridad alta
    GtkGesture *drag_gesture = gtk_gesture_drag_new();
    gtk_event_controller_set_propagation_phase(GTK_EVENT_CONTROLLER(drag_gesture), GTK_PHASE_CAPTURE);
    gtk_widget_add_controller(scroll_window, GTK_EVENT_CONTROLLER(drag_gesture));
    g_signal_connect(drag_gesture, "drag-begin", G_CALLBACK(block_drag_events), NULL);

    if (scroll_timer_id > 0) {
        g_source_remove(scroll_timer_id);
    }

    scroll_timer_id = g_timeout_add(current_scroll_interval, auto_scroll_tick, NULL);

    g_print("🚀 Wallpaper auto-scroll iniciado:\n");
    g_print("   FPS: %d | Intervalo: %dms | Velocidad: %.1f px/s\n", 
            current_target_fps, current_scroll_interval, current_speed_per_second);
}

// Estructura para pasar datos a la función activate
typedef struct {
    const char *monitor_name;
    int target_fps;
    double target_speed;
} AppData;

static void activate(GtkApplication *app, gpointer user_data) {
    AppData *data = (AppData *)user_data;
    GtkWidget *window;
    GtkWidget *scroll;
    GtkWidget *grid;

    window = gtk_application_window_new(app);
    
    if (data && data->monitor_name) {
        gtk_window_set_title(GTK_WINDOW(window), g_strdup_printf("WallPin - Wallpaper Mode (%s)", data->monitor_name));
    } else {
        gtk_window_set_title(GTK_WINDOW(window), "WallPin - Wallpaper Mode");
    }
    
    // Establecer tamaño por defecto antes del layer shell
    gtk_window_set_default_size(GTK_WINDOW(window), 1920, 1080);

    // Configurar layer shell para wallpaper en monitor específico
    if (data && data->monitor_name) {
        layer_shell_init_window_for_monitor(GTK_WINDOW(window), data->monitor_name);
    } else {
        layer_shell_init_window(GTK_WINDOW(window));
    }
    layer_shell_configure_wallpaper(GTK_WINDOW(window));

    apply_css_to_window(window);

    // Configurar tema oscuro
    GtkSettings *settings = gtk_settings_get_default();
    g_object_set(settings, "gtk-application-prefer-dark-theme", TRUE, NULL);

    scroll = gtk_scrolled_window_new();
    
    // Configurar para wallpaper: mantener sensibilidad para hover pero bloquear scroll
    gtk_widget_set_can_focus(scroll, FALSE);
    gtk_widget_set_focusable(scroll, FALSE);
    // NO deshabilitar sensitive - esto bloquearía el hover
    
    gtk_window_set_child(GTK_WINDOW(window), scroll);

    grid = create_image_grid();
    
    // Mantener sensibilidad para efectos hover
    gtk_widget_set_sensitive(grid, TRUE);
    
    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(scroll), grid);
    load_images_from_directory(GTK_BOX(grid), ASSETS_DIR);

    // Configurar FPS si se especificó
    if (data && data->target_fps > 0) {
        set_target_fps(data->target_fps);
    }
    
    // Configurar velocidad si se especificó
    if (data && data->target_speed > 0) {
        set_scroll_speed(data->target_speed);
    }

    setup_infinite_scroll(scroll);

    gtk_window_present(GTK_WINDOW(window));

    gtk_widget_add_css_class(window, "dark-window");
    
    g_print("WallPin wallpaper mode activated!\n");
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
    AppData app_data = {NULL, 0, 0.0};
    
    // Inicializar configuración de scroll
    init_scroll_config();
    
    // Procesar argumentos ANTES de crear la aplicación GTK
    int gtk_argc = 1;  // Solo argv[0] para GTK
    char **gtk_argv = malloc(sizeof(char*) * argc);
    gtk_argv[0] = argv[0];  // Nombre del programa
    
    // Procesar argumentos personalizados
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--monitor") == 0 || strcmp(argv[i], "-m") == 0) {
            if (i + 1 < argc) {
                app_data.monitor_name = argv[i + 1];
                i++; // Saltar el siguiente argumento
            } else {
                g_print("Error: --monitor requiere un nombre de monitor\n");
                g_print("Uso: %s --monitor <nombre_monitor>\n", argv[0]);
                g_print("Ejemplo: %s --monitor HDMI-A-1\n", argv[0]);
                free(gtk_argv);
                return 1;
            }
        } else if (strcmp(argv[i], "--fps") == 0 || strcmp(argv[i], "-f") == 0) {
            if (i + 1 < argc) {
                int fps = atoi(argv[i + 1]);
                if (fps >= 30 && fps <= 500) {
                    app_data.target_fps = fps;
                    i++; // Saltar el siguiente argumento
                } else {
                    g_print("Error: FPS debe estar entre 30 y 500\n");
                    free(gtk_argv);
                    return 1;
                }
            } else {
                g_print("Error: --fps requiere un valor numérico\n");
                free(gtk_argv);
                return 1;
            }
        } else if (strcmp(argv[i], "--speed") == 0 || strcmp(argv[i], "-s") == 0) {
            if (i + 1 < argc) {
                double speed = atof(argv[i + 1]);
                if (speed >= 1.0 && speed <= 100.0) {
                    app_data.target_speed = speed;
                    i++; // Saltar el siguiente argumento
                } else {
                    g_print("Error: Velocidad debe estar entre 1.0 y 100.0 px/s\n");
                    free(gtk_argv);
                    return 1;
                }
            } else {
                g_print("Error: --speed requiere un valor numérico\n");
                free(gtk_argv);
                return 1;
            }
        } else if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
            g_print("WallPin Wallpaper Mode\n");
            g_print("Uso: %s [opciones]\n", argv[0]);
            g_print("Opciones:\n");
            g_print("  --monitor, -m <nombre>  Especificar monitor (ej: HDMI-A-1, eDP-1)\n");
            g_print("  --fps, -f <número>      Configurar FPS (30-500, por defecto: %d)\n", TARGET_FPS);
            g_print("  --speed, -s <número>    Configurar velocidad (1.0-100.0 px/s, por defecto: %.1f)\n", SCROLL_SPEED_PER_SECOND);
            g_print("  --help, -h              Mostrar esta ayuda\n");
            g_print("\nEjemplos:\n");
            g_print("  %s                      # Por defecto: %d FPS, %.1f px/s\n", argv[0], TARGET_FPS, SCROLL_SPEED_PER_SECOND);
            g_print("  %s -f 120 -s 25.0       # 120 FPS, scroll rápido\n", argv[0]);
            g_print("  %s -f 240 -s 10.0       # 240 FPS ultra suave, scroll lento\n", argv[0]);
            g_print("  %s -m HDMI-A-1 -f 144 -s 30.0  # Monitor específico con config custom\n", argv[0]);
            g_print("\nFPS populares: 60, 120, 144, 165, 240, 360\n");
            g_print("Velocidades: 10.0 (lento), 18.0 (normal), 25.0 (rápido), 35.0 (muy rápido)\n");
            free(gtk_argv);
            return 0;
        } else {
            // Pasar argumentos desconocidos a GTK
            gtk_argv[gtk_argc++] = argv[i];
        }
    }

    if (app_data.monitor_name) {
        g_print("🖥️  Iniciando WallPin wallpaper en monitor: %s\n", app_data.monitor_name);
    } else {
        g_print("🖥️  Iniciando WallPin wallpaper en monitor por defecto\n");
    }
    
    if (app_data.target_fps > 0 || app_data.target_speed > 0) {
        g_print("🎯 Configuración personalizada:\n");
        if (app_data.target_fps > 0) {
            g_print("   FPS: %d\n", app_data.target_fps);
        } else {
            g_print("   FPS: %d (por defecto)\n", TARGET_FPS);
        }
        if (app_data.target_speed > 0) {
            g_print("   Velocidad: %.1f px/s\n", app_data.target_speed);
        } else {
            g_print("   Velocidad: %.1f px/s (por defecto)\n", SCROLL_SPEED_PER_SECOND);
        }
    } else {
        g_print("🎯 Configuración por defecto: %d FPS, %.1f px/s\n", 
                TARGET_FPS, SCROLL_SPEED_PER_SECOND);
    }

    // Crear application ID único para cada monitor para evitar conflictos
    char app_id[256];
    if (app_data.monitor_name) {
        // Reemplazar caracteres no válidos en el monitor name
        char clean_monitor[64];
        strncpy(clean_monitor, app_data.monitor_name, sizeof(clean_monitor) - 1);
        clean_monitor[sizeof(clean_monitor) - 1] = '\0';
        
        // Reemplazar caracteres no válidos para application ID
        for (char *p = clean_monitor; *p; p++) {
            if (*p == '-' || *p == ':') *p = '_';
        }
        
        snprintf(app_id, sizeof(app_id), "org.gtk.wallpin.wallpaper_%s", clean_monitor);
    } else {
        snprintf(app_id, sizeof(app_id), "org.gtk.wallpin.wallpaper_default");
    }

    g_print("Application ID: %s\n", app_id);

    app = gtk_application_new(app_id, G_APPLICATION_DEFAULT_FLAGS);
    g_signal_connect(app, "activate", G_CALLBACK(activate), &app_data);
    status = g_application_run(G_APPLICATION(app), gtk_argc, gtk_argv);

    cleanup_auto_scroll();
    masonry_layout_free(&layout);

    g_object_unref(app);
    free(gtk_argv);
    return status;
}
