#!/bin/bash

# Colores estéticos
VERDE='\033[0;32m'
AZUL='\033[0;34m'
AMARILLO='\033[1;33m'
RESET='\033[0m'

echo -e "${AZUL}=========================================${RESET}"
echo -e "${AZUL}     ESTADO DE TEMPERATURAS - TALLER     ${RESET}"
echo -e "${AZUL}=========================================${RESET}"

# 1. Detección de CPU (Corregido para Intel Core 2 Duo / AMD)
if sensors 2>/dev/null | grep -q 'Core 0'; then
    # Formato Intel Viejo: Extrae la tercera columna limpia
    TEMP_CPU=$(sensors 2>/dev/null | grep 'Core 0' | awk '{print $3}' | tr -d '+')
else
    # Formato AMD / Otros: Busca Tctl
    TEMP_CPU=$(sensors 2>/dev/null | grep -i 'Tctl' | head -n 1 | awk '{print $2}' | tr -d '+')
fi

if [ -z "$TEMP_CPU" ]; then
    TEMP_CPU="No detectada"
fi
echo -e "${VERDE}CPU (Core 2 Duo):${RESET}       $TEMP_CPU"

# 2. Placa de Video Radeon dedicada (¡Agregada!)
TEMP_GPU=$(sensors 2>/dev/null | grep -A 2 'radeon-pci' | grep 'temp1' | awk '{print $2}' | tr -d '+')
if [ ! -z "$TEMP_GPU" ]; then
    echo -e "${VERDE}GPU (Radeon Video):${RESET}     $TEMP_GPU"
fi

# 3. Resto de Discos HDD / SSD SATA
echo -e "${AMARILLO}Resto de discos HDD/SATA:${RESET}"

for disco in /dev/sd[a-z]; do
    if [ -b "$disco" ]; then
        NOMBRE=$(basename "$disco")
        MODELO=$(lsblk -d -o MODEL "$disco" | tail -n 1 | xargs)
        
        TEMP_HDD=$(sudo smartctl -a "$disco" 2>/dev/null | grep -i -E 'temperature_case|temperature_ambient|air_airflow_temperature|temperature_internal|Temperature' | awk '{print $10}' | head -n 1)
        
        if [ -z "$TEMP_HDD" ] || [ "$TEMP_HDD" == "0" ]; then
            TEMP_HDD=$(sudo smartctl -a "$disco" 2>/dev/null | grep -i 'Temperature' | awk '{print $4}' | head -n 1)
        fi

        if [ -z "$TEMP_HDD" ]; then
            TEMP_HDD="N/A"
        else
            TEMP_HDD="+${TEMP_HDD}.0°C"
        fi
        
        echo -e "  - Disco $NOMBRE ($MODELO): $TEMP_HDD"
    fi
done

echo -e "${AZUL}=========================================${RESET}"