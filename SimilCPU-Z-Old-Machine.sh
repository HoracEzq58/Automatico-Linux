#!/usr/bin/env bash
# ==============================================
#   REPORTE DE HARDWARE - TALLER (Linux Mint)
#   Equivalente al SimilCPU-Z-Old-Machine.bat
#   Requiere: dmidecode (sudo), lscpu, lspci
# ==============================================

PCNAME=$(hostname)
USUARIO=$(whoami)
FECHA=$(date "+%d/%m/%Y")
HORA=$(date "+%H:%M:%S")
OUTFILE="$(dirname "$0")/Reporte_${PCNAME}.txt"

echo "Generando reporte, aguarde..."
echo ""

# Nota: dmidecode requiere sudo para leer datos completos de BIOS/RAM/Motherboard
# Si no tenes sudo, esas secciones pueden quedar incompletas.

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
CPU_MODELO=$(lscpu | grep "Model name" | sed 's/Model name[[:space:]]*:[[:space:]]*//')
CPU_NUCLEOS=$(lscpu | grep "^Core(s) per socket" | awk -F: '{print $2}' | tr -d ' ')
CPU_LOGICOS=$(lscpu | grep "^CPU(s):" | awk -F: '{print $2}' | tr -d ' ')
CPU_MHZ=$(lscpu | grep "CPU max MHz\|CPU MHz" | head -1 | awk -F: '{print $2}' | tr -d ' ' | cut -d'.' -f1)

echo "Modelo    : ${CPU_MODELO:-No detectado}"
echo "Nucleos   : ${CPU_NUCLEOS:-No detectado}"
echo "Logicos   : ${CPU_LOGICOS:-No detectado}"
echo "Velocidad : ${CPU_MHZ:-No detectado} MHz"
echo ""

# ============================================================
#  MEMORIA RAM
# ============================================================
echo "[MEMORIA RAM]"

# Tipo DDR (requiere sudo + dmidecode)
TIPO_RAM=$(sudo dmidecode -t memory 2>/dev/null | grep -m1 "Type:" | grep -v "Error" | awk '{print $2}')
echo "Tipo      : ${TIPO_RAM:-Desconocido (requiere sudo)}"

# Velocidad
RAM_SPEED=$(sudo dmidecode -t memory 2>/dev/null | grep -m1 "Speed:" | grep -v "Unknown" | awk '{print $2, $3}')
echo "Velocidad : ${RAM_SPEED:-No detectada}"

# Total GB
RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
if [[ -n "$RAM_KB" ]]; then
    RAM_GB=$(awk "BEGIN {printf \"%.1f\", $RAM_KB/1048576}")
    echo "Total     : ${RAM_GB} GB"
else
    echo "Total     : No detectado"
fi

# Slots en uso
SLOTS=$(sudo dmidecode -t memory 2>/dev/null | grep -c "Size:.*MB\|Size:.*GB" 2>/dev/null || echo "0")
echo "Slots en uso: ${SLOTS}"
echo ""

# ============================================================
#  DISCO
# ============================================================
echo "[DISCO]"

# Primer disco detectado
DISCO=$(lsblk -dno NAME,MODEL,SIZE,ROTA,TRAN 2>/dev/null | grep -v "loop\|sr" | head -1)
DISCO_DEV=$(echo "$DISCO" | awk '{print $1}')
DISCO_MODELO=$(echo "$DISCO" | awk '{$1=$NF=""; print}' | xargs)
DISCO_SIZE=$(lsblk -dno SIZE /dev/${DISCO_DEV} 2>/dev/null)
DISCO_ROTA=$(lsblk -dno ROTA /dev/${DISCO_DEV} 2>/dev/null)
DISCO_TRAN=$(lsblk -dno TRAN /dev/${DISCO_DEV} 2>/dev/null | tr '[:lower:]' '[:upper:]')

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
MB_FABRICANTE=$(sudo dmidecode -t baseboard 2>/dev/null | grep -m1 "Manufacturer:" | awk -F: '{print $2}' | xargs)
MB_MODELO=$(sudo dmidecode -t baseboard 2>/dev/null | grep -m1 "Product Name:" | awk -F: '{print $2}' | xargs)
echo "Fabricante: ${MB_FABRICANTE:-No detectado (requiere sudo)}"
echo "Modelo    : ${MB_MODELO:-No detectado (requiere sudo)}"
echo ""

# ============================================================
#  BIOS
# ============================================================
echo "[BIOS]"
BIOS_FAB=$(sudo dmidecode -t bios 2>/dev/null | grep -m1 "Vendor:" | awk -F: '{print $2}' | xargs)
BIOS_VER=$(sudo dmidecode -t bios 2>/dev/null | grep -m1 "Version:" | awk -F: '{print $2}' | xargs)
echo "Fabricante: ${BIOS_FAB:-No detectado (requiere sudo)}"
echo "Version   : ${BIOS_VER:-No detectado (requiere sudo)}"
echo ""

# ============================================================
#  VIDEO
# ============================================================
echo "[VIDEO]"
# GPU(s) via lspci
GPU=$(lspci 2>/dev/null | grep -iE "VGA|3D|Display" | sed 's/.*: //')
if [[ -n "$GPU" ]]; then
    while IFS= read -r linea; do
        echo "Modelo    : $linea"
    done <<< "$GPU"
else
    echo "Modelo    : No detectado"
fi

# VRAM (solo NVIDIA via nvidia-smi, si esta instalado)
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
