#include "config.h"
#include <glib.h>
#include <stdio.h>

WallPinConfig *load_config(void) {
    WallPinConfig *config = g_new0(WallPinConfig, 1);
    GKeyFile *key_file = g_key_file_new();
    
    // Default values
    config->refresh_rate = 10;
    config->animation_speed = 500;
    config->columns = 4;

    if (g_key_file_load_from_file(key_file, CONFIG_FILE, G_KEY_FILE_NONE, NULL)) {
        // Try to read values from config file
        config->refresh_rate = g_key_file_get_integer(key_file, "Display", "refresh_rate", NULL);
        config->animation_speed = g_key_file_get_integer(key_file, "Display", "animation_speed", NULL);
        config->columns = g_key_file_get_integer(key_file, "Display", "columns", NULL);
    }

    g_key_file_free(key_file);
    return config;
}

void save_config(WallPinConfig *config) {
    GKeyFile *key_file = g_key_file_new();

    g_key_file_set_integer(key_file, "Display", "refresh_rate", config->refresh_rate);
    g_key_file_set_integer(key_file, "Display", "animation_speed", config->animation_speed);
    g_key_file_set_integer(key_file, "Display", "columns", config->columns);

    g_key_file_save_to_file(key_file, CONFIG_FILE, NULL);
    g_key_file_free(key_file);
}
