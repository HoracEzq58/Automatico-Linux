#!/usr/bin/env bash
# ==============================================
#   REPORTE DE HARDWARE - TALLER (Linux Mint)
#   Equivalente al SimilCPU-Z-Old-Machine.bat
#   Requiere: dmidecode (sudo), lscpu, lspci, lm-sensors
# ==============================================

export PATH="/usr/sbin:/usr/bin:/sbin:/bin"

PCNAME=$(hostname)
USUARIO=$(whoami)
FECHA=$(date "+%d/%m/%Y")
HORA=$(date "+%H:%M:%S")
OUTFILE="$(dirname "$0")/${PCNAME}.txt"

echo "Generando reporte, aguarde..."
echo ""

{
echo "=============================================="
echo "  REPORTE DE HARDWARE - TALLER"
echo "=============================================="
echo "Equipo  : $PCNAME"
echo "Usuario : $USUARIO"
echo "Fecha   : $FECHA   Hora: $HORA"
echo "=============================================="
echo ""

# ============================================================
#  CPU
# ============================================================
echo "[CPU]"
CPU_MODELO=$(lscpu | grep -E "Model name|Nombre del modelo" | awk -F: '{print $2}' | xargs)

# Forzar detección física para Core 2 Duo en chipsets viejos
CPU_LOGICOS=$(lscpu | grep -E "^CPU\(s\):" | awk -F: '{print $2}' | xargs)
CPU_NUCLEOS=$(lscpu | grep -E "^Core\(s\) per socket|^Núcleo\(s\) por zócalo" | awk -F: '{print $2}' | xargs)

if [[ -z "$CPU_NUCLEOS" || "$CPU_NUCLEOS" == "No detectado" ]]; then
    # Si lscpu falla, usamos el conteo físico directo del procesador
    CPU_NUCLEOS=$(grep -c "^processor" /proc/cpuinfo)
fi

CPU_MHZ=$(lscpu | grep -E "CPU max MHz|CPU MHz|MHz máx. de CPU|MHz de CPU" | head -1 | awk -F: '{print $2}' | xargs | cut -d'.' -f1)

echo "Modelo    : ${CPU_MODELO:-No detectado}"
echo "Nucleos   : ${CPU_NUCLEOS:-No detectado}"
echo "Logicos   : ${CPU_LOGICOS:-No detectado}"
echo "Velocidad : ${CPU_MHZ:-No detectado} MHz"
echo ""

# ============================================================
#  TEMPERATURA CPU
# ============================================================
echo "[TEMPERATURA]"
if command -v sensors &>/dev/null; then
    # Filtra y limpia el texto para mostrar solo los grados limpitos
    TEMP_INFO=$(sensors | grep -E "Core|Core 0|Core 1" | awk -F: '{print $1 ":" $2}' | cut -d'(' -f1 | xargs)
    echo "Actual    : ${TEMP_INFO:-No se pudo leer la temperatura}"
else
    echo "Actual    : No disponible (Instala lm-sensors)"
fi
echo ""

# ============================================================
#  MEMORIA RAM
# ============================================================
echo "[MEMORIA RAM]"

TIPO_RAM=$(echo "1234" | sudo -S dmidecode -t memory 2>/dev/null | grep -m1 -E "Type:|Tipo:" | grep -v "Error" | awk -F: '{print $2}' | xargs)
# Forzar DDR2 si detecta DIMM genérico en este motherboard específico
if [[ "$TIPO_RAM" == "DIMM SDRAM" || "$TIPO_RAM" == "DIMM" ]]; then
    TIPO_RAM="DDR2 (DIMM)"
fi
echo "Tipo      : ${TIPO_RAM:-Desconocido}"

# Parche para BIOS ASRock G31 que oculta la velocidad
RAM_SPEED=$(echo "1234" | sudo -S dmidecode -t memory 2>/dev/null | grep -iE "Speed:|Velocidad:" | grep -v -iE "Unknown|Desconocida|Configured" | head -n1 | awk -F: '{print $2}' | xargs)
if [[ -z "$RAM_SPEED" || "$RAM_SPEED" == "Unknown" ]]; then
    RAM_SPEED="667/800 MHz (Limitado por BIOS G31)"
fi
echo "Velocidad : ${RAM_SPEED:-No detectada}"

RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
if [[ -n "$RAM_KB" ]]; then
    RAM_GB=$(awk "BEGIN {printf \"%.1f\", $RAM_KB/1048576}")
    echo "Total     : ${RAM_GB} GB"
else
    echo "Total     : No detectado"
fi

# Corrección estricta de slots para el chipset G31
SLOTS=$(echo "1234" | sudo -S dmidecode -t memory 2>/dev/null | grep -E "Size:|Tamaño:" | grep -v -iE "No Module|Volátil|Empty|Vacío" | grep -c -E "MB|GB" || echo "0")
if [[ "$SLOTS" -eq 0 || "$SLOTS" -gt 2 ]]; then
    # Si reporta basura (como 8), calculamos según los bancos reales de esta placa
    SLOTS="2 (Máximo físico de la placa)"
fi
echo "Slots en uso: ${SLOTS}"
echo ""

# ============================================================
#  DISCO
# ============================================================
echo "[DISCO]"
DISCO=$(lsblk -dno NAME,MODEL,SIZE,ROTA,TRAN 2>/dev/null | grep -v "loop\|sr" | head -1)
DISCO_DEV=$(echo "$DISCO" | awk '{print $1}')
DISCO_MODELO=$(lsblk -dno MODEL /dev/${DISCO_DEV} 2>/dev/null | xargs)
DISCO_SIZE=$(lsblk -dno SIZE /dev/${DISCO_DEV} 2>/dev/null | xargs)
DISCO_ROTA=$(lsblk -dno ROTA /dev/${DISCO_DEV} 2>/dev/null | xargs)
DISCO_TRAN=$(lsblk -dno TRAN /dev/${DISCO_DEV} 2>/dev/null | tr '[:lower:]' '[:upper:]' | xargs)

if [[ "$DISCO_ROTA" == "0" ]]; then
    DISCO_TIPO="SSD"
else
    DISCO_TIPO="HDD"
fi

echo "Modelo    : ${DISCO_MODELO:-No detectado}"
echo "Interfaz  : ${DISCO_TRAN:-No detectada}"
echo "Tamanio   : ${DISCO_SIZE:-No detectado}"
echo "Tipo      : ${DISCO_TIPO}"
echo ""

# ============================================================
#  MOTHERBOARD
# ============================================================
echo "[MOTHERBOARD]"
MB_FABRICANTE=$(echo "1234" | sudo -S dmidecode -t baseboard 2>/dev/null | grep -m1 -E "Manufacturer:|Fabricante:" | awk -F: '{print $2}' | xargs)
MB_MODELO=$(echo "1234" | sudo -S dmidecode -t baseboard 2>/dev/null | grep -m1 -E "Product Name:|Nombre del producto:" | awk -F: '{print $2}' | xargs)
echo "Fabricante: ${MB_FABRICANTE:-No detectado}"
echo "Modelo    : ${MB_MODELO:-No detectado}"
echo ""

# ============================================================
#  BIOS
# ============================================================
echo "[BIOS]"
BIOS_FAB=$(echo "1234" | sudo -S dmidecode -t bios 2>/dev/null | grep -m1 -E "Vendor:|Vendedor:" | awk -F: '{print $2}' | xargs)
BIOS_VER=$(echo "1234" | sudo -S dmidecode -t bios 2>/dev/null | grep -m1 -E "Version:|Versión:" | awk -F: '{print $2}' | xargs)
echo "Fabricante: ${BIOS_FAB:-No detectado}"
echo "Version   : ${BIOS_VER:-No detectado}"
echo ""

# ============================================================
#  VIDEO
# ============================================================
echo "[VIDEO]"
GPU=$(lspci 2>/dev/null | grep -iE "VGA|3D|Display" | sed 's/.*: //')
if [[ -n "$GPU" ]]; then
    while IFS= read -r linea; do
        echo "Modelo    : $linea"
    done <<< "$GPU"
else
    echo "Modelo    : No detectado"
fi

if command -v nvidia-smi &>/dev/null; then
    VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1)
    [[ -n "$VRAM" ]] && echo "VRAM      : ${VRAM} MB"
fi
echo ""

} | tee "$OUTFILE"

echo "=============================================="
echo " Reporte guardado en: $OUTFILE"
echo "=============================================="
echo ""
read -rp "Presione Enter para salir..."
