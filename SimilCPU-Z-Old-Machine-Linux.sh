#!/usr/bin/env bash
# ==============================================
#   REPORTE DE HARDWARE - TALLER (Linux Mint)
#   Equivalente al SimilCPU-Z-Old-Machine.bat
#   Compatible: DDR2 / DDR3 / DDR4 / DDR5 + Dual Channel
#   Requiere: dmidecode (sudo), lscpu, lspci, lm-sensors
# ==============================================
# version 4 ChatGPT 01/09/2026

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

CPU_LOGICOS=$(lscpu | grep -E "^CPU\(s\):" | awk -F: '{print $2}' | xargs)
CPU_NUCLEOS=$(lscpu | grep -E "^Core\(s\) per socket|^Núcleo\(s\) por zócalo" | awk -F: '{print $2}' | xargs)

if [[ -z "$CPU_NUCLEOS" || "$CPU_NUCLEOS" == "No detectado" ]]; then
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
    TEMP_INFO=$(sensors | grep -E "Core|Core 0|Core 1" | awk -F: '{print $1 ":" $2}' | cut -d'(' -f1 | xargs)
    echo "Actual    : ${TEMP_INFO:-No se pudo leer la temperatura}"
else
    echo "Actual    : No disponible (Instala lm-sensors)"
fi
echo ""

# ============================================================
#  MEMORIA RAM  (compatible DDR2 → DDR5 + Dual Channel)
# ============================================================
echo "[MEMORIA RAM]"

# --- Tipo de RAM ---
TIPO_RAM=$(echo "1234" | sudo -S dmidecode -t memory 2>/dev/null | grep -E "^\s*Type:|^\s*Tipo:" | grep -v -iE "Error|Unknown|Other|Flash|ROM" | head -1 | awk -F: '{print $2}' | xargs)

# Si dmidecode devuelve genérico (muy común en placas DDR2 viejas)
if [[ -z "$TIPO_RAM" || "$TIPO_RAM" == "Unknown" || "$TIPO_RAM" == "DIMM" || "$TIPO_RAM" == "DIMM SDRAM" || "$TIPO_RAM" == "SDRAM" ]]; then
    FORM_FACTOR=$(echo "1234" | sudo -S dmidecode -t memory 2>/dev/null | grep -m1 -E "Form Factor:|Factor de forma:" | awk -F: '{print $2}' | xargs)
    if [[ "$FORM_FACTOR" == *"DIMM"* ]]; then
        TIPO_RAM="DDR2 (DIMM)"
    else
        TIPO_RAM="Desconocido"
    fi
fi
echo "Tipo      : ${TIPO_RAM}"

# --- Velocidad ---
RAM_SPEED=$(echo "1234" | sudo -S dmidecode -t memory 2>/dev/null | grep -iE "Configured Memory Speed:|Configured Clock Speed:|Velocidad configurada:" | head -1 | awk -F: '{print $2}' | xargs)

if [[ -z "$RAM_SPEED" || "$RAM_SPEED" == "Unknown" || "$RAM_SPEED" == "0 MHz" ]]; then
    RAM_SPEED=$(echo "1234" | sudo -S dmidecode -t memory 2>/dev/null | grep -iE "^\s*Speed:|^\s*Velocidad:" | grep -v -iE "Unknown|Desconocida|Configured|0 MHz" | head -1 | awk -F: '{print $2}' | xargs)
fi

if [[ -z "$RAM_SPEED" || "$RAM_SPEED" == "Unknown" ]]; then
    if [[ "$TIPO_RAM" == *"DDR2"* || "$TIPO_RAM" == *"DIMM"* ]]; then
        RAM_SPEED="667/800 MHz (tipico DDR2 - BIOS limitada)"
    else
        RAM_SPEED="No detectada"
    fi
fi
echo "Velocidad : ${RAM_SPEED}"

# --- Total ---
RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
if [[ -n "$RAM_KB" ]]; then
    RAM_GB=$(awk "BEGIN {printf \"%.1f\", $RAM_KB/1048576}")
    echo "Total     : ${RAM_GB} GB"
else
    echo "Total     : No detectado"
fi

# ---Slots en uso ---
SLOTS=$(echo "1234" | sudo -S dmidecode -t memory 2>/dev/null | grep -E "Size:|Tamaño:" | grep -v -iE "No Module|No module|Volátil|Empty|Vacío|0 MB|0GB|Unknown" | grep -c -E "[0-9]+ (MB|GB)" || echo "0")

if [[ "$SLOTS" -eq 0 ]]; then
    SLOTS="No detectado"
elif [[ "$SLOTS" -gt 4 && ("$TIPO_RAM" == *"DDR2"* || "$TIPO_RAM" == *"DIMM"*) ]]; then
    SLOTS="$SLOTS (verificar fisico)"
fi
echo "Slots en uso: ${SLOTS}"

# --- Dual Channel / Single Channel ---
MODULOS=$(echo "1234" | sudo -S dmidecode -t memory 2>/dev/null | grep -E "Size:|Tamaño:" | grep -v -iE "No Module|No module|Empty|Vacío|0 MB|0GB|Unknown")
CANT_MODULOS=$(echo "$MODULOS" | grep -c -E "[0-9]+ (MB|GB)" || echo "0")

if [[ "$CANT_MODULOS" -eq 0 ]]; then
    CANAL="No detectado"
elif [[ "$CANT_MODULOS" -eq 1 ]]; then
    CANAL="Single Channel (1 modulo)"
elif [[ "$CANT_MODULOS" -eq 2 ]]; then
    TAM1=$(echo "$MODULOS" | head -1 | grep -oE "[0-9]+ (MB|GB)")
    TAM2=$(echo "$MODULOS" | tail -1 | grep -oE "[0-9]+ (MB|GB)")
    if [[ "$TAM1" == "$TAM2" ]]; then
        CANAL="Dual Channel (2 modulos iguales)"
    else
        CANAL="Single Channel (2 modulos de distinto tamaño)"
    fi
elif [[ "$CANT_MODULOS" -ge 3 ]]; then
    CANAL="Multi Channel posible ($CANT_MODULOS modulos)"
else
    CANAL="No detectado"
fi
echo "Canal     : ${CANAL}"
echo ""

# ============================================================
#  DISCO
# ============================================================
echo "[DISCO]"

DISCOS_ENCONTRADOS=0
for candidate in $(lsblk -dno NAME 2>/dev/null | grep -E '^(sd|hd|vd|nvme)'); do
    DISCO_DEV="$candidate"
    DISCO_MODELO=$(lsblk -dno MODEL /dev/$DISCO_DEV 2>/dev/null | xargs)
    DISCO_SIZE=$(lsblk -dno SIZE /dev/$DISCO_DEV 2>/dev/null | xargs)
    DISCO_ROTA=$(lsblk -dno ROTA /dev/$DISCO_DEV 2>/dev/null | xargs)
    DISCO_TRAN=$(lsblk -dno TRAN /dev/$DISCO_DEV 2>/dev/null | tr '[:lower:]' '[:upper:]' | xargs)

    if [[ -z "$DISCO_MODELO" ]]; then
        DISCO_MODELO=$(cat /sys/block/$DISCO_DEV/device/model 2>/dev/null | xargs)
    fi

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
    DISCOS_ENCONTRADOS=$((DISCOS_ENCONTRADOS + 1))
done

if [[ $DISCOS_ENCONTRADOS -eq 0 ]]; then
    echo "Modelo    : No detectado"
    echo "Interfaz  : No detectada"
    echo "Tamanio   : No detectado"
    echo "Tipo      : No detectado"
    echo ""
fi

# ============================================================
#  MOTHERBOARD
# ============================================================
echo "[MOTHERBOARD]"
MB_FABRICANTE=$(echo "1234" | sudo -S dmidecode -t baseboard 2>/dev/null | grep -m1 -E "Manufacturer:|Fabricante:" | awk -F: '{print $2}' | xargs)
MB_MODELO=$(echo "1234" | sudo -S dmidecode -t baseboard 2>/dev/null | grep -m1 -E "Product Name:|Nombre del producto:" | awk -F: '{print $2}' | xargs)

MB_SOCKET=$(echo "1234" | sudo -S dmidecode -t processor 2>/dev/null | grep -m1 -iE "Upgrade:|Socket Designation:|Designación de zócalo:" | awk -F: '{print $2}' | xargs)
if [[ -z "$MB_SOCKET" || "$MB_SOCKET" == "Unknown" ]]; then
    MB_SOCKET=$(echo "1234" | sudo -S dmidecode -t 4 2>/dev/null | grep -m1 -iE "Socket Designation|Upgrade" | awk -F: '{print $2}' | xargs)
fi

echo "Fabricante: ${MB_FABRICANTE:-No detectado}"
echo "Modelo    : ${MB_MODELO:-No detectado}"
echo "Socket    : ${MB_SOCKET:-No detectado}"
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
