#!/bin/bash
# --- MantSemDebloat-Universal.sh (Versión Anti-Ansiedad v3 - Universal) ---
# Modificado: 02/07/2026
# Funciona en cualquier PC/usuario sin editar nada (autodetecta USUARIO)

USUARIO=$(whoami)
LOG="/home/$USUARIO/Documentos/Automatico/mantenimiento-$USUARIO.log"

# Crea la carpeta de logs si no existe (evita el error de "No existe el archivo")
mkdir -p "$(dirname "$LOG")"

# Todo lo que el script imprime va al log Y a la pantalla
exec > >(tee -a "$LOG") 2>&1

echo ""
echo "======================================================"
echo "=== INICIO MANTENIMIENTO: $(date '+%d/%m/%Y %H:%M:%S') ==="
echo "=== Usuario detectado: $USUARIO ==="
echo "=== Hostname: $(hostname) ==="
echo "======================================================"

# Verifica que jq este instalado, si no lo instala solo
if ! command -v jq &> /dev/null; then
    echo "--- [0] jq no encontrado, instalando... ---"
    sudo apt install -y jq
fi

# Asegura que el shutdown no pida contraseña (evita que sudo se venza durante el sleep final)
SUDOERS_FILE="/etc/sudoers.d/mantenimiento-shutdown"
if ! sudo test -f "$SUDOERS_FILE"; then
    echo "--- [0] Configurando shutdown sin contraseña para $USUARIO ---"
    echo "$USUARIO ALL=(ALL) NOPASSWD: /sbin/shutdown, /usr/sbin/shutdown" | sudo tee "$SUDOERS_FILE" > /dev/null
    sudo chmod 440 "$SUDOERS_FILE"
    sudo visudo -c -f "$SUDOERS_FILE" > /dev/null 2>&1 || { echo "[ERROR] Sintaxis invalida en $SUDOERS_FILE, borrando por seguridad"; sudo rm -f "$SUDOERS_FILE"; }
fi

# 0. CONSULTA A LA API
API="http://192.168.1.62:8000/estado?cliente=$(hostname)"
RESPUESTA=$(curl -s "$API")

ACTIVO=$(echo "$RESPUESTA" | jq -r '.activo')

if [ "$ACTIVO" != "true" ]; then
    echo "Servicio inactivo o vencido. Abortando."
    exit 1
fi

TOKEN=$(echo "$RESPUESTA" | jq -r '.telegram_token')
CHATID=$(echo "$RESPUESTA" | jq -r '.telegram_chat_id')

# 1. BLOQUEO DE AVISOS
# Elimina el punto naranja y las notificaciones de actualizacion
echo "--- [1] Bloqueando avisos molestos ---"
gsettings set org.x.editor.plugins.spell check-at-startup false 2>/dev/null
gsettings set com.linuxmint.updates.settings show-tray-icon false 2>/dev/null
gsettings set com.linuxmint.updates.settings auto-update-enabled false 2>/dev/null

# 2. DEBLOAT
# Solo purga lo que todavia existe, ignora si ya fue removido
echo "--- [2] Limpiando apps innecesarias ---"
PAQUETES="thunderbird hexchat transmission-common transmission-gtk
gnome-notes gnome-calendar simple-scan drawing
pix celluloid hyphen-en-us libreoffice-math libreoffice-draw"

for PKG in $PAQUETES; do
    if dpkg -l "$PKG" 2>/dev/null | grep -q "^ii"; then
        sudo apt purge -y "$PKG"
        echo "[OK] Purgado: $PKG"
    else
        echo "[--] Ya no existe: $PKG"
    fi
done

# 3. TECLADO NUMERICO
echo "--- [3] Activando teclado numerico ---"
sudo apt install -y numlockx 2>/dev/null
numlockx on

# 4. ACTUALIZACION
echo "--- [4] Actualizando sistema ---"
sudo apt update
sudo apt upgrade -y

# 5. LIMPIEZA
echo "--- [5] Limpiando sistema y temporales ---"
sudo apt autoremove -y
sudo apt autoclean
sudo rm -rf /tmp/*

# 6. FLATPAK
echo "--- [6] Actualizando Flatpak ---"
flatpak update -y
flatpak uninstall --unused -y

# 7. CACHE
echo "--- [7] Limpiando cache de miniaturas ---"
rm -rf ~/.cache/thumbnails/*

# 8. PANTALLA MATE
echo "--- [8] Configurando tiempos de pantalla ---"
gsettings set org.mate.screensaver idle-activation-enabled false 2>/dev/null
gsettings set org.mate.power-manager sleep-display-ac 3600 2>/dev/null

echo ""
echo "--- [OK] Sistema optimizado y notificaciones silenciadas ---"

# 9. PROGRAMAR PROXIMO JUEVES 7:30
echo "--- Programando alarma RTC para el proximo jueves 07:30 ---"
echo 0 | sudo tee /sys/class/rtc/rtc0/wakealarm
TARGET=$(date -d "next thursday 07:30" +%s)
echo $TARGET | sudo tee /sys/class/rtc/rtc0/wakealarm
echo "Alarma programada para: $(date -d @$TARGET '+%A %d/%m/%Y %H:%M')"

echo ""
echo "======================================================"
echo "=== FIN MANTENIMIENTO: $(date '+%d/%m/%Y %H:%M:%S') ==="
echo "======================================================"
echo ""

# 10. REPORTE TELEGRAM
curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
    -d chat_id="$CHATID" \
    -d text="[$(hostname)] Mantenimiento OK - $(date '+%d/%m/%Y %H:%M')" > /dev/null

echo "La PC se apagara en 2 minutos..."
sleep 120
sudo shutdown -h now