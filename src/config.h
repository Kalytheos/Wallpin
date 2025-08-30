#ifndef CONFIG_H
#define CONFIG_H

#define ASSETS_DIR "/home/kalytheos/Documents/Proyectos/WallPin/assets"
#define CONFIG_FILE "/home/kalytheos/Documents/Proyectos/WallPin/config/settings.ini"

// Configuration settings structure
typedef struct {
    int refresh_rate;      // Image refresh rate in seconds
    int animation_speed;   // Transition animation speed
    int columns;          // Number of columns in the grid
} WallPinConfig;

// Function declarations
WallPinConfig *load_config(void);
void save_config(WallPinConfig *config);

#endif // CONFIG_H
