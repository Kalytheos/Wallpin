#!/bin/bash

# WallPin Multi-Monitor para Hyprland
# Script para gestionar wallpaper en múltiples pantallas

WALLPIN_DIR="/home/kalytheos/Documents/Proyectos/WallPin"
LOG_FILE="/tmp/wallpin.log"
PID_DIR="/tmp/wallpin_pids"

# Crear directorio para PIDs si no existe
mkdir -p "$PID_DIR"

# Función para mostrar ayuda
show_help() {
    echo "WallPin Multi-Monitor para Hyprland"
    echo "Uso: $0 [comando] [opciones]"
    echo ""
    echo "Comandos:"
    echo "  start [monitor]         - Iniciar en monitor específico"
    echo "  start-all              - Iniciar en todos los monitores detectados"
    echo "  stop [monitor]         - Detener monitor específico"
    echo "  stop-all               - Detener todos los wallpapers"
    echo "  restart [monitor]      - Reiniciar monitor específico"
    echo "  restart-all            - Reiniciar todos los wallpapers"
    echo "  status                 - Mostrar estado de todos los monitores"
    echo "  list-monitors          - Listar monitores disponibles"
    echo ""
    echo "Ejemplos:"
    echo "  $0 start HDMI-A-1      # Iniciar en monitor HDMI principal"
    echo "  $0 start eDP-1         # Iniciar en pantalla de laptop"
    echo "  $0 start-all           # Iniciar en todos los monitores"
    echo "  $0 stop-all            # Detener todos los wallpapers"
    echo ""
}

# Función para listar monitores
list_monitors() {
    echo "📺 Monitores disponibles:"
    hyprctl monitors | grep -E "Monitor|description:" | while read -r line; do
        if [[ $line == Monitor* ]]; then
            monitor_name=$(echo "$line" | awk '{print $2}')
            echo "  • $monitor_name"
        fi
    done
}

# Función para obtener lista de monitores
get_monitors() {
    hyprctl monitors | grep "^Monitor" | awk '{print $2}' | tr -d ':'
}

# Función para verificar estado de un monitor
check_monitor_status() {
    local monitor="$1"
    local pid_file="$PID_DIR/wallpin_${monitor}.pid"
    
    if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        echo "✅ $monitor: WallPin ejecutándose (PID: $(cat "$pid_file"))"
        return 0
    else
        echo "❌ $monitor: WallPin no está ejecutándose"
        [[ -f "$pid_file" ]] && rm -f "$pid_file"
        return 1
    fi
}

# Función para verificar estado de todos los monitores
check_status() {
    echo "📊 Estado de WallPin en todos los monitores:"
    local monitors
    monitors=$(get_monitors)
    
    if [[ -z "$monitors" ]]; then
        echo "❌ No se detectaron monitores"
        return 1
    fi
    
    while IFS= read -r monitor; do
        check_monitor_status "$monitor"
    done <<< "$monitors"
}

# Función para iniciar wallpaper en un monitor específico
start_monitor() {
    local monitor="$1"
    local pid_file="$PID_DIR/wallpin_${monitor}.pid"
    
    # Verificar si ya está ejecutándose
    if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        echo "⚠️  WallPin ya está ejecutándose en $monitor"
        return 1
    fi
    
    echo "🚀 Iniciando WallPin en monitor: $monitor"
    
    # Asegurar que usamos Wayland
    export GDK_BACKEND=wayland
    
    # Cambiar al directorio correcto
    cd "$WALLPIN_DIR" || {
        echo "❌ Error: No se pudo acceder al directorio $WALLPIN_DIR"
        exit 1
    }
    
    # Verificar que el ejecutable existe
    if [[ ! -x "build/wallpin-wallpaper" ]]; then
        echo "❌ Error: No se encontró build/wallpin-wallpaper. Ejecuta 'make wallpaper' primero."
        exit 1
    fi
    
    # Limpiar log anterior para este monitor
    echo "=== WallPin iniciado en $monitor $(date) ===" >> "$LOG_FILE"
    
    # Ejecutar wallpaper en background para el monitor específico
    nohup ./build/wallpin-wallpaper --monitor "$monitor" >> "$LOG_FILE" 2>&1 &
    
    # Guardar PID
    echo $! > "$pid_file"
    
    sleep 2
    
    # Verificar que se inició correctamente
    if kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        echo "✅ WallPin iniciado correctamente en $monitor"
        echo "📄 Log: $LOG_FILE"
    else
        echo "❌ Error al iniciar WallPin en $monitor"
        rm -f "$pid_file"
        return 1
    fi
}

# Función para iniciar en todos los monitores
start_all() {
    echo "🚀 Iniciando WallPin en todos los monitores..."
    local monitors
    monitors=$(get_monitors)
    
    if [[ -z "$monitors" ]]; then
        echo "❌ No se detectaron monitores"
        return 1
    fi
    
    while IFS= read -r monitor; do
        start_monitor "$monitor"
        sleep 1  # Pequeña pausa entre monitores
    done <<< "$monitors"
}

# Función para detener wallpaper en un monitor
stop_monitor() {
    local monitor="$1"
    local pid_file="$PID_DIR/wallpin_${monitor}.pid"
    
    echo "🛑 Deteniendo WallPin en monitor: $monitor"
    
    if [[ -f "$pid_file" ]]; then
        local pid
        pid=$(cat "$pid_file")
        if kill "$pid" 2>/dev/null; then
            echo "✅ WallPin detenido en $monitor"
        else
            echo "⚠️  Proceso no encontrado, limpiando PID file"
        fi
        rm -f "$pid_file"
    else
        echo "❌ WallPin no estaba ejecutándose en $monitor"
    fi
}

# Función para detener todos los wallpapers
stop_all() {
    echo "🛑 Deteniendo WallPin en todos los monitores..."
    
    # Detener por PID files
    for pid_file in "$PID_DIR"/wallpin_*.pid; do
        if [[ -f "$pid_file" ]]; then
            local monitor
            monitor=$(basename "$pid_file" .pid | sed 's/wallpin_//')
            stop_monitor "$monitor"
        fi
    done
    
    # Cleanup adicional por si acaso
    pkill -f "wallpin-wallpaper" 2>/dev/null || true
    echo "✅ Todos los WallPin wallpapers detenidos"
}

# Función para reiniciar un monitor
restart_monitor() {
    local monitor="$1"
    stop_monitor "$monitor"
    sleep 1
    start_monitor "$monitor"
}

# Función para reiniciar todos
restart_all() {
    stop_all
    sleep 2
    start_all
}

# Procesar argumentos
case "$1" in
    "start")
        if [[ -n "$2" ]]; then
            start_monitor "$2"
        else
            echo "❌ Error: Especifica un monitor"
            echo "Uso: $0 start <monitor>"
            echo "Monitores disponibles:"
            get_monitors | sed 's/^/  /'
            exit 1
        fi
        ;;
    "start-all")
        start_all
        ;;
    "stop")
        if [[ -n "$2" ]]; then
            stop_monitor "$2"
        else
            echo "❌ Error: Especifica un monitor"
            echo "Uso: $0 stop <monitor>"
            exit 1
        fi
        ;;
    "stop-all")
        stop_all
        ;;
    "restart")
        if [[ -n "$2" ]]; then
            restart_monitor "$2"
        else
            echo "❌ Error: Especifica un monitor"
            echo "Uso: $0 restart <monitor>"
            exit 1
        fi
        ;;
    "restart-all")
        restart_all
        ;;
    "status")
        check_status
        ;;
    "list-monitors")
        list_monitors
        ;;
    "help" | "--help" | "-h")
        show_help
        ;;
    *)
        echo "❌ Comando no reconocido: $1"
        show_help
        exit 1
        ;;
esac
