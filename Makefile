CC = gcc
CFLAGS = -Wall -Wextra $(shell pkg-config --cflags gtk4 gdk-pixbuf-2.0 gtk4-layer-shell-0)
LDFLAGS = $(shell pkg-config --libs gtk4 gdk-pixbuf-2.0 gtk4-layer-shell-0)

SRC_DIR = src
BUILD_DIR = build

# Archivos fuente comunes
COMMON_SRCS = $(SRC_DIR)/config.c $(SRC_DIR)/layout.c $(SRC_DIR)/utils.c $(SRC_DIR)/wallpaper.c $(SRC_DIR)/layer_shell.c
COMMON_OBJS = $(COMMON_SRCS:$(SRC_DIR)/%.c=$(BUILD_DIR)/%.o)

# Archivos principales
MAIN_SRC = $(SRC_DIR)/main.c
WALLPAPER_SRC = $(SRC_DIR)/main_wallpaper.c

MAIN_OBJ = $(BUILD_DIR)/main.o
WALLPAPER_OBJ = $(BUILD_DIR)/main_wallpaper.o

# Targets
TARGET_NORMAL = wallpin
TARGET_WALLPAPER = wallpin-wallpaper

.PHONY: all clean wallpaper normal

all: $(BUILD_DIR)/$(TARGET_NORMAL) $(BUILD_DIR)/$(TARGET_WALLPAPER)

# Versión normal (aplicación de ventana)
normal: $(BUILD_DIR)/$(TARGET_NORMAL)

# Versión wallpaper (layer shell)
wallpaper: $(BUILD_DIR)/$(TARGET_WALLPAPER)

$(BUILD_DIR)/$(TARGET_NORMAL): $(COMMON_OBJS) $(MAIN_OBJ)
	@mkdir -p $(BUILD_DIR)
	$(CC) $(COMMON_OBJS) $(MAIN_OBJ) -o $@ $(LDFLAGS)

$(BUILD_DIR)/$(TARGET_WALLPAPER): $(COMMON_OBJS) $(WALLPAPER_OBJ)
	@mkdir -p $(BUILD_DIR)
	$(CC) $(COMMON_OBJS) $(WALLPAPER_OBJ) -o $@ $(LDFLAGS)

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -rf $(BUILD_DIR)
