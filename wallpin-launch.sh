#!/bin/bash

# WallPin Launcher Script
# This script ensures WallPin runs with proper Wayland support

# Force GTK to use Wayland backend
export GDK_BACKEND=wayland

# Ensure we're using the Wayland display
if [ -z "$WAYLAND_DISPLAY" ]; then
    echo "Error: WAYLAND_DISPLAY not set. Make sure you're running under Wayland."
    exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Determine which binary to run
case "$1" in
    "wallpaper"|"bg"|"background")
        BINARY="$SCRIPT_DIR/build/wallpin-wallpaper"
        MODE="wallpaper"
        ;;
    "normal"|"window"|"")
        BINARY="$SCRIPT_DIR/build/wallpin"
        MODE="normal"
        ;;
    *)
        echo "Usage: $0 [wallpaper|normal]"
        echo "  wallpaper - Run as wallpaper background"
        echo "  normal    - Run as normal application window (default)"
        exit 1
        ;;
esac

# Check if binary exists
if [ ! -f "$BINARY" ]; then
    echo "Error: Binary not found: $BINARY"
    echo "Please compile first with: make all"
    exit 1
fi

echo "Starting WallPin in $MODE mode..."
echo "Using Wayland display: $WAYLAND_DISPLAY"

# Run the application
exec "$BINARY" "$@"
