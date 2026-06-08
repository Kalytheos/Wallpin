#!/bin/bash

# Script para verificar el uso de memoria de WallPin antes y después de optimizaciones
# Uso: ./test-memory.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  WallPin - Memory Usage Test${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

# Verificar que el binario existe
if [ ! -f "./wallpin-wallpaper" ]; then
    echo -e "${RED}❌ Error: wallpin-wallpaper no encontrado${NC}"
    echo -e "${YELLOW}   Ejecuta 'make' primero${NC}"
    exit 1
fi

# Contar imágenes
IMAGE_COUNT=$(find assets/ -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | wc -l)
echo -e "${BLUE}📊 Imágenes encontradas: ${IMAGE_COUNT}${NC}"
echo ""

# Memoria disponible antes
MEMORY_BEFORE=$(free -m | awk 'NR==2{printf "%.2f GB", $7/1024}')
echo -e "${BLUE}💾 Memoria disponible antes: ${MEMORY_BEFORE}${NC}"
echo ""

echo -e "${YELLOW}⚠️  Iniciando WallPin en background...${NC}"
echo -e "${YELLOW}   Presiona Ctrl+C para detener el test${NC}"
echo ""

# Iniciar wallpin en background
./wallpin-wallpaper &
WALLPIN_PID=$!

# Esperar a que cargue
sleep 2

echo -e "${BLUE}🔍 Monitoreando uso de memoria...${NC}"
echo ""

# Función para limpiar al salir
cleanup() {
    echo ""
    echo -e "${YELLOW}🛑 Deteniendo WallPin...${NC}"
    kill $WALLPIN_PID 2>/dev/null
    wait $WALLPIN_PID 2>/dev/null
    echo -e "${GREEN}✅ Test completado${NC}"
    exit 0
}

trap cleanup INT TERM

# Monitorear memoria cada 2 segundos
COUNT=0
MAX_MEMORY=0
MIN_MEMORY=999999

while kill -0 $WALLPIN_PID 2>/dev/null; do
    # Obtener uso de memoria del proceso
    MEMORY=$(ps -p $WALLPIN_PID -o rss= 2>/dev/null)
    
    if [ -n "$MEMORY" ]; then
        MEMORY_MB=$(echo "scale=2; $MEMORY/1024" | bc)
        MEMORY_GB=$(echo "scale=3; $MEMORY/1048576" | bc)
        
        # Actualizar máximo y mínimo
        MEMORY_INT=$(echo "$MEMORY" | awk '{print int($1)}')
        if [ "$MEMORY_INT" -gt "$MAX_MEMORY" ]; then
            MAX_MEMORY=$MEMORY_INT
        fi
        if [ "$MEMORY_INT" -lt "$MIN_MEMORY" ] || [ "$MIN_MEMORY" -eq 999999 ]; then
            MIN_MEMORY=$MEMORY_INT
        fi
        
        # Determinar color según uso
        if (( $(echo "$MEMORY_MB < 200" | bc -l) )); then
            COLOR=$GREEN
            STATUS="✅ EXCELENTE"
        elif (( $(echo "$MEMORY_MB < 500" | bc -l) )); then
            COLOR=$BLUE
            STATUS="✓ BUENO"
        elif (( $(echo "$MEMORY_MB < 1500" | bc -l) )); then
            COLOR=$YELLOW
            STATUS="⚠ ACEPTABLE"
        else
            COLOR=$RED
            STATUS="❌ ALTO"
        fi
        
        echo -e "${COLOR}[$COUNT] RAM: ${MEMORY_MB} MB (${MEMORY_GB} GB) - ${STATUS}${NC}"
        
        ((COUNT++))
    else
        echo -e "${RED}❌ Proceso terminado inesperadamente${NC}"
        break
    fi
    
    sleep 2
done

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Resumen del Test${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

MAX_MB=$(echo "scale=2; $MAX_MEMORY/1024" | bc)
MIN_MB=$(echo "scale=2; $MIN_MEMORY/1024" | bc)
AVG_MB=$(echo "scale=2; ($MAX_MEMORY + $MIN_MEMORY) / 2 / 1024" | bc)

echo -e "📊 Imágenes procesadas: ${IMAGE_COUNT}"
echo -e "📈 Memoria mínima: ${GREEN}${MIN_MB} MB${NC}"
echo -e "📈 Memoria máxima: ${BLUE}${MAX_MB} MB${NC}"
echo -e "📊 Memoria promedio: ${YELLOW}${AVG_MB} MB${NC}"
echo -e "⏱️  Muestras tomadas: ${COUNT}"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Evaluación de Optimizaciones${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

# Evaluar resultados
if (( $(echo "$MAX_MB < 300" | bc -l) )); then
    echo -e "${GREEN}✅ EXCELENTE: Las optimizaciones funcionan perfectamente${NC}"
    echo -e "${GREEN}   El uso de memoria es ${MAX_MB} MB (objetivo: <300 MB)${NC}"
elif (( $(echo "$MAX_MB < 1500" | bc -l) )); then
    echo -e "${YELLOW}⚠️  BUENO: Las optimizaciones ayudan pero hay margen de mejora${NC}"
    echo -e "${YELLOW}   El uso de memoria es ${MAX_MB} MB (objetivo: <300 MB)${NC}"
    echo -e "${YELLOW}   Considera implementar lazy loading${NC}"
else
    echo -e "${RED}❌ ALTO: El uso de memoria sigue siendo elevado${NC}"
    echo -e "${RED}   El uso de memoria es ${MAX_MB} MB${NC}"
    echo -e "${RED}   Revisar si hay memory leaks o imágenes sin optimizar${NC}"
fi

echo ""

# Memoria disponible después
MEMORY_AFTER=$(free -m | awk 'NR==2{printf "%.2f GB", $7/1024}')
echo -e "${BLUE}💾 Memoria disponible después: ${MEMORY_AFTER}${NC}"

cleanup
