#!/bin/bash
# coretemp.sh - Versión mejorada 17/08/2026 Grok
# Taller ABC PC - Compatible con AMD Athlon/Phenom + Radeon HD 4xxx y discos SATA/NVMe

VERDE='\033[0;32m'
AZUL='\033[0;34m'
AMARILLO='\033[1;33m'
ROJO='\033[0;31m'
CYAN='\033[0;36m'
RESET='\033[0m'

echo -e "${AZUL}=========================================${RESET}"
echo -e "${AZUL}     ESTADO DE TEMPERATURAS - TALLER     ${RESET}"
echo -e "${AZUL}=========================================${RESET}"

# --------------------------------------------------
# 1. Temperaturas del CPU
# --------------------------------------------------
echo -e "${VERDE}Temperaturas del CPU:${RESET}"

SENSORS_OUT=$(sensors 2>/dev/null)

if echo "$SENSORS_OUT" | grep -q 'Core 0'; then
    # Intel clásico (Core 2 Duo, etc.)
    TEMP_CORE0=$(echo "$SENSORS_OUT" | grep 'Core 0' | awk '{print $3}')
    TEMP_CORE1=$(echo "$SENSORS_OUT" | grep 'Core 1' | awk '{print $3}')
    echo -e "  - Core 0: ${TEMP_CORE0:-N/A}"
    echo -e "  - Core 1: ${TEMP_CORE1:-N/A}"
else
    # AMD (Phenom, Athlon II, FX, Ryzen viejos) y otros
    TEMP_CPU=$(echo "$SENSORS_OUT" | grep -iE 'Tctl|Tdie|Package id 0|temp1:' | head -n 1 | awk '{print $2}')
    
    if [ -z "$TEMP_CPU" ]; then
        TEMP_CPU=$(echo "$SENSORS_OUT" | grep -i 'CPU Temperature\|temp1' | head -n 1 | awk '{print $2}')
    fi
    
    if [ -z "$TEMP_CPU" ]; then
        echo -e "  - CPU General: ${ROJO}No detectada${RESET}"
    else
        echo -e "  - CPU General: $TEMP_CPU"
    fi
fi

# --------------------------------------------------
# 2. GPU (Radeon integrada o dedicada)
# --------------------------------------------------
TEMP_GPU=$(echo "$SENSORS_OUT" | grep -A5 -iE 'radeon|amdgpu|pci' | grep -i 'temp1' | head -n 1 | awk '{print $2}')

if [ -n "$TEMP_GPU" ]; then
    echo -e "${VERDE}GPU (Radeon/AMD):${RESET}       $TEMP_GPU"
fi

# --------------------------------------------------
# 3. Discos (SATA + NVMe)
# --------------------------------------------------
echo -e "${AMARILLO}Discos HDD / SSD:${RESET}"

# Función auxiliar para sacar temperatura de un disco
get_disk_temp() {
    local disco="$1"
    local temp=""

    # Intento principal con atributos SMART estándar
    temp=$(sudo smartctl -A "$disco" 2>/dev/null | awk '
        $1 == 194 || $1 == 190 {print $10; exit}
        /Temperature_Celsius|Airflow_Temperature|Temperature_Internal|Temperature/ {print $10; exit}
    ')

    # Respaldo más amplio
    if [ -z "$temp" ] || [ "$temp" = "0" ]; then
        temp=$(sudo smartctl -a "$disco" 2>/dev/null | grep -iE 'Temperature|Temp' | head -n 1 | awk '{print $10}')
    fi

    if [ -z "$temp" ] || [ "$temp" = "0" ]; then
        echo "N/A"
    else
        # A veces smartctl devuelve solo el número
        if [[ "$temp" =~ ^[0-9]+$ ]]; then
            echo "+${temp}.0°C"
        else
            echo "$temp"
        fi
    fi
}

# SATA / SCSI
for disco in /dev/sd[a-z]; do
    [ -b "$disco" ] || continue

    MODELO=$(lsblk -d -no MODEL "$disco" 2>/dev/null | xargs)
    # Filtrar lectores de tarjetas y dispositivos vacíos
    if [[ -z "$MODELO" || "$MODELO" == *"Multi-Card"* || "$MODELO" == *"Card"* ]]; then
        continue
    fi

    NOMBRE=$(basename "$disco")
    TEMP=$(get_disk_temp "$disco")
    echo -e "  - $NOMBRE ($MODELO): $TEMP"
done

# NVMe (por si en el futuro ponen SSD modernos)
for disco in /dev/nvme[0-9]n[0-9]; do
    [ -b "$disco" ] || continue
    MODELO=$(lsblk -d -no MODEL "$disco" 2>/dev/null | xargs)
    NOMBRE=$(basename "$disco")
    TEMP=$(get_disk_temp "$disco")
    echo -e "  - $NOMBRE ($MODELO): $TEMP"
done

echo -e "${AZUL}=========================================${RESET}"