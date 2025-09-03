#ifndef COLOR_ANALYSIS_H
#define COLOR_ANALYSIS_H

#include <gtk/gtk.h>
#include <glib.h>

// Estructura para representar un color RGB
typedef struct {
    int r, g, b;
    double hue;       // Matiz (0-360)
    double saturation; // Saturación (0-1)
    double lightness;  // Luminosidad (0-1)
} Color;

// Estructura para agrupar imágenes por color
typedef struct {
    Color dominant_color;
    GList *image_paths;  // Lista de rutas de imágenes con colores similares
    char *color_name;    // Nombre descriptivo del color (ej: "Azul", "Rojo cálido")
} ColorGroup;

// Modos de organización por color
typedef enum {
    COLOR_MODE_DEFAULT = 1,    // Modo normal sin agrupación
    COLOR_MODE_DOMINANT = 2,   // Agrupar por color dominante
    COLOR_MODE_PALETTE = 3,    // Agrupar por paleta de colores
    COLOR_MODE_HUE = 4,        // Agrupar por matiz (hue)
    COLOR_MODE_TEMPERATURE = 5 // Agrupar por temperatura (cálidos/fríos)
} ColorMode;

// Funciones principales
Color extract_dominant_color(const char *image_path);
void rgb_to_hsl(int r, int g, int b, double *h, double *s, double *l);
char* get_color_name(Color color);
ColorGroup* create_color_group(Color color);
void free_color_group(ColorGroup *group);
GList* group_images_by_color(GList *image_paths, ColorMode mode, int tolerance);
void print_color_analysis(GList *color_groups);

// Funciones de utilidad
double color_distance(Color c1, Color c2);
gboolean colors_similar(Color c1, Color c2, int tolerance);
Color get_average_color(GdkPixbuf *pixbuf);

#endif // COLOR_ANALYSIS_H
