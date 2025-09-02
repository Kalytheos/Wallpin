#!/bin/bash

# WallPin Multi-Monitor para Hyprland
# Script para gestionar wallpaper en múltiples pantallas

WALLPIN_DIR="/home/kalytheos/Documents/Proyectos/WallPin"
LOG_FILE="/tmp/wallpin.log"
PID_DIR="/tmp/wallpin_pids"
DEFAULT_FPS=60

# Crear directorio para PIDs si no existe
mkdir -p "$PID_DIR"

# Función para mostrar ayuda
show_help() {
    echo "WallPin Multi-Monitor para Hyprland"
    echo "Uso: $0 [comando] [opciones]"
    echo ""
    echo "Comandos:"
    echo "  start [monitor] [-f fps] [-s speed]       - Iniciar en monitor específico"
    echo "  start-all [-f fps] [-s speed]             - Iniciar en todos los monitores"
    echo "  stop [monitor]                            - Detener monitor específico"
    echo "  stop-all                                  - Detener todos los wallpapers"
    echo "  restart [monitor] [-f fps] [-s speed]     - Reiniciar monitor específico"
    echo "  restart-all [-f fps] [-s speed]           - Reiniciar todos los wallpapers"
    echo "  status                                    - Mostrar estado de todos los monitores"
    echo "  list-monitors                             - Listar monitores disponibles"
    echo ""
    echo "Opciones:"
    echo "  -f, --fps [30-500]      - Configurar FPS (por defecto: 60)"
    echo "  -s, --speed [1.0-100.0] - Configurar velocidad en px/s (por defecto: 18.0)"
    echo ""
    echo "Opciones de FPS populares:"
    echo "  60    - Estándar (por defecto)"
    echo "  120   - Gaming suave"
    echo "  144   - Gaming high-end"
    echo "  240   - Gaming profesional"
    echo "  360   - Máximo rendimiento"
    echo ""
    echo "Opciones de Velocidad (px/s):"
    echo "  10.0  - Lento y relajante"
    echo "  18.0  - Normal (por defecto)"
    echo "  25.0  - Rápido"
    echo "  35.0  - Muy rápido"
    echo ""
    echo "Ejemplos:"
    echo "  $0 start HDMI-A-1 -f 120 -s 25.0       # 120 FPS, velocidad rápida en HDMI"
    echo "  $0 start eDP-1 -f 144 -s 10.0          # 144 FPS, velocidad lenta en laptop"
    echo "  $0 start-all -f 60 -s 18.0             # 60 FPS, velocidad normal en todos"
    echo "  $0 restart-all -f 240 -s 30.0          # Reiniciar todos con 240 FPS y velocidad alta"
    echo "  $0 start HDMI-A-1 120 25.0             # También soporta sintaxis posicional"
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
    local fps="$2"
    local speed="$3"
    local pid_file="$PID_DIR/wallpin_${monitor}.pid"
    
    # Usar FPS por defecto si no se especifica
    if [[ -z "$fps" ]]; then
        fps="$DEFAULT_FPS"
    fi
    
    # Validar FPS
    if [[ ! "$fps" =~ ^[0-9]+$ ]] || [[ "$fps" -lt 30 ]] || [[ "$fps" -gt 500 ]]; then
        echo "❌ Error: FPS debe ser un número entre 30 y 500. Usando $DEFAULT_FPS FPS"
        fps="$DEFAULT_FPS"
    fi
    
    # Validar velocidad si se especifica
    local speed_param=""
    if [[ -n "$speed" ]]; then
        # Validación simple para números decimales (sin bc)
        if [[ "$speed" =~ ^[0-9]+\.?[0-9]*$ ]] || [[ "$speed" =~ ^[0-9]*\.[0-9]+$ ]]; then
            # Convertir a entero para comparación simple (multiplicar por 10)
            local speed_int=$(echo "$speed * 10" | awk '{printf "%.0f", $1}')
            if [[ "$speed_int" -ge 10 ]] && [[ "$speed_int" -le 1000 ]]; then
                speed_param="--speed $speed"
            else
                echo "❌ Error: Velocidad debe ser un número entre 1.0 y 100.0. Usando velocidad por defecto"
                speed_param=""
            fi
        else
            echo "❌ Error: Velocidad debe ser un número válido. Usando velocidad por defecto"
            speed_param=""
        fi
    fi
    
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
    local config_msg="$fps FPS"
    if [[ -n "$speed" ]]; then
        config_msg="$fps FPS, $speed px/s"
    fi
    echo "=== WallPin iniciado en $monitor con $config_msg $(date) ===" >> "$LOG_FILE"
    
    # Ejecutar wallpaper en background para el monitor específico con FPS y velocidad
    nohup ./build/wallpin-wallpaper --monitor "$monitor" --fps "$fps" $speed_param >> "$LOG_FILE" 2>&1 &
    
    # Guardar PID
    echo $! > "$pid_file"
    
    sleep 2
    
    # Verificar que se inició correctamente
    if kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        local success_msg="✅ WallPin iniciado correctamente en $monitor ($fps FPS"
        if [[ -n "$speed" ]]; then
            success_msg="$success_msg, $speed px/s)"
        else
            success_msg="$success_msg)"
        fi
        echo "$success_msg"
        echo "📄 Log: $LOG_FILE"
    else
        echo "❌ Error al iniciar WallPin en $monitor"
        rm -f "$pid_file"
        return 1
    fi
}

# Función para iniciar en todos los monitores
start_all() {
    local fps="$1"
    local speed="$2"
    echo "🚀 Iniciando WallPin en todos los monitores..."
    local monitors
    monitors=$(get_monitors)
    
    if [[ -z "$monitors" ]]; then
        echo "❌ No se detectaron monitores"
        return 1
    fi
    
    while IFS= read -r monitor; do
        start_monitor "$monitor" "$fps" "$speed"
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
    local fps="$2"
    local speed="$3"
    stop_monitor "$monitor"
    sleep 1
    start_monitor "$monitor" "$fps" "$speed"
}

# Función para reiniciar todos
restart_all() {
    local fps="$1"
    local speed="$2"
    stop_all
    sleep 2
    start_all "$fps" "$speed"
}

# Función para parsear argumentos con flags
parse_args() {
    local command="$1"
    shift
    
    local fps=""
    local speed=""
    local monitor=""
    local remaining_args=()
    
    # Parsear argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--fps)
                fps="$2"
                shift 2
                ;;
            -s|--speed)
                speed="$2"
                shift 2
                ;;
            *)
                remaining_args+=("$1")
                shift
                ;;
        esac
    done
    
    # Para comandos que requieren monitor, el primer argumento restante es el monitor
    if [[ "${#remaining_args[@]}" -gt 0 ]]; then
        monitor="${remaining_args[0]}"
    fi
    
    # Si no se especificó FPS/speed como flags, usar argumentos posicionales
    if [[ -z "$fps" && "${#remaining_args[@]}" -gt 1 ]]; then
        fps="${remaining_args[1]}"
    fi
    if [[ -z "$speed" && "${#remaining_args[@]}" -gt 2 ]]; then
        speed="${remaining_args[2]}"
    fi
    
    # Ejecutar comando con argumentos parseados
    case "$command" in
        "start")
            if [[ -n "$monitor" ]]; then
                start_monitor "$monitor" "$fps" "$speed"
            else
                echo "❌ Error: Especifica un monitor"
                echo "Uso: $0 start <monitor> [-f fps] [-s speed]"
                echo "Monitores disponibles:"
                get_monitors | sed 's/^/  /'
                exit 1
            fi
            ;;
        "start-all")
            start_all "$fps" "$speed"
            ;;
        "restart")
            if [[ -n "$monitor" ]]; then
                restart_monitor "$monitor" "$fps" "$speed"
            else
                echo "❌ Error: Especifica un monitor"
                echo "Uso: $0 restart <monitor> [-f fps] [-s speed]"
                exit 1
            fi
            ;;
        "restart-all")
            restart_all "$fps" "$speed"
            ;;
    esac
}

# Procesar argumentos
case "$1" in
    "start")
        parse_args "$@"
        ;;
    "start-all")
        parse_args "$@"
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
        parse_args "$@"
        ;;
    "restart-all")
        parse_args "$@"
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
