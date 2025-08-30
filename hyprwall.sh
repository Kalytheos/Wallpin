#!/bin/bash

# WallPin para Hyprland - Script optimizado
# Este script está diseñado para funcionar perfectamente con Hyprland

WALLPIN_DIR="/home/kalytheos/Documents/Proyectos/WallPin"

# Función para mostrar ayuda
show_help() {
    echo "WallPin para Hyprland"
    echo "Uso: $0 [start|stop|restart|status]"
    echo ""
    echo "Comandos:"
    echo "  start    - Iniciar WallPin como wallpaper"
    echo "  stop     - Detener WallPin wallpaper"
    echo "  restart  - Reiniciar WallPin wallpaper"
    echo "  status   - Mostrar estado de WallPin"
    echo "  window   - Ejecutar en modo ventana"
    echo ""
}

# Función para verificar estado
check_status() {
    if pgrep -f "wallpin-wallpaper" > /dev/null; then
        echo "✅ WallPin wallpaper está ejecutándose (PID: $(pgrep -f wallpin-wallpaper))"
        return 0
    else
        echo "❌ WallPin wallpaper no está ejecutándose"
        return 1
    fi
}

# Función para iniciar wallpaper
start_wallpaper() {
    if pgrep -f "wallpin-wallpaper" > /dev/null; then
        echo "⚠️  WallPin ya está ejecutándose"
        return 1
    fi
    
    echo "🚀 Iniciando WallPin wallpaper..."
    
    # Asegurar que usamos Wayland cuando sea posible
    export GDK_BACKEND=wayland
    
    # Cambiar al directorio correcto
    cd "$WALLPIN_DIR" || {
        echo "❌ Error: No se pudo acceder al directorio $WALLPIN_DIR"
        exit 1
    }
    
    # Ejecutar en segundo plano
    nohup "$WALLPIN_DIR/build/wallpin-wallpaper" > /tmp/wallpin.log 2>&1 &
    
    # Esperar un momento para verificar que se inició correctamente
    sleep 2
    
    if pgrep -f "wallpin-wallpaper" > /dev/null; then
        echo "✅ WallPin wallpaper iniciado correctamente"
        echo "📄 Log: /tmp/wallpin.log"
    else
        echo "❌ Error al iniciar WallPin wallpaper"
        echo "Ver log: /tmp/wallpin.log"
        return 1
    fi
}

# Función para detener wallpaper
stop_wallpaper() {
    if ! pgrep -f "wallpin-wallpaper" > /dev/null; then
        echo "⚠️  WallPin wallpaper no está ejecutándose"
        return 1
    fi
    
    echo "🛑 Deteniendo WallPin wallpaper..."
    pkill -f "wallpin-wallpaper"
    
    # Esperar un momento
    sleep 1
    
    if ! pgrep -f "wallpin-wallpaper" > /dev/null; then
        echo "✅ WallPin wallpaper detenido"
    else
        echo "⚠️  Forzando cierre..."
        pkill -9 -f "wallpin-wallpaper"
        echo "✅ WallPin wallpaper detenido (forzado)"
    fi
}

# Función para reiniciar
restart_wallpaper() {
    stop_wallpaper
    sleep 1
    start_wallpaper
}

# Función para modo ventana
start_window() {
    echo "🪟 Iniciando WallPin en modo ventana..."
    cd "$WALLPIN_DIR" || exit 1
    "$WALLPIN_DIR/build/wallpin"
}

# Procesar argumentos
case "$1" in
    "start")
        start_wallpaper
        ;;
    "stop")
        stop_wallpaper
        ;;
    "restart")
        restart_wallpaper
        ;;
    "status")
        check_status
        ;;
    "window")
        start_window
        ;;
    *)
        show_help
        ;;
esac
