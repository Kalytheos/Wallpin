# WallPin

Dynamic## ✨ Features

- 🖼️ **Masonry Layout**: Pinterest-style dynamic image arrangement
- 🔄 **Auto-scroll**: Infinite smooth scrolling through images
- 🖥️ **Multi-Monitor**: Independent wallpaper on each monitor simultaneously
- 🎨 **True Wallpaper**: Native Wayland layer shell integration (not just fullscreen)
- 🚫 **Non-Interactive**: Blocks user scroll while maintaining image hover effects
- 🪟 **Wallpaper Mode**: Native layer shell wallpaper integration
- ⚡ **GTK4 + Layer Shell**: Native Wayland/Hyprland integration
- 🎯 **Optimized**: Efficient image loading with per-instance state management
- 🎲 **Image Shuffling**: Multiple strategies to reorder wallpaper display (NEW!)
- 🔧 **Image Normalization**: Standardize inconsistent file naming (NEW!)
- 💾 **Memory Optimized**: 97% less RAM usage - handles 1000+ images efficiently (NEW!)or wallpaper with masonry layout and auto-scroll for Wayland/Hyprland.

## 🎬 Demo

### Animated Demo
![WallPin Demo](docs/media/demo.gif)

### Video Demonstration
https://github.com/Kalytheos/Wallpin/docs/media/show.mp4

### Screenshot
![WallPin Screenshot](docs/media/captura.png)

### Preview Gallery
![WallPin Preview](assets/preview.png)

## ✨ Features

- 🖼️ **Masonry Layout**: Pinterest-style dynamic image arrangement
- 🔄 **Auto-scroll**: Infinite smooth scrolling through images
- � **Multi-Monitor**: Independent wallpaper on each monitor simultaneously
- 🎨 **True Wallpaper**: Native Wayland layer shell integration (not just fullscreen)
- 🚫 **Non-Interactive**: Blocks user scroll while maintaining image hover effects
- 🪟 **Wallpaper Mode**: Native layer shell wallpaper integration
- ⚡ **GTK4 + Layer Shell**: Native Wayland/Hyprland integration
- 🎯 **Optimized**: Efficient image loading with per-instance state management
- 🎲 **Image Shuffling**: Multiple strategies to reorder wallpaper display (NEW!)
- 🔧 **Image Normalization**: Standardize inconsistent file naming (NEW!)

## 🖥️ Multi-Monitor Support

WallPin now supports **multiple monitors simultaneously** with independent wallpapers:

- ✅ **HDMI-A-1** + **eDP-1** (or any monitor combination)
- ✅ **Independent processes** per monitor (no shared state)
- ✅ **Monitor-specific control** (start/stop individual monitors)
- ✅ **Auto-detection** of available monitors

## 📋 Requirements

- **Wayland compositor** (Hyprland recommended)
- **GTK4** and **gtk4-layer-shell**
- **GDK-Pixbuf** for image processing
- **GCC** and **Make** for compilation

### Arch Linux Dependencies

```bash
sudo pacman -S gtk4 gtk4-layer-shell gdk-pixbuf2 base-devel
```

### Ubuntu/Debian Dependencies

```bash
sudo apt install libgtk-4-dev libgtk4-layer-shell-dev libgdk-pixbuf-2.0-dev build-essential pkg-config
```

## � Performance & Memory Optimization

WallPin is heavily optimized to handle **1000+ images** efficiently:

| Metric | Before Optimization | After Optimization | Improvement |
|--------|---------------------|-------------------|-------------|
| RAM Usage (Initial) | ~4 GB | ~150 MB | ✅ **97% less** |
| RAM Usage (Full Load) | ~50 GB | ~1.2 GB | ✅ **97% less** |
| Loading Time | 30-45 seconds | 3-5 seconds | ✅ **85% faster** |

### Key Optimizations
- 🔍 **Smart dimension reading**: Only reads image headers, not full pixel data
- 📦 **Direct scaled loading**: Loads images at display size, not full resolution
- 🧹 **Immediate cleanup**: Proper GTK4 reference counting and memory management
- ⚡ **Efficient caching**: Per-instance state management prevents duplicates

### Testing Memory Usage
```bash
# Run the included memory test script
./test-memory.sh

# Or monitor manually
watch -n 1 'ps aux | grep wallpin | grep -v grep'
```

For technical details, see [`MEMORY_OPTIMIZATIONS.md`](MEMORY_OPTIMIZATIONS.md).

## �🚀 Installation

### Quick Install (Recommended)

```bash
git clone https://github.com/Kalytheos/WallPin.git
cd WallPin
make clean && make wallpaper
```

### Manual Installation

```bash
# Compile wallpaper version
make clean && make

# Install binary (optional)
sudo cp build/wallpin-wallpaper /usr/local/bin/
sudo chmod +x /usr/local/bin/wallpin-wallpaper
```

## 🖥️ Usage

### Multi-Monitor Wallpaper (New!)

**Using the multi-monitor script (recommended):**

```bash
# List available monitors
./hyprwall-multi.sh list-monitors

# Start on all monitors (default 60 FPS)
./hyprwall-multi.sh start-all

# Start on all monitors with custom FPS
./hyprwall-multi.sh start-all 120
./hyprwall-multi.sh start-all 144

# Start on specific monitor
./hyprwall-multi.sh start HDMI-A-1
./hyprwall-multi.sh start eDP-1

# Start with custom FPS
./hyprwall-multi.sh start HDMI-A-1 240
./hyprwall-multi.sh start eDP-1 144

# Check status of all monitors
./hyprwall-multi.sh status

# Stop specific monitor
./hyprwall-multi.sh stop HDMI-A-1

# Stop all monitors
./hyprwall-multi.sh stop-all

# Restart all
./hyprwall-multi.sh restart-all

# Restart with custom FPS
./hyprwall-multi.sh restart-all 120
./hyprwall-multi.sh restart HDMI-A-1 240
```

**Available commands:**
- `start [monitor]` - Start wallpaper on specific monitor
- `start-all` - Start on all detected monitors  
- `stop [monitor]` - Stop specific monitor
- `stop-all` - Stop all wallpapers
- `restart [monitor]` - Restart specific monitor
- `restart-all` - Restart all wallpapers
- `status` - Show status of all monitors
- `list-monitors` - List available monitors

### Single Monitor Wallpaper (Legacy)

```bash
# Start wallpaper
./hyprwall.sh start

# Stop wallpaper  
./hyprwall.sh stop

# Check status
./hyprwall.sh status

# Restart wallpaper
./hyprwall.sh restart
```

### Direct Usage with Monitor Selection

```bash
# Start on specific monitor
./build/wallpin-wallpaper --monitor HDMI-A-1
./build/wallpin-wallpaper -m eDP-1

# Configure FPS (30-500)
./build/wallpin-wallpaper --fps 120
./build/wallpin-wallpaper -f 144

# Combine monitor and FPS
./build/wallpin-wallpaper -m HDMI-A-1 -f 240

# See help
./build/wallpin-wallpaper --help
```

### 🎯 FPS Configuration

**Popular FPS Settings:**
- **60 FPS** (default): Balanced performance, standard displays
- **120 FPS**: Smooth animations, 120Hz displays  
- **144 FPS**: Gaming monitors, ultra-smooth scrolling
- **165 FPS**: High-end gaming displays
- **240 FPS**: Professional gaming, maximum smoothness
- **360 FPS**: Extreme refresh rates

**Performance Notes:**
- Higher FPS = smoother animation but more CPU usage
- Scroll speed remains constant (18 pixels/second) regardless of FPS
- Recommended: Match your monitor's refresh rate

```bash
# Examples for different display types
./build/wallpin-wallpaper -f 60   # Standard monitor
./build/wallpin-wallpaper -f 120  # Gaming monitor
./build/wallpin-wallpaper -f 144  # High refresh gaming
./build/wallpin-wallpaper -f 240  # Professional gaming
```

### 🔧 Hyprland Integration

**Option 1: Multi-monitor auto-start (recommended)**
Add to your `~/.config/hypr/hyprland.conf`:

```bash
# Start WallPin on all monitors (default 60 FPS)
exec-once = /path/to/WallPin/hyprwall-multi.sh start-all

# Start with custom FPS for all monitors
exec-once = /path/to/WallPin/hyprwall-multi.sh start-all 120

# Keybinds for control
bind = SUPER, W, exec, /path/to/WallPin/hyprwall-multi.sh restart-all
bind = SUPER SHIFT, W, exec, /path/to/WallPin/hyprwall-multi.sh stop-all

# Keybinds with custom FPS
bind = SUPER, W, exec, /path/to/WallPin/hyprwall-multi.sh restart-all 144
```

**Option 2: Specific monitors with FPS control**
```bash
# Start on specific monitors with different FPS
exec-once = /path/to/WallPin/hyprwall-multi.sh start HDMI-A-1 240
exec-once = sleep 2 && /path/to/WallPin/hyprwall-multi.sh start eDP-1 144

# Monitor-specific controls with FPS
bind = SUPER, W, exec, /path/to/WallPin/hyprwall-multi.sh restart HDMI-A-1 240
bind = SUPER SHIFT, W, exec, /path/to/WallPin/hyprwall-multi.sh restart eDP-1 144
```

**Option 3: Single monitor (legacy)**
```bash
# Single monitor auto-start
exec-once = /path/to/WallPin/hyprwall.sh start

# Single monitor control
bind = SUPER, W, exec, /path/to/WallPin/hyprwall.sh restart
```

## ⚙️ Configuration

### Image Directory

Edit `src/config.h` to change the default image directory:

```c
#define ASSETS_DIR "/path/to/your/images"
```

Then recompile:

```bash
make clean && make wallpaper
```

## 🎲 Image Shuffling

WallPin includes scripts to change the order in which images are displayed without modifying the program itself:

### Advanced Shuffling (shuffle-wallpapers.sh)

```bash
# Show all available options
./shuffle-wallpapers.sh help

# Reverse order (first becomes last, last becomes first)
./shuffle-wallpapers.sh reverse

# Random order (reproducible based on current date)
./shuffle-wallpapers.sh random

# Swap chunks of 50 images
./shuffle-wallpapers.sh chunks

# Interleave even/odd images
./shuffle-wallpapers.sh interleave

# Create backup without shuffling
./shuffle-wallpapers.sh backup

# Restore original order
./shuffle-wallpapers.sh restore
```

### Quick Shuffle (quick-shuffle.sh)

```bash
# Simple reverse order (swap first ↔ last)
./quick-shuffle.sh
```

**Features:**
- ✅ **Automatic backup**: Creates backup before any change
- ✅ **Preserve extensions**: Maintains .jpg, .png, .jpeg correctly
- ✅ **Smart detection**: Handles wall_XXX and wallpaper_XXX patterns
- ✅ **Easy restore**: Return to original order anytime
- ✅ **Multiple strategies**: Different shuffling algorithms
- ✅ **Progress tracking**: Shows progress for large collections

**Example workflow:**
```bash
# 1. Try reverse order
./shuffle-wallpapers.sh reverse

# 2. Test your wallpaper (images now show in reverse)
./hyprwall-multi.sh restart-all

# 3. Try random if you want more variety
./shuffle-wallpapers.sh random

# 4. Go back to original if needed
./shuffle-wallpapers.sh restore
```

### Auto-scroll Settings

Modify in `src/main_wallpaper.c`:

```c
#define SCROLL_SPEED 0.3        // Pixels per frame (0.1 = slow, 1.0 = fast)
#define SCROLL_INTERVAL 16      // Milliseconds (16ms = 60 FPS)
```

### Image Layout Settings

Modify in `src/layout.h`:

```c
#define STANDARD_WIDTH 280           // Base width for images
#define IMAGE_SPACING 16             // Space between images
#define MAX_IMAGES_PER_ROW 5         // Maximum images per row
```

## 🎮 Features Details

### Non-Interactive Wallpaper
- **Scroll blocking**: User scroll/drag is completely disabled
- **Hover effects**: Images still grow slightly on mouse hover
- **Auto-scroll**: Continues smoothly without user interference
- **True wallpaper**: Renders below all windows (not just fullscreen)

### Multi-Monitor Independence
- **Separate processes**: Each monitor runs its own wallpaper instance
- **No shared state**: No conflicts between monitors
- **Individual control**: Start/stop/restart each monitor independently
- **Monitor detection**: Automatically detects available monitors

### Advanced Layer Shell Integration
- **Background layer**: Renders below all other windows
- **Monitor-specific**: Each wallpaper binds to its specific monitor
- **Fallback support**: Falls back to fullscreen if layer shell unavailable
- **Wayland native**: Uses `wlr-layer-shell-unstable-v1` protocol

## 📁 Project Structure

```
WallPin/
├── src/                      # Source code
│   ├── main_wallpaper.c      # Main wallpaper application (multi-monitor)
│   ├── layer_shell.c         # Wayland layer shell integration
│   ├── layout.c              # Masonry layout algorithm (per-instance state)
│   ├── utils.c               # Utility functions and CSS
│   ├── config.c              # Configuration management
│   └── wallpaper.c           # Wallpaper management functions
├── assets/                   # Image files directory
├── build/                    # Compiled binaries
│   ├── wallpin               # Window application binary
│   └── wallpin-wallpaper     # Wallpaper application binary
├── Makefile                  # Build configuration
├── hyprwall.sh               # Single monitor script (legacy)
├── hyprwall-multi.sh         # Multi-monitor script (recommended)
├── wallpin-launch.sh         # Launch script with Wayland support
└── README.md                 # Documentation
```

## 🔧 How It Works

### Multi-Monitor Architecture
1. **Monitor Detection**: Uses `hyprctl monitors` to detect available displays
2. **Process Isolation**: Each monitor gets its own wallpaper process
3. **Unique App IDs**: Each instance has a unique GTK application ID
4. **Independent State**: Separate layout and image state per monitor
5. **Layer Shell Binding**: Each window binds to its specific monitor

### Rendering Pipeline
1. **Image Loading**: Loads all images from the specified directory
2. **Masonry Layout**: Arranges images in columns based on aspect ratios
3. **Auto-scroll**: Smoothly scrolls through the layout infinitely
4. **Layer Shell**: Uses `wlr-layer-shell-unstable-v1` protocol for wallpaper mode
5. **Hover Effects**: CSS transforms for image hover while blocking scroll

### Event Handling
- **Scroll Blocking**: Captures scroll events in GTK_PHASE_CAPTURE
- **Drag Blocking**: Prevents gesture-based scrolling
- **Hover Preservation**: Maintains CSS `:hover` effects on images
- **Focus Management**: Disables keyboard focus while preserving visual effects

## 🛠️ Compilation Targets

- `make all` - Build both window and wallpaper versions
- `make normal` - Build window application only  
- `make wallpaper` - Build wallpaper version only
- `make clean` - Clean build directory

## 🐛 Troubleshooting

### Multi-Monitor Issues

**Problem**: Wallpaper appears on wrong monitor
```bash
# Check available monitors
./hyprwall-multi.sh list-monitors

# Restart with correct monitor name
./hyprwall-multi.sh stop-all
./hyprwall-multi.sh start HDMI-A-1  # Use exact monitor name
```

**Problem**: Second monitor shows gray screen
```bash
# This was fixed in the latest version
# Make sure you have the latest compiled version
make clean && make wallpaper
./hyprwall-multi.sh restart-all
```

### Layer Shell Warnings

If you see "Failed to initialize layer surface" warnings:

1. Make sure you're running on Wayland:
   ```bash
   echo $WAYLAND_DISPLAY
   ```

2. Use the multi-monitor script (handles Wayland automatically):
   ```bash
   ./hyprwall-multi.sh start-all
   ```

3. Check if layer shell is supported:
   ```bash
   pkg-config --exists gtk4-layer-shell-0 && echo "Supported"
   ```

### Performance Issues

- Reduce image directory size
- Lower scroll speed in configuration  
- Use smaller image resolutions
- Stop unused monitor instances

### Memory Usage

Monitor with:
```bash
# Check all wallpaper processes
./hyprwall-multi.sh status

# Detailed memory usage
ps aux | grep wallpin
```

## 📊 Performance Tips

- **Image Optimization**: Use images around 1920x1080 or smaller
- **Directory Size**: Keep image directory under 500 images for best performance
- **Memory Management**: Each monitor uses ~50-100MB RAM
- **CPU Usage**: Very low CPU usage during steady auto-scroll

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test on Hyprland/Wayland with multiple monitors
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

## 🔗 Similar Projects

- [hyprpaper](https://github.com/hyprwm/hyprpaper) - Static wallpaper for Hyprland
- [mpvpaper](https://github.com/GhostNaN/mpvpaper) - Video wallpapers for Wayland
- [swww](https://github.com/Horus645/swww) - Wallpaper daemon for Wayland

## 🙏 Acknowledgments

- Hyprland team for the amazing compositor and multi-monitor support
- GTK and layer-shell developers for the Wayland integration
- Pinterest for the masonry layout inspiration
- Community feedback for multi-monitor requirements

---

## 🆕 Changelog

### v3.1.0 - Critical Memory Optimizations (Oct 2025)
- 🚀 **97% reduction in RAM usage**: From ~50 GB to ~1.2 GB for 1367 images
- ⚡ **85% faster loading times**: From 30-45s to 3-5s
- 🔧 **GTK4 compatibility fixes**: Adapted to recent GTK4 API changes
  - Fixed `gdk_pixbuf_new_from_file` → `gdk_pixbuf_get_file_info` (99% less memory for dimension reading)
  - Optimized `gdk_pixbuf_scale_simple` → `gdk_pixbuf_new_from_file_at_scale` (97% less memory per image)
  - Fixed reference counting with immediate `g_object_unref()` calls
- 📊 **Memory leak prevention**: Proper cleanup of GdkPixbuf and GdkTexture objects
- 📝 **Complete documentation**: `MEMORY_OPTIMIZATIONS.md` with technical details
- 🧪 **Testing script**: `test-memory.sh` for monitoring RAM usage
- ✅ **Production ready**: Handles 1000+ images efficiently on standard hardware

### v3.0.0 - Image Shuffling & Normalization
- ✅ **Image shuffling scripts**: Multiple reordering strategies for visual variety
  - `shuffle-wallpapers.sh`: Advanced shuffling with 4 strategies (reverse, random, chunks, interleave)
  - `quick-shuffle.sh`: Simple one-command reverse shuffling
- ✅ **Image normalization**: `normalize-images.sh` standardizes inconsistent naming
  - Handles `wall_XXX`, `wallpaper_XXXX`, and mixed patterns
  - Converts all to consistent `wall_001.ext` format
- ✅ **Configurable FPS system**: Fine-tune performance for any display
  - Range: 30-500 FPS with `--fps` or `-f` parameter
  - Speed independence: Constant 18 px/second regardless of FPS
  - Popular presets: 60, 120, 144, 165, 240, 360 FPS
  - Real-time switching with `set_target_fps()` function
- ✅ **Robust algorithms**: Fixed random strategy with Fisher-Yates algorithm
- ✅ **Data safety**: Comprehensive backup systems and validation checks
- ✅ **Preview mode**: See changes before applying them
- ✅ **Error prevention**: Duplicate detection and file loss protection
- ✅ **Documentation**: Complete SHUFFLING.md guide with examples

### v2.0.0 - Multi-Monitor Support
- ✅ **Multi-monitor support**: Independent wallpapers on each monitor
- ✅ **Non-interactive wallpaper**: Blocks user scroll while preserving hover effects  
- ✅ **Per-instance state**: Eliminates shared state conflicts
- ✅ **Monitor-specific control**: Individual start/stop/restart per monitor
- ✅ **Improved layer shell**: Better monitor binding and sizing
- ✅ **Enhanced scripts**: New `hyprwall-multi.sh` for multi-monitor management

### v1.0.0 - Initial Release
- ✅ **Basic wallpaper functionality**: Single monitor support
- ✅ **Masonry layout**: Pinterest-style image arrangement
- ✅ **Auto-scroll**: Infinite smooth scrolling
- ✅ **Hyprland integration**: Layer shell support
