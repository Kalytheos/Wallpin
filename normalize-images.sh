#!/bin/bash

# WallPin Image Normalizer
# Estandariza los nombres de imágenes para un formato consistente

set -e

ASSETS_DIR="./assets"
BACKUP_DIR="./assets_backup_normalize"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para mostrar ayuda
show_help() {
    echo -e "${BLUE}WallPin Image Normalizer${NC}"
    echo -e "Estandariza nombres de archivos de imagen a un formato consistente\n"
    echo "Uso: $0 [OPCIÓN]"
    echo ""
    echo "Opciones:"
    echo "  normalize  - Renombra a formato wall_001.ext"
    echo "  restore    - Restaura desde backup"
    echo "  preview    - Muestra qué cambios se harían (sin aplicar)"
    echo "  help       - Muestra esta ayuda"
    echo ""
    echo "Formato objetivo: wall_001.jpg, wall_002.png, etc."
    echo "Maneja: wall_XXX, wallpaper_XXXX, números inconsistentes"
}

# Función para crear backup
create_backup() {
    if [ -d "$BACKUP_DIR" ]; then
        echo -e "${YELLOW}Backup de normalización ya existe${NC}"
        read -p "¿Sobrescribir? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${RED}Operación cancelada${NC}"
            exit 1
        fi
        rm -rf "$BACKUP_DIR"
    fi
    
    echo -e "${BLUE}Creando backup para normalización...${NC}"
    cp -r "$ASSETS_DIR" "$BACKUP_DIR"
    echo -e "${GREEN}Backup creado en $BACKUP_DIR${NC}"
}

# Función para obtener número de archivo
extract_number_smart() {
    local filename="$1"
    local basename=$(basename "$filename" | sed 's/\.[^.]*$//')
    
    # Extraer último número del nombre
    local number=$(echo "$basename" | grep -oE '[0-9]+$')
    echo "$number"
}

# Función para preview
preview_changes() {
    echo -e "${BLUE}🔍 Preview de cambios (sin aplicar):${NC}\n"
    
    local images=($(find "$ASSETS_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | sort))
    local counter=1
    
    for old_file in "${images[@]}"; do
        local basename=$(basename "$old_file")
        local extension="${basename##*.}"
        local new_name=$(printf "wall_%03d.%s" "$counter" "$extension")
        
        if [ "$basename" != "$new_name" ]; then
            echo -e "${YELLOW}$basename${NC} → ${GREEN}$new_name${NC}"
        fi
        
        ((counter++))
    done
    
    echo -e "\n${BLUE}Total de archivos: ${#images[@]}${NC}"
    echo -e "${BLUE}Serán renumerados secuencialmente: wall_001 a wall_$(printf "%03d" ${#images[@]})${NC}"
}

# Función principal de normalización
normalize_images() {
    echo -e "${BLUE}Normalizando nombres de archivos...${NC}"
    
    # Crear backup automáticamente
    create_backup
    
    # Obtener lista de imágenes ordenada por nombre actual
    local images=($(find "$ASSETS_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | sort))
    local total=${#images[@]}
    
    echo -e "${BLUE}Total de imágenes: $total${NC}"
    
    # Crear directorio temporal
    local temp_dir=$(mktemp -d)
    
    echo -e "${BLUE}Renombrando archivos...${NC}"
    
    # Copiar con nombres normalizados
    local counter=1
    for old_file in "${images[@]}"; do
        local basename=$(basename "$old_file")
        local extension="${basename##*.}"
        local new_name=$(printf "wall_%03d.%s" "$counter" "$extension")
        local new_path="$temp_dir/$new_name"
        
        cp "$old_file" "$new_path"
        
        # Mostrar progreso cada 50 archivos
        if [ $((counter % 50)) -eq 0 ]; then
            echo -e "${YELLOW}   Procesados: $counter/$total${NC}"
        fi
        
        ((counter++))
    done
    
    # Verificar que se copiaron todos los archivos
    local copied_count=$(ls "$temp_dir" | wc -l)
    if [ "$copied_count" -ne "$total" ]; then
        echo -e "${RED}Error: Se copiaron $copied_count archivos pero esperaba $total${NC}"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Reemplazar archivos originales
    rm -f "$ASSETS_DIR"/*.jpg "$ASSETS_DIR"/*.jpeg "$ASSETS_DIR"/*.png 2>/dev/null || true
    mv "$temp_dir"/* "$ASSETS_DIR"/
    rmdir "$temp_dir"
    
    # Verificación final
    local final_count=$(ls "$ASSETS_DIR" | wc -l)
    echo -e "${GREEN}Normalización completada${NC}"
    echo -e "${BLUE}Resumen:${NC}"
    echo -e "   - Archivos originales: $total"
    echo -e "   - Archivos finales: $final_count"
    echo -e "   - Formato: wall_001 a wall_$(printf "%03d" $final_count)"
    echo -e "   - Backup disponible en: $BACKUP_DIR"
}

# Función para restaurar
restore_backup() {
    if [ ! -d "$BACKUP_DIR" ]; then
        echo -e "${RED} No se encontró backup en $BACKUP_DIR${NC}"
        exit 1
    fi
    
    echo -e "${BLUE} Restaurando desde backup de normalización...${NC}"
    rm -rf "$ASSETS_DIR"
    cp -r "$BACKUP_DIR" "$ASSETS_DIR"
    echo -e "${GREEN} Archivos restaurados${NC}"
}

# Verificar directorio
if [ ! -d "$ASSETS_DIR" ]; then
    echo -e "${RED} Error: No se encontró el directorio $ASSETS_DIR${NC}"
    exit 1
fi

# Procesar argumentos
case "${1:-help}" in
    "normalize")
        echo -e "${GREEN}🔧 Modo: Normalizar${NC}"
        echo -e "Renombrando a formato wall_XXX.ext estándar"
        normalize_images
        ;;
    "preview")
        preview_changes
        ;;
    "restore")
        restore_backup
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
