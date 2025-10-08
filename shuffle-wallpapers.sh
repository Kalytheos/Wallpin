#!/bin/bash

# WallPin Image Shuffler
# Reorganiza las imágenes para cambiar el orden de visualización
# Mantiene las extensiones originales y permite diferentes estrategias de reordenamiento

set -e

ASSETS_DIR="./assets"
BACKUP_DIR="./assets_backup"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para mostrar ayuda
show_help() {
    echo -e "${BLUE}WallPin Image Shuffler${NC}"
    echo -e "Reorganiza las imágenes en assets/ para cambiar el orden de visualización\n"
    echo "Uso: $0 [OPCIÓN]"
    echo ""
    echo "Opciones:"
    echo "  reverse    - Invierte el orden (primera→última, última→primera)"
    echo "  random     - Orden aleatorio (basado en fecha para ser reproducible)"
    echo "  chunks     - Intercambia bloques de imágenes (grupos de 50)"
    echo "  interleave - Entrelaza: par/impar alternado"
    echo "  restore    - Restaura desde backup"
    echo "  backup     - Solo crear backup sin reorganizar"
    echo "  help       - Muestra esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $0 reverse     # Invertir orden completamente"
    echo "  $0 random     # Mezcla aleatoria reproducible"
    echo "  $0 chunks     # Intercambiar bloques"
    echo "  $0 restore    # Volver al orden original"
}

# Función para crear backup
create_backup() {
    if [ -d "$BACKUP_DIR" ]; then
        echo -e "${YELLOW}  Backup ya existe en $BACKUP_DIR${NC}"
        read -p "¿Sobrescribir backup existente? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${RED} Operación cancelada${NC}"
            exit 1
        fi
        rm -rf "$BACKUP_DIR"
    fi
    
    echo -e "${BLUE} Creando backup...${NC}"
    cp -r "$ASSETS_DIR" "$BACKUP_DIR"
    echo -e "${GREEN} Backup creado en $BACKUP_DIR${NC}"
}

# Función para restaurar backup
restore_backup() {
    if [ ! -d "$BACKUP_DIR" ]; then
        echo -e "${RED} No se encontró backup en $BACKUP_DIR${NC}"
        exit 1
    fi
    
    echo -e "${BLUE} Restaurando desde backup...${NC}"
    rm -rf "$ASSETS_DIR"
    cp -r "$BACKUP_DIR" "$ASSETS_DIR"
    echo -e "${GREEN} Imágenes restauradas al orden original${NC}"
}

# Función para obtener lista de imágenes ordenada
get_image_list() {
    find "$ASSETS_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | sort
}

# Función para extraer número de la imagen
extract_number() {
    local filename="$1"
    echo "$filename" | grep -oE '[0-9]+' | tail -1
}

# Función para generar nuevo nombre basado en estrategia
generate_new_name() {
    local strategy="$1"
    local old_file="$2"
    local index="$3"
    local total="$4"
    
    local basename=$(basename "$old_file")
    local extension="${basename##*.}"
    local prefix=""
    
    # Detectar prefijo (wall_ o wallpaper_)
    if [[ "$basename" =~ ^wall_ ]]; then
        prefix="wall_"
    elif [[ "$basename" =~ ^wallpaper_ ]]; then
        prefix="wallpaper_"
    else
        prefix="wall_"
    fi
    
    local new_number
    case "$strategy" in
        "reverse")
            new_number=$((total - index + 1))
            ;;
        "random")
            # Crear un hash único basado en el nombre del archivo original y fecha
            local seed=$(date +%Y%m%d)
            local hash=$(echo "$basename$seed" | md5sum | tr -d -c 0-9)
            # Usar el índice como base y el hash como desplazamiento para evitar duplicados
            new_number=$(( (index + ${hash:0:6}) % total + 1 ))
            ;;
        "chunks")
            local chunk_size=50
            local chunk_num=$((index / chunk_size))
            local pos_in_chunk=$((index % chunk_size))
            local total_chunks=$(((total + chunk_size - 1) / chunk_size))
            local new_chunk=$(((chunk_num + total_chunks / 2) % total_chunks))
            new_number=$((new_chunk * chunk_size + pos_in_chunk + 1))
            ;;
        "interleave")
            if [ $((index % 2)) -eq 0 ]; then
                new_number=$(((index / 2) + (total / 2) + 1))
            else
                new_number=$(((index / 2) + 1))
            fi
            ;;
    esac
    
    printf "%s%03d.%s" "$prefix" "$new_number" "$extension"
}

# Función principal de reorganización
reorganize_images() {
    local strategy="$1"
    
    echo -e "${BLUE} Aplicando estrategia: $strategy${NC}"
    
    # Crear backup automáticamente
    create_backup
    
    # Obtener lista de imágenes
    local images=($(get_image_list))
    local total=${#images[@]}
    
    echo -e "${BLUE} Total de imágenes: $total${NC}"
    
    # Crear directorio temporal
    local temp_dir=$(mktemp -d)
    
    echo -e "${BLUE} Reorganizando imágenes...${NC}"
    
    # Crear array de nuevos índices según estrategia
    local new_indices=()
    for i in $(seq 1 $total); do
        case "$strategy" in
            "reverse")
                new_indices[i]=$((total - i + 1))
                ;;
            "random")
                # Para random, creamos una lista y la mezclamos
                new_indices[i]=$i
                ;;
            "chunks")
                local chunk_size=50
                local chunk_num=$(((i-1) / chunk_size))
                local pos_in_chunk=$(((i-1) % chunk_size))
                local total_chunks=$(((total + chunk_size - 1) / chunk_size))
                local new_chunk=$(((chunk_num + total_chunks / 2) % total_chunks))
                new_indices[i]=$((new_chunk * chunk_size + pos_in_chunk + 1))
                ;;
            "interleave")
                if [ $(((i-1) % 2)) -eq 0 ]; then
                    new_indices[i]=$(((((i-1) / 2) + (total / 2)) % total + 1))
                else
                    new_indices[i]=$((((i-1) / 2) + 1))
                fi
                ;;
        esac
    done
    
    # Para random, mezclamos el array
    if [ "$strategy" = "random" ]; then
        # Usar una semilla basada en la fecha para reproducibilidad
        local seed=$(date +%Y%m%d)
        RANDOM="$seed"
        
        # Crear array con índices ordenados
        local temp_indices=()
        for i in $(seq 1 $total); do
            temp_indices+=($i)
        done
        
        # Algoritmo Fisher-Yates para mezclar
        for ((i = total - 1; i > 0; i--)); do
            local j=$((RANDOM % (i + 1)))
            # Intercambiar elementos i y j
            local temp=${temp_indices[i]}
            temp_indices[i]=${temp_indices[j]}
            temp_indices[j]=$temp
        done
        
        # Copiar a new_indices (ajustando índices para bash)
        for i in $(seq 1 $total); do
            new_indices[i]=${temp_indices[$((i-1))]}
        done
    fi
    
    # Copiar archivos con nuevos nombres
    for i in "${!images[@]}"; do
        local old_file="${images[$i]}"
        local basename=$(basename "$old_file")
        local extension="${basename##*.}"
        
        # Siempre usar formato wall_XXX estandarizado
        local new_index=${new_indices[$((i + 1))]}
        
        # Verificar que new_index no esté vacío
        if [ -z "$new_index" ] || [ "$new_index" -eq 0 ]; then
            echo -e "${RED} Error: Índice inválido para archivo $basename (índice: '$new_index')${NC}"
            rm -rf "$temp_dir"
            return 1
        fi
        
        local new_name=$(printf "wall_%03d.%s" "$new_index" "$extension")
        local new_path="$temp_dir/$new_name"
        
        # Verificar que no exista ya un archivo con ese nombre en temporal
        if [ -f "$new_path" ]; then
            echo -e "${RED} Error: Archivo duplicado detectado: $new_name${NC}"
            echo -e "${YELLOW}   Archivo original: $basename → Nuevo: $new_name${NC}"
            rm -rf "$temp_dir"
            return 1
        fi
        
        cp "$old_file" "$new_path"
        
        # Mostrar progreso cada 50 imágenes
        if [ $(((i + 1) % 50)) -eq 0 ]; then
            echo -e "${YELLOW}   Procesadas: $((i + 1))/$total${NC}"
        fi
    done
    
    # Verificar que se copiaron todos los archivos
    local copied_count=$(ls "$temp_dir" | wc -l)
    if [ "$copied_count" -ne "$total" ]; then
        echo -e "${RED} Error: Se copiaron $copied_count archivos pero esperaba $total${NC}"
        echo -e "${YELLOW} Limpiando directorio temporal y abortando...${NC}"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Limpiar directorio original y mover desde temporal
    rm -f "$ASSETS_DIR"/*.jpg "$ASSETS_DIR"/*.jpeg "$ASSETS_DIR"/*.png 2>/dev/null || true
    mv "$temp_dir"/* "$ASSETS_DIR"/
    rmdir "$temp_dir"
    
    # Verificación final
    local final_count=$(ls "$ASSETS_DIR" | wc -l)
    echo -e "${GREEN} Reorganización completada${NC}"
    echo -e "${BLUE} Resumen:${NC}"
    echo -e "   - Estrategia: $strategy"
    echo -e "   - Imágenes originales: $total"
    echo -e "   - Imágenes finales: $final_count"
    echo -e "   - Backup disponible en: $BACKUP_DIR"
    
    if [ "$final_count" -ne "$total" ]; then
        echo -e "${YELLOW}  Advertencia: El número final de archivos no coincide${NC}"
    fi
}

# Verificar que estamos en el directorio correcto
if [ ! -d "$ASSETS_DIR" ]; then
    echo -e "${RED} Error: No se encontró el directorio $ASSETS_DIR${NC}"
    echo -e "${YELLOW} Ejecuta este script desde el directorio raíz de WallPin${NC}"
    exit 1
fi

# Procesar argumentos
case "${1:-help}" in
    "reverse")
        echo -e "${GREEN}Modo: Inverso${NC}"
        echo -e "Las primeras imágenes serán las últimas y viceversa"
        reorganize_images "reverse"
        ;;
    "random")
        echo -e "${GREEN}Modo: Aleatorio${NC}"
        echo -e "Orden aleatorio reproducible (basado en fecha actual)"
        reorganize_images "random"
        ;;
    "chunks")
        echo -e "${GREEN}Modo: Bloques${NC}"
        echo -e "Intercambia bloques de 50 imágenes"
        reorganize_images "chunks"
        ;;
    "interleave")
        echo -e "${GREEN}Modo: Entrelazado${NC}"
        echo -e "Alterna imágenes pares e impares"
        reorganize_images "interleave"
        ;;
    "restore")
        restore_backup
        ;;
    "backup")
        create_backup
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    *)
        echo -e "${RED} Opción no válida: $1${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac

echo -e "\n${GREEN} ¡Operación completada!${NC}"
echo -e "${BLUE} Tip: Ejecuta './shuffle-wallpapers.sh restore' para volver al orden original${NC}"
