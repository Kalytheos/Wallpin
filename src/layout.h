#ifndef LAYOUT_H
#define LAYOUT_H

#include <gtk/gtk.h>

// Tamaños estándar para el layout tipo Pinterest
#define STANDARD_WIDTH 280            // Ancho estándar base para todas las imágenes

// Alturas según el tipo de imagen (manteniendo proporciones estándar)
#define VERTICAL_HEIGHT 498          // Alto para imágenes verticales (9:16 -> 280x498)
#define HORIZONTAL_HEIGHT 158        // Alto para imágenes horizontales (16:9 -> 280x158)
#define SQUARE_HEIGHT 280           // Alto para imágenes cuadradas (1:1 -> 280x280)

// Límite de altura máxima para imágenes verticales muy altas
#define MAX_VERTICAL_HEIGHT 500

// Umbrales para clasificación de imágenes
#define VERTICAL_RATIO_THRESHOLD 0.75   // Para imágenes verticales (menor que 0.75)
#define HORIZONTAL_RATIO_THRESHOLD 1.33 // Para imágenes horizontales (mayor que 1.33)

// Límites y espaciado
#define MAX_IMAGES_PER_ROW 4          // Número máximo de imágenes por fila
#define IMAGE_SPACING 32 //16              // Espaciado entre imágenes
#define WINDOW_WIDTH 1920            // Ancho de la ventana

typedef enum {
    IMAGE_VERTICAL,   // Aspect ratio < 0.75 (más alto que ancho, ej: 9:16)
    IMAGE_SQUARE,     // Aspect ratio between 0.75 and 1.33
    IMAGE_HORIZONTAL  // Aspect ratio > 1.33 (más ancho que alto, ej: 16:9)
} ImageType;

typedef struct {
    char *path;
    int original_width;
    int original_height;
    double aspect_ratio;
    int target_width;
    int target_height;
    ImageType image_type;
} ImageInfo;

typedef struct {
    GList *images;
    int grid_width;
    int row_height;
    int spacing;
    GHashTable *loaded_paths;  // Hash table para tracking de imágenes cargadas
} MasonryLayout;

void masonry_layout_init(MasonryLayout *layout, int grid_width, int row_height, int spacing);
void masonry_layout_add_image(MasonryLayout *layout, const char *path);
void masonry_layout_calculate(MasonryLayout *layout);
void masonry_layout_free(MasonryLayout *layout);

#endif // LAYOUT_H
