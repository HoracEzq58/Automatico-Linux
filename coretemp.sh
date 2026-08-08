#!/bin/bash

# Colores estéticos - "coretemp.sh" v2 - Modo 07/08/2026
VERDE='\033[0;32m'
AZUL='\033[0;34m'
AMARILLO='\033[1;33m'
RESET='\033[0m'

echo -e "${AZUL}=========================================${RESET}"
echo -e "${AZUL}     ESTADO DE TEMPERATURAS - TALLER     ${RESET}"
echo -e "${AZUL}=========================================${RESET}"

# 1. Detección de CPU por Núcleos independientes (Core 0 y Core 1)
echo -e "${VERDE}Temperaturas del CPU:${RESET}"
if sensors 2>/dev/null | grep -q 'Core 0'; then
    # Extrae de forma independiente cada núcleo para Intel Core 2 Duo
    TEMP_CORE0=$(sensors 2>/dev/null | grep 'Core 0' | awk '{print $3}')
    TEMP_CORE1=$(sensors 2>/dev/null | grep 'Core 1' | awk '{print $3}')
    echo -e "  - Core 0: $TEMP_CORE0"
    echo -e "  - Core 1: $TEMP_CORE1"
else
    # Respaldos para AMD o arquitecturas unificadas
    TEMP_CPU=$(sensors 2>/dev/null | grep -i 'Tctl' | head -n 1 | awk '{print $2}')
    [ -z "$TEMP_CPU" ] && TEMP_CPU="No detectada"
    echo -e "  - CPU General: $TEMP_CPU"
fi

# 2. Placa de Video Radeon dedicada
TEMP_GPU=$(sensors 2>/dev/null | grep -A 2 'radeon-pci' | grep 'temp1' | awk '{print $2}')
if [ ! -z "$TEMP_GPU" ]; then
    echo -e "${VERDE}GPU (Radeon Video):${RESET}     $TEMP_GPU"
fi

# 3. Resto de Discos HDD / SSD SATA
echo -e "${AMARILLO}Resto de discos HDD/SATA:${RESET}"

for disco in /dev/sd[a-z]; do
    if [ -b "$disco" ]; then
        NOMBRE=$(basename "$disco")
        MODELO=$(lsblk -d -o MODEL "$disco" | tail -n 1 | xargs)
        
        # FILTRO CRÍTICO: Si el disco está vacío (como el lector Multi-Card sin tarjeta), lo salta
        if [ "$MODELO" == "Multi-Card" ] || [ -z "$MODELO" ]; then
            continue
        fi
        
        # Intenta extraer la temperatura usando smartctl mediante el ID numérico de atributo estándar (ID 194 o 190)
        TEMP_HDD=$(sudo smartctl -A "$disco" 2>/dev/null | awk '$1 == 194 || $1 == 190 {print $10}')
        
        # Respaldo por texto si fallan los IDs numéricos estándar
        if [ -z "$TEMP_HDD" ]; then
            TEMP_HDD=$(sudo smartctl -a "$disco" 2>/dev/null | grep -i -E 'temperature_case|temperature_ambient|air_airflow_temperature|temperature_internal|Temperature' | awk '{print $10}' | head -n 1)
        fi

        if [ -z "$TEMP_HDD" ] || [ "$TEMP_HDD" == "0" ]; then
            TEMP_HDD="N/A"
        else
            TEMP_HDD="+${TEMP_HDD}.0°C"
        fi
        
        echo -e "  - Disco $NOMBRE ($MODELO): $TEMP_HDD"
    fi
done

echo -e "${AZUL}=========================================${RESET}"
