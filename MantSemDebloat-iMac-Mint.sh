#!/bin/bash
# ======================================================
# MantSemDebloat-iMac-Mint.sh - ChatGPT version 4
# Versión Interruptor API: ABC/TuPcVeloz - 17/08/2026
# Un solo script para ambos modos.
# ======================================================

# ================= CONFIGURACIÓN =======================
MODO_CURSO=true      # true = ABC PC | false = TuPcVeloz

USUARIO=$(whoami)
LOG="/home/$USUARIO/Documentos/Automatico/mantenimiento-$USUARIO.log"

mkdir -p "$(dirname "$LOG")"

# Si no somos root, relanzar con sudo.
# Si sudoers está configurado, no pedirá contraseña.
if [ "$EUID" -ne 0 ]; then
    exec sudo "$0" "$@"
fi

# Guardar salida en pantalla y log
exec > >(tee -a "$LOG") 2>&1

echo ""
echo "======================================================"
echo "=== INICIO MANTENIMIENTO: $(date '+%d/%m/%Y %H:%M:%S') ==="
echo "=== Usuario detectado: $USUARIO ==="
echo "=== Hostname: $(hostname) ==="
echo "=== Modo: $([ "$MODO_CURSO" = true ] && echo 'ABC PC' || echo 'TuPcVeloz') ==="
echo "======================================================"

# ======================================================
# API y Telegram (solo TuPcVeloz)
# ======================================================

if [ "$MODO_CURSO" = false ]; then

    if ! command -v jq >/dev/null 2>&1; then
        echo "--- Instalando jq ---"
        apt update
        apt install -y jq
    fi

    API="http://192.168.1.62:8000/estado?cliente=$(hostname)"
    RESPUESTA=$(curl -s "$API")

    ACTIVO=$(echo "$RESPUESTA" | jq -r '.activo')

    if [ "$ACTIVO" != "true" ]; then
        echo "Servicio inactivo o vencido. Abortando."
        exit 1
    fi

    TOKEN=$(echo "$RESPUESTA" | jq -r '.telegram_token')
    CHATID=$(echo "$RESPUESTA" | jq -r '.telegram_chat_id')

else

    echo "--- Modo Curso: API y Telegram desactivados ---"

fi

# ======================================================
# 1. Avisos
# ======================================================

echo "--- [1] Bloqueando avisos molestos ---"

gsettings set org.x.editor.plugins.spell check-at-startup false 2>/dev/null
gsettings set com.linuxmint.updates.settings show-tray-icon false 2>/dev/null
gsettings set com.linuxmint.updates.settings auto-update-enabled false 2>/dev/null

# ======================================================
# 2. Debloat
# ======================================================

echo "--- [2] Limpiando apps innecesarias ---"

PAQUETES="thunderbird hexchat transmission-common transmission-gtk
gnome-notes gnome-calendar simple-scan drawing
pix celluloid hyphen-en-us libreoffice-math libreoffice-draw"

for PKG in $PAQUETES; do
    if dpkg -l "$PKG" 2>/dev/null | grep -q "^ii"; then
        apt purge -y "$PKG"
        echo "[OK] Purgado: $PKG"
    else
        echo "[--] Ya no existe: $PKG"
    fi
done

# ======================================================
# 3. NumLock
# ======================================================

echo "--- [3] Activando teclado numérico ---"

apt install -y numlockx >/dev/null 2>&1
numlockx on

# ======================================================
# 4. Actualización
# ======================================================

echo "--- [4] Actualizando sistema ---"

apt update
apt upgrade -y

# ======================================================
# 5. Limpieza
# ======================================================

echo "--- [5] Limpiando sistema y temporales ---"

apt autoremove -y
apt autoclean
rm -rf /tmp/*

# ======================================================
# 6. Flatpak
# ======================================================

echo "--- [6] Actualizando Flatpak ---"

flatpak update -y
flatpak uninstall --unused -y

# ======================================================
# 7. Caché
# ======================================================

echo "--- [7] Limpiando caché de miniaturas ---"

rm -rf ~/.cache/thumbnails/*

# ======================================================
# 8. Pantalla MATE
# ======================================================

echo "--- [8] Configurando tiempos de pantalla ---"

gsettings set org.mate.screensaver idle-activation-enabled false 2>/dev/null
gsettings set org.mate.power-manager sleep-display-ac 3600 2>/dev/null

# ======================================================
# 9. RTC WakeAlarm
# ======================================================

echo "--- [9] Programando alarma RTC para el próximo jueves 07:30 ---"

if [ -w /sys/class/rtc/rtc0/wakealarm ]; then
    echo 0 > /sys/class/rtc/rtc0/wakealarm
    TARGET=$(date -d "next thursday 07:30" +%s)
    echo "$TARGET" > /sys/class/rtc/rtc0/wakealarm
    echo "Alarma programada para: $(date -d @$TARGET '+%A %d/%m/%Y %H:%M')"
else
    echo "WakeAlarm no disponible en este equipo."
fi

echo ""
echo "--- [OK] Sistema optimizado y notificaciones silenciadas ---"

# ======================================================
# Telegram (solo TuPcVeloz)
# ======================================================

if [ "$MODO_CURSO" = false ]; then

    curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
        -d chat_id="$CHATID" \
        -d text="[$(hostname)] Mantenimiento OK - $(date '+%d/%m/%Y %H:%M')" >/dev/null

fi

echo ""
echo "======================================================"
echo "=== FIN MANTENIMIENTO: $(date '+%d/%m/%Y %H:%M:%S') ==="
echo "======================================================"

echo ""
echo "La PC se reiniciará en:"

for i in {5..1}; do
    echo "$i..."
    sleep 1
done

reboot