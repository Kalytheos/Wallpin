#include "layout.h"
#include <gdk-pixbuf/gdk-pixbuf.h>

static ImageInfo* create_image_info(const char *path, GHashTable *loaded_paths) {
    // Check if we've already loaded this image
    if (g_hash_table_contains(loaded_paths, path)) {
        g_print("Skipping duplicate image: %s\n", path);
        return NULL;
    }

    ImageInfo *info = g_new0(ImageInfo, 1);
    info->path = g_strdup(path);
    g_hash_table_add(loaded_paths, info->path);
    
    // Load image to get dimensions
    GError *error = NULL;
    GdkPixbuf *pixbuf = gdk_pixbuf_new_from_file(path, &error);
    if (pixbuf) {
        info->original_width = gdk_pixbuf_get_width(pixbuf);
        info->original_height = gdk_pixbuf_get_height(pixbuf);
        info->aspect_ratio = (double)info->original_width / info->original_height;
        g_print("Loaded image: %s (%dx%d, ratio: %.2f)\n", 
                path, info->original_width, info->original_height, info->aspect_ratio);
        g_object_unref(pixbuf);
    } else {
        g_warning("Could not load image %s: %s", path, error->message);
        g_error_free(error);
        info->original_width = 300;
        info->original_height = 300;
        info->aspect_ratio = 1.0;
    }
    
    return info;
};

void masonry_layout_init(MasonryLayout *layout, int grid_width, int row_height, int spacing) {
    layout->images = NULL;
    layout->grid_width = grid_width;
    layout->row_height = row_height;
    layout->spacing = spacing;
    
    // Crear hash table único para esta instancia del layout
    layout->loaded_paths = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, NULL);
}

static void classify_and_size_image(ImageInfo *info) {
    // Determine aspect ratio and type
    if (info->original_height > 0) {
        info->aspect_ratio = (double)info->original_width / (double)info->original_height;
    } else {
        info->aspect_ratio = 1.0; // Fallback to square
    }

    if (info->aspect_ratio < VERTICAL_RATIO_THRESHOLD) {
        info->image_type = IMAGE_VERTICAL;
    } else if (info->aspect_ratio > HORIZONTAL_RATIO_THRESHOLD) {
        info->image_type = IMAGE_HORIZONTAL;
    } else {
        info->image_type = IMAGE_SQUARE;
    }

    // All cards share the same width; height adapts to the image (Pinterest-style)
    info->target_width  = STANDARD_WIDTH;
    if (info->aspect_ratio <= 0.0) {
        info->target_height = STANDARD_WIDTH; // safety
    } else {
        // height = width / (w/h)
        info->target_height = (int) ((double)info->target_width / info->aspect_ratio + 0.5);
    }
    // Clamp absurdly tall items to avoid runaway (optional soft cap)
    if (info->image_type == IMAGE_VERTICAL && info->target_height > MAX_VERTICAL_HEIGHT) {
        info->target_height = MAX_VERTICAL_HEIGHT;
    }
}

static void calculate_row_layout(GList *start, int count) {
    if (count == 0) return;

    int current_count = 0;
    double row_width = 0;
    GList *l = start;

    // Calcular tamaños y limitar imágenes por fila
    while (l && current_count < MAX_IMAGES_PER_ROW) {
        ImageInfo *info = l->data;
        
        // Clasificar y asignar tamaño estándar
        classify_and_size_image(info);
        
        // Verificar si la imagen cabe en la fila actual
        double new_width = row_width + info->target_width;
        if (current_count > 0) {
            new_width += IMAGE_SPACING;
        }
        
        if (new_width > WINDOW_WIDTH - (IMAGE_SPACING * 2)) {
            break;
        }
        
        row_width = new_width;
        current_count++;
        l = l->next;
    }

    // Ajustar alturas si es necesario para mantener proporciones
    l = start;
    for (int i = 0; i < current_count && l; i++) {
        ImageInfo *info = l->data;
        double target_ratio = (double)info->target_width / info->target_height;
        
        // Si la proporción es significativamente diferente, ajustar altura
        if (fabs(target_ratio - info->aspect_ratio) > 0.01) {
            info->target_height = info->target_width / info->aspect_ratio;
        }
        l = l->next;
    }
}


static GList *find_similar_images(GList *start, ImageInfo *reference, int max_count, int available_width) {
    GList *group = NULL;
    ImageType target_type = reference->image_type;
    int count = 0;
    double total_width = 0;
    int required_count = (target_type == IMAGE_VERTICAL) ? 2 : 3;
    
    // First pass: count available similar images
    int available_count = 0;
    for (GList *l = start; l && available_count < max_count; l = l->next) {
        ImageInfo *info = l->data;
        if (info->image_type == target_type) {
            available_count++;
        }
    }
    
    // If not enough vertical images, try squares instead
    if (target_type == IMAGE_VERTICAL && available_count < required_count) {
        target_type = IMAGE_SQUARE;
        max_count = 3;
    }
    
    for (GList *l = start; l && count < max_count; l = l->next) {
        ImageInfo *info = l->data;
        if (info->image_type == target_type) {
            double standard_width = STANDARD_WIDTH;            if (total_width + standard_width + IMAGE_SPACING > available_width) {
                break;
            }
            
            group = g_list_append(group, info);
            total_width += standard_width + IMAGE_SPACING;
            count++;
        }
    }
    
    return group;
}

void masonry_layout_add_image(MasonryLayout *layout, const char *path) {
    ImageInfo *info = create_image_info(path, layout->loaded_paths);
    if (info) {  // Solo añadir si no es un duplicado
        layout->images = g_list_append(layout->images, info);
    }
}

void masonry_layout_calculate(MasonryLayout *layout) {
    if (!layout->images) return;

    int available_width = layout->grid_width - (2 * IMAGE_SPACING);
    GList *current = layout->images;
    GList *processed_images = NULL;

    while (current) {
        ImageInfo *info = current->data;
        GList *group = find_similar_images(current, info, 
                                         info->image_type == IMAGE_VERTICAL ? 2 : 3, 
                                         available_width);
        
        if (group) {
            int count = g_list_length(group);
            // Calculate layout for the group
            calculate_row_layout(group, count);
            
            // Add to processed list
            processed_images = g_list_concat(processed_images, group);
            
            // Skip the processed images
            for (int i = 0; i < count && current; i++) {
                current = current->next;
            }
        } else {
            // If we couldn't form a group, just add this image alone
            GList *single = g_list_append(NULL, info);
            calculate_row_layout(single, 1);
            processed_images = g_list_append(processed_images, info);
            current = current->next;
        }
    }

    // Update the layout's image list with the new order
    layout->images = processed_images;
}

void masonry_layout_free(MasonryLayout *layout) {
    // Liberar hash table de esta instancia
    if (layout->loaded_paths) {
        g_hash_table_destroy(layout->loaded_paths);
        layout->loaded_paths = NULL;
    }
    
    GList *l;
    for (l = layout->images; l; l = l->next) {
        ImageInfo *info = l->data;
        g_free(info->path);
        g_free(info);
    }
    g_list_free(layout->images);
    layout->images = NULL;
}
