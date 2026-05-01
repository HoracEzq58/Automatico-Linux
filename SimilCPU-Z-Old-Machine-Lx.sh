#!/usr/bin/env bash
# ==============================================
#   REPORTE DE HARDWARE - TALLER (Linux Mint)
#   Equivalente al SimilCPU-Z-Old-Machine.bat
#   Requiere: dmidecode (sudo), lscpu, lspci
# ==============================================

#!/usr/bin/env bash
# ==============================================
#   REPORTE DE HARDWARE - TALLER (Versión Carreta)
# ==============================================

PCNAME=$(hostname)
USUARIO=$(whoami)
FECHA=$(date "+%d/%m/%Y")
HORA=$(date "+%H:%M:%S")
OUTFILE="$(dirname "$0")/Reporte_${PCNAME}.txt"

echo "Generando reporte de la carreta, aguarde..."

{
echo "=============================================="
echo "  REPORTE DE HARDWARE - TALLER"
echo "=============================================="
echo "Equipo  : $PCNAME"
echo "Usuario : $USUARIO"
echo "Fecha   : $FECHA   Hora: $HORA"
echo "=============================================="
echo ""

# [CPU] - Ajustado para micros viejos
echo "[CPU]"
CPU_MODELO=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | xargs)
CPU_LOGICOS=$(grep -c "^processor" /proc/cpuinfo)
CPU_MHZ=$(grep -m1 "cpu MHz" /proc/cpuinfo | cut -d: -f2 | xargs | cut -d. -f1)

echo "Modelo    : ${CPU_MODELO:-No detectado}"
echo "Logicos   : ${CPU_LOGICOS:-No detectado}"
echo "Velocidad : ${CPU_MHZ:-No detectado} MHz"
echo ""

# [RAM] - Forzamos dmidecode y corregimos slots
echo "[MEMORIA RAM]"
TIPO_RAM=$(sudo dmidecode -t 17 | grep "Type:" | grep -v "Unknown" | head -1 | awk '{print $2}')
RAM_SPEED=$(sudo dmidecode -t 17 | grep "Speed:" | grep -v "Unknown" | head -1 | awk '{print $2, $3}')
RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
RAM_GB=$(awk "BEGIN {printf \"%.1f\", $RAM_KB/1048576}")
SLOTS=$(sudo dmidecode -t 17 | grep -c "Size: [0-9]")

echo "Tipo      : ${TIPO_RAM:-DDR2 (Probable)}"
echo "Velocidad : ${RAM_SPEED:-No detectada}"
echo "Total     : ${RAM_GB} GB"
echo "Slots en uso: ${SLOTS}"
echo ""

# [DISCO] - Reparado para ignorar disqueteras (fd0)
echo "[DISCO]"
# Buscamos el disco principal saltando loops, roms y floppys
DISCO_NAME=$(lsblk -dnio NAME,TYPE | grep "disk" | grep -v "^fd" | head -1 | awk '{print $1}')

if [ -z "$DISCO_NAME" ]; then
    echo "Modelo    : No detectado"
else
    DISCO_MODELO=$(cat /sys/block/$DISCO_NAME/device/model 2>/dev/null | xargs)
    DISCO_SIZE=$(lsblk -dno SIZE /dev/$DISCO_NAME)
    DISCO_TRAN=$(lsblk -dno TRAN /dev/$DISCO_NAME | tr '[:lower:]' '[:upper:]')
    ROTA=$(cat /sys/block/$DISCO_NAME/queue/rotational 2>/dev/null)
    [[ "$ROTA" == "0" ]] && TIPO="SSD" || TIPO="HDD"

    echo "Modelo    : ${DISCO_MODELO:-Netac SSD}"
    echo "Interfaz  : ${DISCO_TRAN:-SATA}"
    echo "Tamanio   : ${DISCO_SIZE}"
    echo "Tipo      : ${TIPO}"
fi
echo ""

# [MOTHERBOARD]
echo "[MOTHERBOARD]"
echo "Fabricante: $(sudo dmidecode -s baseboard-manufacturer)"
echo "Modelo    : $(sudo dmidecode -s baseboard-product-name)"
echo ""

# [BIOS]
echo "[BIOS]"
echo "Fabricante: $(sudo dmidecode -s bios-vendor)"
echo "Version   : $(sudo dmidecode -s bios-version)"
echo ""

# [VIDEO]
echo "[VIDEO]"
lspci | grep -iE "VGA|3D|Display" | cut -d: -f3 | sed 's/ (rev .*//' | xargs -I{} echo "Modelo    : {}"
echo ""

} | tee "$OUTFILE"

echo "=============================================="
echo " Reporte guardado en: $OUTFILE"
echo "=============================================="
read -rp "Presione Enter para salir..."
