#!/bin/bash
# ==========================================================================================
# InstallAppsAutomatico-Linux.sh - Versión 5 Claude 12/08/2026 (auto-recepción de archivos)
# Curso ABC PC ICO - Casa de Oración Flores
# Linux Mint MATE (DDR2 / DDR3)
# ==========================================================================================

# --------------------------------------------------------------------------
# INTERRUPTOR: poné "false" si esta PC no va a formar parte de la mini red
# Tailscale del taller (te salteás instalación de Tailscale, el operador,
# el ícono systray, y el submenú "Enviar por Tailscale" en Thunar).
# --------------------------------------------------------------------------
INSTALAR_TAILSCALE=true

echo "======================================================"
echo "  InstallApps Automático - Versión 2"
echo "  Pedirá la contraseña UNA sola vez"
echo "======================================================"
echo ""

# Pedir contraseña una sola vez
read -s -p "Ingresá la contraseña del usuario (sudo): " PASSWORD
echo ""
echo "Contraseña guardada. El resto del proceso será automático..."
echo ""

# Función para ejecutar comandos con sudo usando la contraseña
run_sudo() {
  echo "$PASSWORD" | sudo -S "$@"
}

# Verificar que la contraseña sea correcta
if ! echo "$PASSWORD" | sudo -S -v 2>/dev/null; then
  echo "ERROR: Contraseña incorrecta. Abortando."
  exit 1
fi

# --------------------------------------------------------------------------
# Keepalive de sudo: refresca la credencial en segundo plano cada 60s.
# A partir de acá, run_sudo llama a sudo DIRECTO (sin -S ni pipe propio),
# así nunca compite por el stdin de comandos como "contenido | run_sudo tee archivo".
# Esto es lo que corrompía coretemp / sudoers.d / tailscale-systray.desktop
# con la contraseña en vez del contenido real.
# --------------------------------------------------------------------------
( while true; do echo "$PASSWORD" | sudo -S -v 2>/dev/null; sleep 60; done ) &
SUDO_KEEPALIVE_PID=$!
trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null' EXIT

run_sudo() {
  sudo "$@"
}

echo "--- Iniciando el Tune-up de la Pc ---"

# 1. Limpieza inicial
run_sudo apt purge -y libreoffice* firefox
run_sudo apt autoremove -y

# 2. Actualizar sistema + aceptar EULA de fuentes Microsoft
export DEBIAN_FRONTEND=noninteractive
echo "$PASSWORD" | sudo -S debconf-set-selections <<EOF
ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true
EOF

run_sudo rm -f /etc/apt/preferences.d/nosnap.pref
run_sudo apt update
run_sudo apt upgrade -y
run_sudo apt install -y snapd ttf-mscorefonts-installer htop inxi stacer gparted variety simplescreenrecorder sox libsox-fmt-all smartmontools thunar

# 3. Tailscale (método robusto corregido)
if [ "$INSTALAR_TAILSCALE" = true ]; then
  echo "--- Instalando Tailscale ---"
  source /etc/os-release
  CODENAME="${UBUNTU_CODENAME:-jammy}"

  curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${CODENAME}.noarmor.gpg" | sudo -S tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
  echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/ubuntu ${CODENAME} main" | sudo -S tee /etc/apt/sources.list.d/tailscale.list >/dev/null

  run_sudo apt update && run_sudo apt install -y tailscale
else
  echo "--- Tailscale: SALTEADO (INSTALAR_TAILSCALE=false) ---"
fi


# 4. Juegos
run_sudo apt install -y supertuxkart extremetuxracer

# 5. Flatpak (como usuario)
run_sudo apt install -y flatpak
flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo

flatpak install -y --user flathub \
  org.chromium.Chromium \
  io.github.mimbrero.WhatsAppDesktop \
  us.zoom.Zoom \
  org.videolan.VLC \
  com.rustdesk.RustDesk \
  org.localsend.localsend_app

# Corregir permisos de Flatpak
mkdir -p ~/.var
run_sudo chown -R $USER:$USER ~/.var
chmod -R u+rwX ~/.var

# 6. Alias Chromium
if [ ! -f ~/.bashrc_backup ]; then cp ~/.bashrc ~/.bashrc_backup; fi
grep -q "alias chromium=" ~/.bashrc || echo "alias chromium='flatpak run org.chromium.Chromium --password-store=basic'" >> ~/.bashrc

# 7. WPS Office
echo "--- Instalando WPS Office ---"
run_sudo snap install wps-office-multilang
run_sudo snap connect wps-office-multilang:cups-control
run_sudo snap connect wps-office-multilang:alsa
run_sudo snap connect wps-office-multilang:pulseaudio
run_sudo snap connect wps-office-multilang:home
run_sudo snap connect wps-office-multilang:desktop-legacy

# Configurar idioma español Argentina
mkdir -p ~/.config/Kingsoft
mkdir -p ~/.local/share/Kingsoft/office6/dicts
cat <<EOF > ~/.config/Kingsoft/WPSOffice.conf
[General]
languages=es_AR
EOF
echo "es_AR" > ~/.local/share/Kingsoft/office6/dicts/default.dic

mkdir -p ~/snap/wps-office-multilang/current/.config/Kingsoft
cp ~/.config/Kingsoft/WPSOffice.conf ~/snap/wps-office-multilang/current/.config/Kingsoft/ 2>/dev/null || true
run_sudo chown -R $USER:$USER ~/snap/wps-office-multilang

# 8. Crear iconos en el Escritorio (solo apps populares)
echo "--- Creando iconos en el Escritorio ---"

DESKTOP_DIR="$HOME/Escritorio"
mkdir -p "$DESKTOP_DIR"

# Flatpak
FLATPAK_APPS=(
  "org.videolan.VLC"
  "org.localsend.localsend_app"
  "com.rustdesk.RustDesk"
  "us.zoom.Zoom"
  "io.github.mimbrero.WhatsAppDesktop"
  "org.chromium.Chromium"
)

for app in "${FLATPAK_APPS[@]}"; do
  DESKTOP_FILE=$(find ~/.local/share/flatpak/exports/share/applications /var/lib/flatpak/exports/share/applications -name "${app}.desktop" 2>/dev/null | head -n 1)
  if [ -n "$DESKTOP_FILE" ]; then
    cp "$DESKTOP_FILE" "$DESKTOP_DIR/"
    chmod +x "$DESKTOP_DIR/${app}.desktop"
    gio set "$DESKTOP_DIR/${app}.desktop" metadata::trusted true 2>/dev/null || true

    # --- ESPECIAL para Chromium: evitar prompt de keyring ---
    if [ "$app" = "org.chromium.Chromium" ]; then
      sed -i 's|Exec=flatpak run org.chromium.Chromium|Exec=flatpak run org.chromium.Chromium --password-store=basic|g' "$DESKTOP_DIR/${app}.desktop"
      sed -i 's|Exec=/usr/bin/flatpak run --branch=stable --arch=x86_64 --command=/app/bin/chromium --file-forwarding org.chromium.Chromium|Exec=/usr/bin/flatpak run --branch=stable --arch=x86_64 --command=/app/bin/chromium --file-forwarding org.chromium.Chromium --password-store=basic|g' "$DESKTOP_DIR/${app}.desktop"
      # También dejar una copia en ~/.local/share/applications para el menú
      mkdir -p ~/.local/share/applications
      cp "$DESKTOP_DIR/${app}.desktop" ~/.local/share/applications/
    fi

    echo "✓ Icono creado: $app"
  fi
done

# SuperTuxKart
if [ -f /usr/share/applications/supertuxkart.desktop ]; then
  cp /usr/share/applications/supertuxkart.desktop "$DESKTOP_DIR/"
  chmod +x "$DESKTOP_DIR/supertuxkart.desktop"
  gio set "$DESKTOP_DIR/supertuxkart.desktop" metadata::trusted true 2>/dev/null || true
  echo "✓ Icono creado: SuperTuxKart"
fi

# SimpleScreenRecorder
if [ -f /usr/share/applications/simplescreenrecorder.desktop ]; then
  cp /usr/share/applications/simplescreenrecorder.desktop "$DESKTOP_DIR/"
  chmod +x "$DESKTOP_DIR/simplescreenrecorder.desktop"
  gio set "$DESKTOP_DIR/simplescreenrecorder.desktop" metadata::trusted true 2>/dev/null || true
  echo "✓ Icono creado: SimpleScreenRecorder"
fi

# WPS Office
WPS_DESKTOP=$(find /var/lib/snapd/desktop/applications -name "*wps-office*.desktop" 2>/dev/null | head -n 1)
if [ -n "$WPS_DESKTOP" ]; then
  cp "$WPS_DESKTOP" "$DESKTOP_DIR/wps-office.desktop"
  chmod +x "$DESKTOP_DIR/wps-office.desktop"
  gio set "$DESKTOP_DIR/wps-office.desktop" metadata::trusted true 2>/dev/null || true
  echo "✓ Icono creado: WPS Office"
fi

# 9. Sonido de Inicio MATE y Configuración de Pantalla
echo "--- Configurando Sonido de Inicio y Desactivando Bloqueo ---"
mkdir -p ~/.config/autostart
cat << 'EOF' > ~/.config/autostart/login-sound.desktop
[Desktop Entry]
Type=Application
Name=Sonido de Inicio
Comment=Reproduce el sonido al iniciar sesion con play y delay
Exec=bash -c "sleep 5 && play -q /usr/share/sounds/LinuxMint/stereo/desktop-login.ogg"
X-GNOME-Autostart-enabled=true
EOF

# Desactivar bloqueo de pantalla por inactividad de MATE para los alumnos
gsettings set org.mate.screensaver lock-enabled false
# =================================================================
# SECCIÓN 10: Configuración Automatizada de CoreTemp y Tailscale
# =================================================================
echo "--- Configurando Comando coretemp y Permisos de Red ---"

# 1. Crear el script coretemp directamente en la carpeta del sistema
run_sudo tee /usr/local/bin/coretemp << 'EOF'
#!/bin/bash
VERDE='\033[0;32m'
AZUL='\033[0;34m'
AMARILLO='\033[1;33m'
RESET='\033[0m'

echo -e "${AZUL}=========================================${RESET}"
echo -e "${AZUL}     ESTADO DE TEMPERATURAS - TALLER     ${RESET}"
echo -e "${AZUL}=========================================${RESET}"

echo -e "${VERDE}Temperaturas del CPU:${RESET}"
if sensors 2>/dev/null | grep -q 'Core 0'; then
    TEMP_CORE0=$(sensors 2>/dev/null | grep 'Core 0' | awk '{print $3}')
    TEMP_CORE1=$(sensors 2>/dev/null | grep 'Core 1' | awk '{print $3}')
    echo -e "  - Core 0: $TEMP_CORE0"
    echo -e "  - Core 1: $TEMP_CORE1"
else
    TEMP_CPU=$(sensors 2>/dev/null | grep -i -E 'Tctl|Package id 0|Tdie|temp1' | head -n 1 | awk '{print $2}')
    [ -z "$TEMP_CPU" ] && TEMP_CPU="No detectada"
    echo -e "  - CPU General: $TEMP_CPU"
fi

TEMP_GPU=$(sensors 2>/dev/null | grep -A 2 'radeon-pci' | grep 'temp1' | awk '{print $2}')
if [ ! -z "$TEMP_GPU" ]; then
    echo -e "${VERDE}GPU (Radeon Video):${RESET}     $TEMP_GPU"
fi

echo -e "${AMARILLO}Resto de discos HDD/SATA:${RESET}"
for disco in /dev/sd[a-z]; do
    if [ -b "$disco" ]; then
        NOMBRE=$(basename "$disco")
        MODELO=$(lsblk -d -o MODEL "$disco" | tail -n 1 | xargs)
        if [ "$MODELO" == "Multi-Card" ] || [ -z "$MODELO" ]; then
            continue
        fi
        TEMP_HDD=$(sudo smartctl -A "$disco" 2>/dev/null | awk '$1 == 194 || $1 == 190 {print $10}')
        if [ -z "$TEMP_HDD" ]; then
            TEMP_HDD=$(sudo smartctl -a "$disco" 2>/dev/null | grep -i 'Temperature' | awk '{print $4}' | head -n 1)
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
EOF

# 2. Sanitizado de saltos de línea por seguridad
run_sudo sed -i 's/\r$//' /usr/local/bin/coretemp

# 3. Permisos de ejecución de coretemp
run_sudo chmod +x /usr/local/bin/coretemp

# 4. Regla sudoers automática para la lectura de discos de los alumnos
SUDOERS_TMP=$(mktemp)
echo "$USER ALL=(ALL) NOPASSWD: /usr/sbin/smartctl" > "$SUDOERS_TMP"
if run_sudo visudo -cf "$SUDOERS_TMP" >/dev/null 2>&1; then
  run_sudo cp "$SUDOERS_TMP" /etc/sudoers.d/smartctl-coretemp
  run_sudo chmod 0440 /etc/sudoers.d/smartctl-coretemp
  echo "    ✓ Regla sudoers de smartctl instalada y validada"
else
  echo "    ✗ ERROR: la regla sudoers no pasó la validación de visudo, NO se instala"
fi
rm -f "$SUDOERS_TMP"

if [ "$INSTALAR_TAILSCALE" = true ]; then
  # 5. Autorizar al usuario actual a recibir archivos de Tailscale sin sudo
  run_sudo tailscale set --operator=$USER 2>/dev/null

  # 6. Forzar la activación del icono en la barra de tareas al iniciar el escritorio
  mkdir -p /etc/skel/.config/autostart
  echo -e "[Desktop Entry]\nType=Application\nExec=tailscale systray\nHidden=false\nNoDisplay=false\nX-GNOME-Autostart-enabled=true\nName=Tailscale Systray" | run_sudo tee /etc/skel/.config/autostart/tailscale-systray.desktop >/dev/null
  mkdir -p ~/.config/autostart
  cp /etc/skel/.config/autostart/tailscale-systray.desktop ~/.config/autostart/ 2>/dev/null
else
  echo "    (operador y systray de Tailscale salteados: INSTALAR_TAILSCALE=false)"
fi

# 7. Configurar Thunar como explorador preferido del sistema
run_sudo xdg-mime default thunar.desktop inode/directory application/x-gnome-saved-search 2>/dev/null

# ================================================================================================
# 10.8. INYECTAR BOTONERA DE TAILSCALE EN EL MENU CONTEXTUAL DE THUNAR - ChatGPT 10/08/2026 22 hs
# ================================================================================================

if [ "$INSTALAR_TAILSCALE" = true ]; then
echo
echo ">>> Configurando envío de archivos por Tailscale en Thunar (modo dinámico)..."

# --------------------------------------------------------------------------
# Mapa de las 5 PCs del taller: "hostname-tailscale:Nombre a mostrar"
# El hostname-tailscale es el nombre MagicDNS (el que usás en `tailscale file cp X:`)
# Ajustá esta lista si algún hostname de Tailscale no coincide con el de acá.
# --------------------------------------------------------------------------
MAQUINAS=(
  # "abcpc01-XXXXX:ABCPC01"           # <-- PENDIENTE: correr `tailscale status` en abcpc01 y completar su nombre real
  "abcpc02-desktop:ABCPC02"
  "abcpc03-desktop:ABCPC03 (Windows)"
  "abcpc04-g41m-es2l:ABCPC04"
  "abcpc05-inspiron-1545:ABCPC05 (Dell)"
)

MI_HOSTNAME=$(hostname | tr 'A-Z' 'a-z')
echo "    Hostname detectado en esta PC (normalizado): $MI_HOSTNAME"

# Armar el XML dinámicamente, salteando la propia máquina
UCA_TMP=$(mktemp)
{
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo '<actions>'
  for entry in "${MAQUINAS[@]}"; do
    TS_HOST="${entry%%:*}"
    NOMBRE="${entry##*:}"

    # Saltear la propia PC (comparando por el hostname corto, sin -desktop etc.)
    if [[ "$TS_HOST" == "$MI_HOSTNAME"* ]] || [[ "$MI_HOSTNAME" == "$TS_HOST"* ]]; then
      continue
    fi

    UID_SAFE=$(echo "$TS_HOST" | tr -c 'a-zA-Z0-9' '-')
    cat <<EOF
<action>
    <icon>network-vpn</icon>
    <name>${NOMBRE}</name>
    <submenu>Enviar por Tailscale</submenu>
    <unique-id>1000-${UID_SAFE}</unique-id>
    <command>tailscale file cp %f ${TS_HOST}:</command>
    <description>Enviar archivo a ${NOMBRE}</description>
    <range>*</range>
    <patterns>*</patterns>
    <directories/>
    <audio-files/>
    <image-files/>
    <other-files/>
    <text-files/>
    <video-files/>
</action>
EOF
  done
  echo '</actions>'
} > "$UCA_TMP"

# Validar que el XML haya quedado bien formado antes de instalarlo
if command -v xmllint >/dev/null 2>&1; then
  if ! xmllint --noout "$UCA_TMP" 2>/dev/null; then
    echo "    ✗ ERROR: el uca.xml generado quedó mal formado, no se instala."
    cat "$UCA_TMP"
    rm -f "$UCA_TMP"
  fi
fi

if [ -f "$UCA_TMP" ]; then
  # Aplicar la configuración al usuario actual
  mkdir -p ~/.config/Thunar
  cp "$UCA_TMP" ~/.config/Thunar/uca.xml
  rm -f "$UCA_TMP"

  # Asegurar propietario y permisos correctos (por si el HOME quedó tocado por sudo alguna vez)
  run_sudo chown "$USER:$USER" ~/.config/Thunar/uca.xml
  chmod 644 ~/.config/Thunar/uca.xml

  # Guardar también en /etc/skel para que usuarios nuevos lo hereden
  run_sudo mkdir -p /etc/skel/.config/Thunar
  run_sudo cp ~/.config/Thunar/uca.xml /etc/skel/.config/Thunar/uca.xml

  # Recargar Thunar para aplicar los cambios (kill duro, -q a veces no alcanza si quedó como demonio de escritorio)
  thunar -q 2>/dev/null || true
  sleep 1
  pkill -9 -u "$USER" thunar 2>/dev/null || true

  echo "    ✓ Botonera Tailscale configurada en Thunar (excluyendo $MI_HOSTNAME)"

  # --------------------------------------------------------------------------
  # Auto-recepción: sin esto, un archivo enviado por el menú de Thunar queda
  # esperando en la cola interna de Tailscale y NUNCA aparece en Descargas
  # hasta que alguien corre "tailscale file get" a mano. Este watcher lo hace
  # solo, cada 10s, y avisa con una notificación de escritorio.
  # --------------------------------------------------------------------------
  echo "--- Instalando auto-recepción de archivos Tailscale ---"

  run_sudo tee /usr/local/bin/tailscale-autofetch.sh > /dev/null << 'EOF'
#!/bin/bash
DEST="$HOME/Descargas"
mkdir -p "$DEST"
while true; do
  ANTES=$(ls -1 "$DEST" 2>/dev/null | sort)
  tailscale file get "$DEST" >/dev/null 2>&1
  DESPUES=$(ls -1 "$DEST" 2>/dev/null | sort)
  NUEVOS=$(comm -13 <(echo "$ANTES") <(echo "$DESPUES"))
  if [ -n "$NUEVOS" ] && command -v notify-send >/dev/null 2>&1; then
    while IFS= read -r archivo; do
      [ -n "$archivo" ] && notify-send "Tailscale - Archivo recibido" "$archivo" -i network-vpn
    done <<< "$NUEVOS"
  fi
  sleep 10
done
EOF
  run_sudo chmod +x /usr/local/bin/tailscale-autofetch.sh

  # Autostart para todos los usuarios nuevos y para el actual
  mkdir -p /etc/skel/.config/autostart
  echo -e "[Desktop Entry]\nType=Application\nExec=/usr/local/bin/tailscale-autofetch.sh\nHidden=false\nNoDisplay=false\nX-GNOME-Autostart-enabled=true\nName=Tailscale Auto-Recepcion" | run_sudo tee /etc/skel/.config/autostart/tailscale-autofetch.desktop >/dev/null
  mkdir -p ~/.config/autostart
  cp /etc/skel/.config/autostart/tailscale-autofetch.desktop ~/.config/autostart/ 2>/dev/null

  # Arrancarlo ya, sin esperar al próximo login
  pkill -f tailscale-autofetch.sh 2>/dev/null
  nohup /usr/local/bin/tailscale-autofetch.sh >/dev/null 2>&1 &
  disown

  echo "    ✓ Auto-recepción de archivos instalada y corriendo"
fi
else
  echo "--- Submenú Thunar de Tailscale: SALTEADO (INSTALAR_TAILSCALE=false) ---"
fi

# 11. Estirar pantalla de Terminal - Modo 10/08/2026
#!/bin/bash

# 1. Configurar el tamaño predeterminado global (145x35)
PROFILE=$(gsettings get org.mate.terminal.global profile-list | tr -d "[]'")
gsettings set org.mate.terminal.profile:/org/mate/terminal/profiles/$PROFILE/ use-custom-default-size true
gsettings set org.mate.terminal.profile:/org/mate/terminal/profiles/$PROFILE/ default-size-columns 145
gsettings set org.mate.terminal.profile:/org/mate/terminal/profiles/$PROFILE/ default-size-rows 35

# 2. Copiar el acceso directo del sistema a tu carpeta de usuario
mkdir -p ~/.local/share/applications
cp /usr/share/applications/mate-terminal.desktop ~/.local/share/applications/

# 3. Modificar el icono para que use la geometría de posicionamiento superior izquierda (+0+0)
sed -i 's/^Exec=mate-terminal/Exec=mate-terminal --geometry=+0+0/' ~/.local/share/applications/mate-terminal.desktop

# 12. Finalizar
run_sudo fc-cache -f -v
update-desktop-database ~/.local/share/applications/ 2>/dev/null || true

# Limpiar variable de contraseña de la memoria
unset PASSWORD

echo ""
echo "======================================================"
echo "  ¡Proceso terminado!"
echo "  Cerrá sesión y volvé a entrar para que todo tome efecto."
echo "  Los iconos populares ya deberían estar en el Escritorio."
echo "======================================================"
echo ""
echo "Nota: Si aparece la ventana de WPS pidiendo Aceptar,"
echo "      es el único paso manual que puede quedar."
echo "======================================================"