#include "color_analysis.h"
#include <math.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>

// Variable global para cachear si ImageMagick está disponible
static int imagemagick_available = -1; // -1 = no chequeado, 0 = no disponible, 1 = disponible
static gboolean force_native = FALSE;  // Forzar método nativo para pruebas

// Forzar uso del método nativo (para comparaciones)
void force_native_mode(gboolean force) {
    force_native = force;
    if (force) {
        g_print("🔧 Forzando modo nativo para comparación\n");
    }
}

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

// Función para verificar si ImageMagick está disponible
gboolean check_imagemagick_available() {
    // Solo verificar una vez
    if (imagemagick_available != -1) {
        return imagemagick_available == 1;
    }
    
    // Probar magick primero (ImageMagick v7+), luego convert (v6)
    if (system("which magick > /dev/null 2>&1") == 0) {
        imagemagick_available = 1;
        g_print("🎨 ImageMagick detectado: usando análisis de color avanzado\n");
        return TRUE;
    }
    
    if (system("which convert > /dev/null 2>&1") == 0) {
        imagemagick_available = 1; 
        g_print("🎨 ImageMagick detectado: usando análisis de color avanzado\n");
        return TRUE;
    }
    
    imagemagick_available = 0;
    g_print("⚠️  ImageMagick no disponible: usando método nativo\n");
    return FALSE;
}

// Parsear color desde formato hex (#RRGGBB)
Color parse_hex_color(const char *hex_str) {
    Color color = {128, 128, 128, 0, 0, 0.5}; // Color por defecto
    
    if (hex_str && strlen(hex_str) >= 7 && hex_str[0] == '#') {
        unsigned int hex_val;
        if (sscanf(hex_str + 1, "%06x", &hex_val) == 1) {
            color.r = (hex_val >> 16) & 0xFF;
            color.g = (hex_val >> 8) & 0xFF;
            color.b = hex_val & 0xFF;
            
            // Calcular HSL
            rgb_to_hsl(color.r, color.g, color.b, &color.hue, &color.saturation, &color.lightness);
        }
    }
    
    return color;
}

// Extraer color dominante usando ImageMagick
Color extract_color_imagemagick(const char *image_path) {
    Color default_color = {128, 128, 128, 0, 0, 0.5};
    FILE *pipe;
    char command[1024];
    char line[256];
    Color best_color = default_color;
    
    // Comando ImageMagick para obtener histograma de colores
    // -resize 100x100! = redimensionar a 100x100 (! ignora aspect ratio)
    // -colors 16 = reducir a 16 colores principales  
    // -depth 8 = profundidad de color 8 bits
    // +dither = sin dithering para colores más puros
    // -format "%c" histogram:info: = generar histograma en formato texto
    
    // Usar magick (v7+) o convert (v6) según disponibilidad
    if (system("which magick > /dev/null 2>&1") == 0) {
        snprintf(command, sizeof(command), 
                 "magick \"%s\" -resize 100x100! -colors 16 -depth 8 +dither -format \"%%c\" histogram:info: 2>/dev/null", 
                 image_path);
    } else {
        snprintf(command, sizeof(command), 
                 "convert \"%s\" -resize 100x100! -colors 16 -depth 8 +dither -format \"%%c\" histogram:info: 2>/dev/null", 
                 image_path);
    }
    
    pipe = popen(command, "r");
    if (!pipe) {
        g_warning("Error ejecutando ImageMagick para %s", image_path);
        return default_color;
    }
    
    // Parsear la salida del histograma
    // Formato: "  count: (r,g,b) #RRGGBB color_name"  
    // Buscar el mejor color combinando frecuencia y saturación
    double best_score = 0;
    
    while (fgets(line, sizeof(line), pipe)) {
        int count, r, g, b;
        char hex_color[8];
        
        // Buscar líneas con el formato del histograma
        if (sscanf(line, "%d: (%d,%d,%d) %7s", &count, &r, &g, &b, hex_color) == 5) {
            // Calcular luminancia para filtrar ruido
            double luminance = 0.299 * r + 0.587 * g + 0.114 * b;
            
            // Ignorar colores muy oscuros (< 15) o muy claros (> 240)
            if (luminance < 15 || luminance > 240) continue;
            
            // Calcular HSL para obtener saturación
            double hue, saturation, lightness;
            rgb_to_hsl(r, g, b, &hue, &saturation, &lightness);
            
            // Score combinado: frecuencia normalizada + saturación (favorece colores vibrantes)
            double normalized_freq = (double)count / 10000.0; // Normalizar frequencia
            double score = normalized_freq + (saturation * 0.5); // Peso 50% a saturación
            
            if (score > best_score) {
                best_score = score;
                best_color.r = r;
                best_color.g = g;
                best_color.b = b;
                best_color.hue = hue;
                best_color.saturation = saturation;
                best_color.lightness = lightness;
            }
        }
    }
    
    int result = pclose(pipe);
    if (result != 0) {
        g_warning("ImageMagick falló para %s, usando método nativo", image_path);
        // Fallback al método nativo
        GError *error = NULL;
        GdkPixbuf *pixbuf = gdk_pixbuf_new_from_file_at_scale(image_path, 100, 100, TRUE, &error);
        if (error) {
            g_error_free(error);
            return default_color;
        }
        Color native_color = get_average_color(pixbuf);
        g_object_unref(pixbuf);
        return native_color;
    }
    
    return best_color;
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

// Método nativo original (renombrado para claridad)
Color extract_color_native(const char *image_path) {
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

// Función principal que decide qué método usar
Color extract_dominant_color(const char *image_path) {
    static gboolean first_run = TRUE;
    
    // En la primera ejecución, verificar ImageMagick
    if (first_run) {
        check_imagemagick_available();
        first_run = FALSE;
    }
    
    // Si se fuerza el modo nativo o ImageMagick no está disponible
    if (force_native || imagemagick_available != 1) {
        return extract_color_native(image_path);
    } else {
        return extract_color_imagemagick(image_path);
    }
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
