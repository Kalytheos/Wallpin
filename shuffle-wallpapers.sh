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
        echo -e "${YELLOW}⚠️  Backup ya existe en $BACKUP_DIR${NC}"
        read -p "¿Sobrescribir backup existente? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${RED}❌ Operación cancelada${NC}"
            exit 1
        fi
        rm -rf "$BACKUP_DIR"
    fi
    
    echo -e "${BLUE}📦 Creando backup...${NC}"
    cp -r "$ASSETS_DIR" "$BACKUP_DIR"
    echo -e "${GREEN}✅ Backup creado en $BACKUP_DIR${NC}"
}

# Función para restaurar backup
restore_backup() {
    if [ ! -d "$BACKUP_DIR" ]; then
        echo -e "${RED}❌ No se encontró backup en $BACKUP_DIR${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}🔄 Restaurando desde backup...${NC}"
    rm -rf "$ASSETS_DIR"
    cp -r "$BACKUP_DIR" "$ASSETS_DIR"
    echo -e "${GREEN}✅ Imágenes restauradas al orden original${NC}"
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
            # Usar fecha como semilla para reproducibilidad
            local seed=$(date +%Y%m%d)
            new_number=$(echo "$index$seed" | md5sum | tr -d -c 0-9 | cut -c1-3)
            new_number=$((new_number % total + 1))
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
    
    echo -e "${BLUE}🎯 Aplicando estrategia: $strategy${NC}"
    
    # Crear backup automáticamente
    create_backup
    
    # Obtener lista de imágenes
    local images=($(get_image_list))
    local total=${#images[@]}
    
    echo -e "${BLUE}📊 Total de imágenes: $total${NC}"
    
    # Crear directorio temporal
    local temp_dir=$(mktemp -d)
    
    echo -e "${BLUE}🔄 Reorganizando imágenes...${NC}"
    
    # Generar mapeo y mover a temporal
    for i in "${!images[@]}"; do
        local old_file="${images[$i]}"
        local new_name=$(generate_new_name "$strategy" "$old_file" $((i + 1)) "$total")
        local new_path="$temp_dir/$new_name"
        
        cp "$old_file" "$new_path"
        
        # Mostrar progreso cada 50 imágenes
        if [ $(((i + 1) % 50)) -eq 0 ]; then
            echo -e "${YELLOW}   Procesadas: $((i + 1))/$total${NC}"
        fi
    done
    
    # Limpiar directorio original y mover desde temporal
    rm -f "$ASSETS_DIR"/*.jpg "$ASSETS_DIR"/*.jpeg "$ASSETS_DIR"/*.png 2>/dev/null || true
    mv "$temp_dir"/* "$ASSETS_DIR"/
    rmdir "$temp_dir"
    
    echo -e "${GREEN}✅ Reorganización completada${NC}"
    echo -e "${BLUE}📈 Resumen:${NC}"
    echo -e "   - Estrategia: $strategy"
    echo -e "   - Imágenes procesadas: $total"
    echo -e "   - Backup disponible en: $BACKUP_DIR"
}

# Verificar que estamos en el directorio correcto
if [ ! -d "$ASSETS_DIR" ]; then
    echo -e "${RED}❌ Error: No se encontró el directorio $ASSETS_DIR${NC}"
    echo -e "${YELLOW}💡 Ejecuta este script desde el directorio raíz de WallPin${NC}"
    exit 1
fi

# Procesar argumentos
case "${1:-help}" in
    "reverse")
        echo -e "${GREEN}🔄 Modo: Inverso${NC}"
        echo -e "Las primeras imágenes serán las últimas y viceversa"
        reorganize_images "reverse"
        ;;
    "random")
        echo -e "${GREEN}🎲 Modo: Aleatorio${NC}"
        echo -e "Orden aleatorio reproducible (basado en fecha actual)"
        reorganize_images "random"
        ;;
    "chunks")
        echo -e "${GREEN}📦 Modo: Bloques${NC}"
        echo -e "Intercambia bloques de 50 imágenes"
        reorganize_images "chunks"
        ;;
    "interleave")
        echo -e "${GREEN}🔀 Modo: Entrelazado${NC}"
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
        echo -e "${RED}❌ Opción no válida: $1${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac

echo -e "\n${GREEN}🎉 ¡Operación completada!${NC}"
echo -e "${BLUE}💡 Tip: Ejecuta './shuffle-wallpapers.sh restore' para volver al orden original${NC}"
