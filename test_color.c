#include <stdio.h>
#include <string.h>
#include "color_analysis.h"

int main(int argc, char *argv[]) {
    if (argc != 2) {
        printf("Uso: %s <imagen>\n", argv[0]);
        return 1;
    }
    
    const char *image_path = argv[1];
    
    // Probar ImageMagick si está disponible
    if (check_imagemagick_available()) {
        printf("🎨 ImageMagick detectado - Análisis avanzado:\n");
        Color color_im = extract_color_imagemagick(image_path);
        printf("  RGB: (%d, %d, %d)\n", color_im.r, color_im.g, color_im.b);
        printf("  HSL: (%.1f°, %.1f%%, %.1f%%)\n", 
               color_im.hue, color_im.saturation * 100, color_im.lightness * 100);
    } else {
        printf("❌ ImageMagick no disponible\n");
    }
    
    // Probar método nativo
    printf("\n🔧 Método nativo (promedio de píxeles):\n");
    Color color_native = extract_color_native(image_path);
    printf("  RGB: (%d, %d, %d)\n", color_native.r, color_native.g, color_native.b);
    printf("  HSL: (%.1f°, %.1f%%, %.1f%%)\n", 
           color_native.hue, color_native.saturation * 100, color_native.lightness * 100);
    
    return 0;
}
