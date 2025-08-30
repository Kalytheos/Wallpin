#!/bin/bash

# WallPin Installation and Usage Script
# This script compiles, installs, and provides usage instructions for WallPin

INSTALL_DIR="/usr/local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
CONFIG_DIR="$HOME/.config/wallpin"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}         WallPin Setup          ${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_dependencies() {
    print_status "Checking dependencies..."
    
    # Check if we're in Wayland
    if [ -z "$WAYLAND_DISPLAY" ]; then
        print_error "WallPin wallpaper mode requires Wayland"
        print_error "Current session: $XDG_SESSION_TYPE"
        exit 1
    fi
    
    # Check for Hyprland
    if ! pgrep -x "Hyprland" > /dev/null; then
        print_warning "Hyprland not detected. WallPin works best with Hyprland."
    fi
    
    # Check for required packages
    for pkg in gtk4 gdk-pixbuf-2.0 gtk4-layer-shell-0; do
        if ! pkg-config --exists "$pkg"; then
            print_error "Missing dependency: $pkg"
            exit 1
        fi
    done
    
    print_status "All dependencies satisfied!"
}

compile_wallpin() {
    print_status "Compiling WallPin..."
    
    if ! make clean; then
        print_error "Failed to clean build directory"
        exit 1
    fi
    
    if ! make all; then
        print_error "Compilation failed"
        exit 1
    fi
    
    print_status "Compilation successful!"
}

install_wallpin() {
    print_status "Installing WallPin..."
    
    # Create directories
    sudo mkdir -p "$INSTALL_DIR"
    mkdir -p "$DESKTOP_DIR"
    mkdir -p "$CONFIG_DIR"
    
    # Install binaries
    sudo cp build/wallpin "$INSTALL_DIR/"
    sudo cp build/wallpin-wallpaper "$INSTALL_DIR/"
    sudo chmod +x "$INSTALL_DIR/wallpin" "$INSTALL_DIR/wallpin-wallpaper"
    
    # Create desktop entry for normal version
    cat > "$DESKTOP_DIR/wallpin.desktop" << EOF
[Desktop Entry]
Name=WallPin
Comment=Dynamic wallpaper image viewer
Exec=wallpin
Icon=image-x-generic
Type=Application
Categories=Graphics;Photography;
Terminal=false
EOF
    
    # Create config file template
    cat > "$CONFIG_DIR/config.conf" << EOF
# WallPin Configuration
# Path to your images directory
IMAGES_DIR=$HOME/Pictures/wallpapers

# Auto-scroll settings
SCROLL_SPEED=0.1
SCROLL_INTERVAL=16

# Layout settings
COLUMNS=5
IMAGE_SPACING=16
EOF
    
    print_status "Installation complete!"
}

create_hyprland_config() {
    print_status "Creating Hyprland configuration example..."
    
    cat > "$CONFIG_DIR/hyprland-example.conf" << EOF
# Add this to your Hyprland configuration to start WallPin as wallpaper

# Method 1: Start wallpaper on startup
exec-once = wallpin-wallpaper

# Method 2: Use with hyprctl (run manually)
# hyprctl dispatch exec wallpin-wallpaper

# Method 3: Bind to a key
# bind = SUPER, W, exec, killall wallpin-wallpaper; wallpin-wallpaper

# Note: Make sure to adjust the ASSETS_DIR in the source code or use symlinks
# to point to your desired wallpaper directory
EOF
    
    print_status "Hyprland example config created at: $CONFIG_DIR/hyprland-example.conf"
}

show_usage() {
    print_header
    echo
    print_status "Installation complete! Here's how to use WallPin:"
    echo
    echo -e "${BLUE}Normal Application Mode:${NC}"
    echo "  wallpin"
    echo
    echo -e "${BLUE}Wallpaper Mode (for Hyprland):${NC}"
    echo "  wallpin-wallpaper"
    echo
    echo -e "${BLUE}Stop Wallpaper:${NC}"
    echo "  killall wallpin-wallpaper"
    echo
    echo -e "${BLUE}Configuration:${NC}"
    echo "  Edit: $CONFIG_DIR/config.conf"
    echo "  Hyprland example: $CONFIG_DIR/hyprland-example.conf"
    echo
    echo -e "${BLUE}Image Directory:${NC}"
    echo "  Current: $(dirname "$(pwd)")/assets"
    echo "  To use custom directory, edit src/config.h and recompile"
    echo
    echo -e "${YELLOW}For Hyprland integration:${NC}"
    echo "  1. Add 'exec-once = wallpin-wallpaper' to your hyprland.conf"
    echo "  2. Or run manually: hyprctl dispatch exec wallpin-wallpaper"
    echo
}

# Main execution
case "$1" in
    "install")
        print_header
        check_dependencies
        compile_wallpin
        install_wallpin
        create_hyprland_config
        show_usage
        ;;
    "compile")
        print_header
        check_dependencies
        compile_wallpin
        print_status "Compilation complete! Binaries are in ./build/"
        ;;
    "test-wallpaper")
        print_header
        print_status "Testing wallpaper mode (run for 10 seconds)..."
        timeout 10s ./build/wallpin-wallpaper || print_status "Test completed"
        ;;
    "test-normal")
        print_header
        print_status "Testing normal mode (run for 10 seconds)..."
        timeout 10s ./build/wallpin || print_status "Test completed"
        ;;
    *)
        print_header
        echo
        echo "Usage: $0 {install|compile|test-wallpaper|test-normal}"
        echo
        echo "  install        - Compile, install, and setup WallPin"
        echo "  compile        - Just compile the project"
        echo "  test-wallpaper - Test wallpaper mode for 10 seconds"
        echo "  test-normal    - Test normal mode for 10 seconds"
        echo
        ;;
esac
