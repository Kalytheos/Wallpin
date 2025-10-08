#!/bin/bash

# WallPin Quick Shuffle
# Script simple para cambios rápidos de orden

ASSETS_DIR="./assets"

# Función simple de intercambio
quick_reverse() {
    echo "Intercambiando orden de imágenes..."
    
    # Crear array con todas las imágenes
    mapfile -t images < <(find "$ASSETS_DIR" -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" | sort)
    total=${#images[@]}
    
    echo "Total: $total imágenes"
    
    # Crear directorio temporal
    temp_dir=$(mktemp -d)
    
    # Intercambiar: primera ↔ última, segunda ↔ penúltima, etc.
    for ((i=0; i<total; i++)); do
        old_file="${images[$i]}"
        new_index=$((total - 1 - i))
        target_file="${images[$new_index]}"
        target_name=$(basename "$target_file")
        
        cp "$old_file" "$temp_dir/$target_name"
    done
    
    # Reemplazar originales
    rm -f "$ASSETS_DIR"/*.{jpg,jpeg,png} 2>/dev/null
    mv "$temp_dir"/* "$ASSETS_DIR"/
    rmdir "$temp_dir"
    
    echo "¡Orden invertido!"
}

if [ ! -d "$ASSETS_DIR" ]; then
    echo "Error: Ejecuta desde el directorio raíz de WallPin"
    exit 1
fi

quick_reverse
