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
        echo -e "${YELLOW}⚠️  Backup de normalización ya existe${NC}"
        read -p "¿Sobrescribir? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${RED}❌ Operación cancelada${NC}"
            exit 1
        fi
        rm -rf "$BACKUP_DIR"
    fi
    
    echo -e "${BLUE}📦 Creando backup para normalización...${NC}"
    if ! cp -r -- "$ASSETS_DIR" "$BACKUP_DIR" 2>/dev/null; then
        echo -e "${RED}❌ Error creando backup. Verifica permisos y archivos con caracteres especiales${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Backup creado en $BACKUP_DIR${NC}"
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
    
    local temp_list=$(mktemp)
    find "$ASSETS_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | sort > "$temp_list"
    local counter=1
    local total_count=$(wc -l < "$temp_list")
    
    while IFS= read -r old_file; do
        local basename=$(basename "$old_file")
        local extension="${basename##*.}"
        local new_name=$(printf "wall_%03d.%s" "$counter" "$extension")
        
        if [ "$basename" != "$new_name" ]; then
            echo -e "${YELLOW}$basename${NC} → ${GREEN}$new_name${NC}"
        fi
        
        ((counter++))
    done < "$temp_list"
    
    rm -f "$temp_list"
    
    echo -e "\n${BLUE}📊 Total de archivos: $total_count${NC}"
    echo -e "${BLUE}🔄 Serán renumerados secuencialmente: wall_001 a wall_$(printf "%03d" $total_count)${NC}"
}

# Función para limpiar archivos con caracteres problemáticos
clean_problematic_files() {
    echo -e "${BLUE}🧹 Verificando archivos con caracteres especiales...${NC}"
    local cleaned=0
    local temp_list=$(mktemp)
    
    # Crear lista de archivos problemáticos usando null delimiter
    find "$ASSETS_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -print0 > "$temp_list"
    
    while IFS= read -r -d '' file; do
        local basename=$(basename "$file")
        
        # Si el archivo contiene caracteres que pueden causar problemas
        if [[ "$basename" =~ [^a-zA-Z0-9._\ -] ]]; then
            echo -e "${YELLOW}   Limpiando: ${basename:0:50}...${NC}"
            
            # Generar nuevo nombre limpio
            local extension="${basename##*.}"
            local clean_base=$(echo "$basename" | tr -cd 'a-zA-Z0-9._-' | head -c 40)
            local timestamp=$(date +%s%N | cut -c1-13)
            local clean_name="${clean_base}_${timestamp}.${extension}"
            
            # Si el nombre base está vacío, usar un nombre genérico
            if [[ -z "$clean_base" ]]; then
                clean_name="cleaned_file_${timestamp}.${extension}"
            fi
            
            # Renombrar el archivo problemático usando comillas y verificando existencia
            local new_path="$ASSETS_DIR/$clean_name"
            if [[ -f "$file" ]]; then
                if cp "$file" "$new_path" 2>/dev/null && rm "$file" 2>/dev/null; then
                    echo -e "${GREEN}   ✅ Renombrado a: $clean_name${NC}"
                    ((cleaned++))
                else
                    echo -e "${RED}   ❌ No se pudo limpiar: ${basename:0:30}...${NC}"
                fi
            else
                echo -e "${RED}   ⚠️  Archivo no encontrado: ${basename:0:30}...${NC}"
            fi
        fi
    done < "$temp_list"
    
    rm -f "$temp_list"
    
    if [ $cleaned -gt 0 ]; then
        echo -e "${GREEN}✅ Limpiados $cleaned archivos problemáticos${NC}"
    else
        echo -e "${GREEN}✅ No se encontraron archivos problemáticos para limpiar${NC}"
    fi
}

# Función principal de normalización
normalize_images() {
    echo -e "${BLUE}🎯 Normalizando nombres de archivos...${NC}"
    
    # Mostrar un preview rápido del total
    local temp_count=$(find "$ASSETS_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | wc -l)
    echo -e "${YELLOW}⚠️  Se van a renombrar $temp_count archivos${NC}"
    read -p "¿Continuar con la normalización? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}❌ Normalización cancelada${NC}"
        return 1
    fi
    
    # Primero limpiar archivos problemáticos
    clean_problematic_files
    
    # Crear backup automáticamente
    create_backup
    
    # Obtener lista de imágenes ordenada por nombre actual usando null delimiter
    local temp_list=$(mktemp)
    find "$ASSETS_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -print0 | sort -z > "$temp_list"
    local total=$(tr -dc '\0' < "$temp_list" | wc -c)
    
    echo -e "${BLUE}📊 Total de imágenes: $total${NC}"
    
    # Crear directorio temporal
    local temp_dir=$(mktemp -d)
    
    echo -e "${BLUE}🔄 Renombrando archivos...${NC}"
    
    # Copiar con nombres normalizados usando null delimiter
    local counter=1
    while IFS= read -r -d '' old_file; do
        local basename=$(basename "$old_file")
        local extension="${basename##*.}"
        local new_name=$(printf "wall_%03d.%s" "$counter" "$extension")
        local new_path="$temp_dir/$new_name"
        
        # Verificar que el archivo origen existe
        if [[ ! -f "$old_file" ]]; then
            echo -e "${YELLOW}⚠️  Archivo no existe: ${basename:0:40}...${NC}"
            continue
        fi
        
        # Copiar archivo con manejo de errores mejorado
        if cp "$old_file" "$new_path" 2>/dev/null; then
            # Mostrar progreso cada 100 archivos
            if [ $((counter % 100)) -eq 0 ]; then
                echo -e "${YELLOW}   Procesados: $counter/$total${NC}"
            fi
            ((counter++))
        else
            echo -e "${YELLOW}⚠️  Error copiando: ${basename:0:40}...${NC}"
        fi
    done < "$temp_list"
    
    rm -f "$temp_list"
    
    # Verificar que se copiaron archivos
    local copied_count=$(ls "$temp_dir" | wc -l)
    if [ "$copied_count" -eq 0 ]; then
        echo -e "${RED}❌ Error: No se copiaron archivos${NC}"
        rm -rf "$temp_dir"
        return 1
    fi
    
    if [ "$copied_count" -ne "$total" ]; then
        echo -e "${YELLOW}⚠️  Se copiaron $copied_count de $total archivos (algunos pueden tener caracteres problemáticos)${NC}"
    fi
    
    # Reemplazar archivos originales
    rm -f "$ASSETS_DIR"/*.jpg "$ASSETS_DIR"/*.jpeg "$ASSETS_DIR"/*.png 2>/dev/null || true
    mv "$temp_dir"/* "$ASSETS_DIR"/
    rmdir "$temp_dir"
    
    # Verificación final
    local final_count=$(ls "$ASSETS_DIR" | wc -l)
    echo -e "${GREEN}✅ Normalización completada${NC}"
    echo -e "${BLUE}📈 Resumen:${NC}"
    echo -e "   - Archivos originales: $total"
    echo -e "   - Archivos finales: $final_count"
    echo -e "   - Formato: wall_001 a wall_$(printf "%03d" $final_count)"
    echo -e "   - Backup disponible en: $BACKUP_DIR"
}

# Función para restaurar
restore_backup() {
    if [ ! -d "$BACKUP_DIR" ]; then
        echo -e "${RED}❌ No se encontró backup en $BACKUP_DIR${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}🔄 Restaurando desde backup de normalización...${NC}"
    rm -rf "$ASSETS_DIR"
    cp -r "$BACKUP_DIR" "$ASSETS_DIR"
    echo -e "${GREEN}✅ Archivos restaurados${NC}"
}

# Verificar directorio
if [ ! -d "$ASSETS_DIR" ]; then
    echo -e "${RED}❌ Error: No se encontró el directorio $ASSETS_DIR${NC}"
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
        echo -e "${RED}❌ Opción no válida: $1${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac

echo -e "\n${GREEN}🎉 ¡Operación completada!${NC}"
