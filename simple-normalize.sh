#!/bin/bash

# Script simple para normalizar nombres de archivos de imágenes
# Versión robusta para manejar caracteres unicode problemáticos

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

ASSETS_DIR="./assets"
BACKUP_DIR="./assets_backup_$(date +%Y%m%d_%H%M%S)"

echo -e "${BLUE}🎯 Normalizador de imágenes - Versión Simple${NC}"

# Crear backup
echo -e "${BLUE}💾 Creando backup...${NC}"
if ! cp -r "$ASSETS_DIR" "$BACKUP_DIR"; then
    echo -e "${RED}❌ Error creando backup${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Backup creado en: $BACKUP_DIR${NC}"

# Contar archivos de imagen
total_files=$(find "$ASSETS_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | wc -l)
echo -e "${BLUE}📊 Total de archivos encontrados: $total_files${NC}"

# Crear directorio temporal
temp_dir=$(mktemp -d)
echo -e "${BLUE}📁 Directorio temporal: $temp_dir${NC}"

# Variables para conteo
counter=1
processed=0
errors=0

echo -e "${BLUE}🔄 Procesando archivos...${NC}"

# Procesar archivos uno por uno de forma más segura
while IFS= read -r -d '' file; do
    if [[ -f "$file" ]]; then
        # Obtener extensión
        extension=$(echo "${file##*.}" | tr '[:upper:]' '[:lower:]')
        
        # Generar nuevo nombre
        new_name=$(printf "wall_%03d.%s" "$counter" "$extension")
        new_path="$temp_dir/$new_name"
        
        # Copiar archivo
        if cp "$file" "$new_path" 2>/dev/null; then
            ((processed++))
            ((counter++))
            
            # Mostrar progreso cada 100 archivos
            if [ $((processed % 100)) -eq 0 ]; then
                echo -e "${YELLOW}   Procesados: $processed/$total_files${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️  Error procesando archivo #$processed${NC}"
            ((errors++))
        fi
    fi
done < <(find "$ASSETS_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -print0)

echo -e "${BLUE}📋 Resumen del procesamiento:${NC}"
echo -e "   - Archivos procesados: $processed"
echo -e "   - Errores: $errors"
echo -e "   - Total encontrado: $total_files"

# Verificar que se procesaron archivos
if [ "$processed" -eq 0 ]; then
    echo -e "${RED}❌ Error: No se procesaron archivos${NC}"
    rm -rf "$temp_dir"
    exit 1
fi

# Mostrar algunos archivos del resultado
echo -e "${BLUE}📝 Muestra de archivos procesados:${NC}"
ls "$temp_dir" | head -5

# Confirmar reemplazo
echo -e "${YELLOW}⚠️  ¿Reemplazar los archivos originales con los normalizados? (y/N)${NC}"
read -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}🔄 Reemplazando archivos...${NC}"
    
    # Limpiar directorio de destino
    find "$ASSETS_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -delete
    
    # Mover archivos normalizados
    if mv "$temp_dir"/* "$ASSETS_DIR"/; then
        rmdir "$temp_dir"
        
        # Verificación final
        final_count=$(find "$ASSETS_DIR" -name "wall_*.jpg" -o -name "wall_*.jpeg" -o -name "wall_*.png" | wc -l)
        echo -e "${GREEN}✅ Normalización completada${NC}"
        echo -e "${GREEN}📈 Archivos finales: $final_count${NC}"
        echo -e "${GREEN}💾 Backup disponible en: $BACKUP_DIR${NC}"
    else
        echo -e "${RED}❌ Error moviendo archivos normalizados${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}❌ Operación cancelada${NC}"
    rm -rf "$temp_dir"
    echo -e "${BLUE}💾 Backup conservado en: $BACKUP_DIR${NC}"
fi
