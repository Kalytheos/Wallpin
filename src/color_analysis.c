#include "color_analysis.h"
#include <math.h>
#include <string.h>
#include <stdlib.h>

// Convertir RGB a HSL
void rgb_to_hsl(int r, int g, int b, double *h, double *s, double *l) {
    double rd = r / 255.0;
    double gd = g / 255.0;
    double bd = b / 255.0;
    
    double max = fmax(rd, fmax(gd, bd));
    double min = fmin(rd, fmin(gd, bd));
    double delta = max - min;
    
    // Luminosidad
    *l = (max + min) / 2.0;
    
    if (delta == 0) {
        *h = 0; // Gris
        *s = 0;
    } else {
        // Saturación
        if (*l < 0.5) {
            *s = delta / (max + min);
        } else {
            *s = delta / (2.0 - max - min);
        }
        
        // Matiz
        if (max == rd) {
            *h = 60 * (((gd - bd) / delta) + (gd < bd ? 6 : 0));
        } else if (max == gd) {
            *h = 60 * (((bd - rd) / delta) + 2);
        } else {
            *h = 60 * (((rd - gd) / delta) + 4);
        }
    }
}

// Obtener color promedio de una imagen
Color get_average_color(GdkPixbuf *pixbuf) {
    int width = gdk_pixbuf_get_width(pixbuf);
    int height = gdk_pixbuf_get_height(pixbuf);
    int channels = gdk_pixbuf_get_n_channels(pixbuf);
    int rowstride = gdk_pixbuf_get_rowstride(pixbuf);
    guchar *pixels = gdk_pixbuf_get_pixels(pixbuf);
    
    long long total_r = 0, total_g = 0, total_b = 0;
    int pixel_count = 0;
    
    // Muestrear cada N píxeles para eficiencia
    int sample_rate = 8; // Muestrear 1 de cada 8 píxeles
    
    for (int y = 0; y < height; y += sample_rate) {
        for (int x = 0; x < width; x += sample_rate) {
            guchar *pixel = pixels + y * rowstride + x * channels;
            
            total_r += pixel[0];
            total_g += pixel[1];
            total_b += pixel[2];
            pixel_count++;
        }
    }
    
    Color color;
    if (pixel_count > 0) {
        color.r = total_r / pixel_count;
        color.g = total_g / pixel_count;
        color.b = total_b / pixel_count;
    } else {
        color.r = color.g = color.b = 128; // Gris por defecto
    }
    
    // Calcular HSL
    rgb_to_hsl(color.r, color.g, color.b, &color.hue, &color.saturation, &color.lightness);
    
    return color;
}

// Extraer color dominante de una imagen
Color extract_dominant_color(const char *image_path) {
    GError *error = NULL;
    Color default_color = {128, 128, 128, 0, 0, 0.5}; // Gris por defecto
    
    // Cargar imagen con tamaño reducido para eficiencia
    GdkPixbuf *pixbuf = gdk_pixbuf_new_from_file_at_scale(image_path, 100, 100, TRUE, &error);
    
    if (error) {
        g_warning("Error loading image for color analysis %s: %s", image_path, error->message);
        g_error_free(error);
        return default_color;
    }
    
    Color dominant_color = get_average_color(pixbuf);
    g_object_unref(pixbuf);
    
    return dominant_color;
}

// Obtener nombre descriptivo del color
char* get_color_name(Color color) {
    double h = color.hue;
    double s = color.saturation;
    double l = color.lightness;
    
    // Colores acromáticos (grises)
    if (s < 0.1) {
        if (l < 0.2) return g_strdup("Negro");
        else if (l < 0.4) return g_strdup("Gris Oscuro");
        else if (l < 0.6) return g_strdup("Gris");
        else if (l < 0.8) return g_strdup("Gris Claro");
        else return g_strdup("Blanco");
    }
    
    // Colores cromáticos
    char *base_name;
    if (h < 15 || h >= 345) base_name = "Rojo";
    else if (h < 45) base_name = "Naranja";
    else if (h < 75) base_name = "Amarillo";
    else if (h < 150) base_name = "Verde";
    else if (h < 210) base_name = "Azul";
    else if (h < 270) base_name = "Púrpura";
    else if (h < 315) base_name = "Magenta";
    else base_name = "Rosa";
    
    // Modificadores por saturación y luminosidad
    char *modifier = "";
    if (l < 0.3) modifier = " Oscuro";
    else if (l > 0.7 && s > 0.3) modifier = " Claro";
    else if (s < 0.3) modifier = " Pálido";
    else if (s > 0.8) modifier = " Vibrante";
    
    return g_strdup_printf("%s%s", base_name, modifier);
}

// Calcular distancia entre colores
double color_distance(Color c1, Color c2) {
    // Distancia euclidiana en espacio HSL (más perceptualmente uniforme)
    double dh = fmin(fabs(c1.hue - c2.hue), 360 - fabs(c1.hue - c2.hue));
    double ds = c1.saturation - c2.saturation;
    double dl = c1.lightness - c2.lightness;
    
    // Pesos ajustados para percepción humana
    return sqrt(0.5 * dh * dh + 2.0 * ds * ds + 1.0 * dl * dl);
}

// Verificar si dos colores son similares
gboolean colors_similar(Color c1, Color c2, int tolerance) {
    double distance = color_distance(c1, c2);
    double max_distance = tolerance / 10.0; // Escalado del tolerance
    return distance < max_distance;
}

// Crear nuevo grupo de color
ColorGroup* create_color_group(Color color) {
    ColorGroup *group = g_malloc0(sizeof(ColorGroup));
    group->dominant_color = color;
    group->image_paths = NULL;
    group->color_name = get_color_name(color);
    return group;
}

// Liberar grupo de color
void free_color_group(ColorGroup *group) {
    if (group) {
        g_list_free_full(group->image_paths, g_free);
        g_free(group->color_name);
        g_free(group);
    }
}

// Agrupar imágenes por color
GList* group_images_by_color(GList *image_paths, ColorMode mode, int tolerance) {
    GList *color_groups = NULL;
    
    g_print("🎨 Analizando colores de %d imágenes (modo: %d)...\n", g_list_length(image_paths), mode);
    
    int processed = 0;
    int total = g_list_length(image_paths);
    
    for (GList *l = image_paths; l != NULL; l = l->next) {
        const char *image_path = (const char *)l->data;
        Color image_color = extract_dominant_color(image_path);
        
        processed++;
        if (processed % 10 == 0 || processed == total) {
            g_print("   Procesadas: %d/%d (%.1f%%)\n", processed, total, (processed * 100.0) / total);
        }
        
        // Buscar grupo existente con color similar
        ColorGroup *target_group = NULL;
        for (GList *g = color_groups; g != NULL; g = g->next) {
            ColorGroup *group = (ColorGroup *)g->data;
            if (colors_similar(image_color, group->dominant_color, tolerance)) {
                target_group = group;
                break;
            }
        }
        
        // Si no se encontró grupo similar, crear uno nuevo
        if (!target_group) {
            target_group = create_color_group(image_color);
            color_groups = g_list_append(color_groups, target_group);
        }
        
        // Agregar imagen al grupo
        target_group->image_paths = g_list_append(target_group->image_paths, g_strdup(image_path));
    }
    
    g_print("✅ Análisis completado: %d grupos de colores creados\n", g_list_length(color_groups));
    
    return color_groups;
}

// Imprimir análisis de colores
void print_color_analysis(GList *color_groups) {
    g_print("\n🎨 === ANÁLISIS DE COLORES ===\n");
    
    int group_num = 1;
    for (GList *l = color_groups; l != NULL; l = l->next) {
        ColorGroup *group = (ColorGroup *)l->data;
        int image_count = g_list_length(group->image_paths);
        
        g_print("Grupo %d: %s\n", group_num++, group->color_name);
        g_print("  Color RGB: (%d, %d, %d)\n", 
                group->dominant_color.r, 
                group->dominant_color.g, 
                group->dominant_color.b);
        g_print("  HSL: (%.1f°, %.1f%%, %.1f%%)\n", 
                group->dominant_color.hue, 
                group->dominant_color.saturation * 100, 
                group->dominant_color.lightness * 100);
        g_print("  Imágenes: %d\n", image_count);
        g_print("\n");
    }
}
