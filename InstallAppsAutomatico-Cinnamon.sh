#!/bin/bash
# ==================================================================
# InstallAppsAutomatico-Cinnamon.sh - Versión 1 Claude 17/08/2026
# Adaptado desde InstallAppsAutomatico-Linux.sh (MATE) v5
# Curso ABC PC ICO - Casa de Oración Flores
# Linux Mint CINNAMON (DDR3 en adelante)
# ==================================================================
# CAMBIOS RESPECTO A LA VERSIÓN MATE:
#  - Thunar deja de ser el explorador default -> Nemo (nativo de Cinnamon)
#  - Botonera "Enviar por Tailscale" migrada de Thunar (uca.xml) a
#    Nemo Actions (.nemo_action), un archivo por máquina destino
#  - Se agrega KDE Connect + indicador (no estaba en la versión MATE)
#  - Se agrega Tilix como terminal (reemplaza mate-terminal), seteado
#    como terminal por defecto de Cinnamon y tamaño 145x35
#  - Se pre-descargan (no se activan) los archivos del applet de
#    sensores de temperatura para el panel (Sensors@claudiux)
#  - gsettings de screensaver: org.mate.* -> org.cinnamon.*
#  - coretemp, RustDesk, WPS, Flatpak, Tailscale: SIN CAMBIOS
#    (son apt/systemd puros, no dependen del entorno de escritorio)
# ==================================================================

# --------------------------------------------------------------------------
# INTERRUPTOR: poné "false" si esta PC no va a formar parte de la mini red
# Tailscale del taller (te salteás instalación de Tailscale, el operador,
# el ícono systray, y las acciones "Enviar por Tailscale" en Nemo).
# --------------------------------------------------------------------------
INSTALAR_TAILSCALE=false

# --------------------------------------------------------------------------
# Contraseña permanente de RustDesk: completá acá la misma que ya usás para
# no tener que fijarla a mano en cada PC. Dejá "" para saltear este paso
# y configurarla vos después con: sudo rustdesk --password TU_CLAVE
# --------------------------------------------------------------------------
RUSTDESK_PASSWORD="Abcpc2026"

echo "======================================================"
echo "  InstallApps Automático - Cinnamon - Versión 1"
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
run_sudo apt install -y snapd ttf-mscorefonts-installer htop inxi stacer gparted variety simplescreenrecorder sox libsox-fmt-all smartmontools thunar dconf-cli

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
  org.localsend.localsend_app

# Corregir permisos de Flatpak
mkdir -p ~/.var
run_sudo chown -R $USER:$USER ~/.var
chmod -R u+rwX ~/.var

# --------------------------------------------------------------------------
# 5.5 RustDesk (paquete nativo .deb, NO Flatpak)
# --------------------------------------------------------------------------
echo "--- Instalando RustDesk (paquete nativo, no Flatpak) ---"

if flatpak list --user 2>/dev/null | grep -q com.rustdesk.RustDesk; then
  echo "    Se detectó una versión Flatpak vieja de RustDesk, desinstalando..."
  flatpak uninstall -y --user com.rustdesk.RustDesk 2>/dev/null
fi
rm -f "$HOME/Escritorio/com.rustdesk.RustDesk.desktop"
rm -f "$HOME/.local/share/applications/com.rustdesk.RustDesk.desktop"

RUSTDESK_DEB_URL=$(curl -fsSL https://api.github.com/repos/rustdesk/rustdesk/releases/latest \
  | grep -oP '"browser_download_url":\s*"\K[^"]*x86_64\.deb(?=")' | head -n 1)

if [ -n "$RUSTDESK_DEB_URL" ]; then
  curl -fsSL -o /tmp/rustdesk.deb "$RUSTDESK_DEB_URL"
  run_sudo apt install -fy /tmp/rustdesk.deb
  rm -f /tmp/rustdesk.deb
  run_sudo systemctl enable --now rustdesk

  if [ -n "$RUSTDESK_PASSWORD" ]; then
    run_sudo rustdesk --password "$RUSTDESK_PASSWORD"
    echo "    ✓ Contraseña permanente de RustDesk configurada"
  else
    echo "    ⚠ RUSTDESK_PASSWORD vacío: fijala a mano con 'sudo rustdesk --password TU_CLAVE'"
  fi

  echo "    ✓ RustDesk instalado como servicio (arranca solo, sin login)"
  echo "    ID de esta PC: $(rustdesk --get-id 2>/dev/null)"
else
  echo "    ✗ No se pudo detectar la última versión de RustDesk (revisar conexión a GitHub). Instalar a mano."
fi

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

FLATPAK_APPS=(
  "org.videolan.VLC"
  "org.localsend.localsend_app"
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

    if [ "$app" = "org.chromium.Chromium" ]; then
      sed -i 's|Exec=flatpak run org.chromium.Chromium|Exec=flatpak run org.chromium.Chromium --password-store=basic|g' "$DESKTOP_DIR/${app}.desktop"
      sed -i 's|Exec=/usr/bin/flatpak run --branch=stable --arch=x86_64 --command=/app/bin/chromium --file-forwarding org.chromium.Chromium|Exec=/usr/bin/flatpak run --branch=stable --arch=x86_64 --command=/app/bin/chromium --file-forwarding org.chromium.Chromium --password-store=basic|g' "$DESKTOP_DIR/${app}.desktop"
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

# RustDesk
RUSTDESK_DESKTOP=$(find /usr/share/applications -iname "rustdesk*.desktop" 2>/dev/null | head -n 1)
if [ -n "$RUSTDESK_DESKTOP" ]; then
  cp "$RUSTDESK_DESKTOP" "$DESKTOP_DIR/rustdesk.desktop"
  chmod +x "$DESKTOP_DIR/rustdesk.desktop"
  gio set "$DESKTOP_DIR/rustdesk.desktop" metadata::trusted true 2>/dev/null || true
  echo "✓ Icono creado: RustDesk (nativo)"
fi

# WPS Office
WPS_DESKTOP=$(find /var/lib/snapd/desktop/applications -name "*wps-office*.desktop" 2>/dev/null | head -n 1)
if [ -n "$WPS_DESKTOP" ]; then
  cp "$WPS_DESKTOP" "$DESKTOP_DIR/wps-office.desktop"
  chmod +x "$DESKTOP_DIR/wps-office.desktop"
  gio set "$DESKTOP_DIR/wps-office.desktop" metadata::trusted true 2>/dev/null || true
  echo "✓ Icono creado: WPS Office"
fi

# 9. Sonido de Inicio y Configuración de Pantalla (Cinnamon)
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

# Desactivar bloqueo de pantalla por inactividad (equivalente Cinnamon de org.mate.screensaver)
gsettings set org.cinnamon.desktop.screensaver lock-enabled false
gsettings set org.cinnamon.desktop.screensaver idle-activation-enabled false

# =================================================================
# SECCIÓN 10: Configuración Automatizada de CoreTemp (sin cambios)
# =================================================================
echo "--- Configurando Comando coretemp y Permisos de Red ---"

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

run_sudo sed -i 's/\r$//' /usr/local/bin/coretemp
run_sudo chmod +x /usr/local/bin/coretemp

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
  if run_sudo tailscale set --operator=$USER; then
    echo "    ✓ Operador de Tailscale asignado a $USER"
  else
    echo "    ✗ ATENCIÓN: no se pudo asignar el operador de Tailscale."
    echo "      Probablemente falta hacer login: 'sudo tailscale up --hostname=$(hostname)'"
    echo "      y DESPUÉS correr a mano: 'sudo tailscale set --operator=$USER'"
  fi

  mkdir -p /etc/skel/.config/autostart
  echo -e "[Desktop Entry]\nType=Application\nExec=tailscale systray\nHidden=false\nNoDisplay=false\nX-GNOME-Autostart-enabled=true\nName=Tailscale Systray" | run_sudo tee /etc/skel/.config/autostart/tailscale-systray.desktop >/dev/null
  mkdir -p ~/.config/autostart
  cp /etc/skel/.config/autostart/tailscale-systray.desktop ~/.config/autostart/ 2>/dev/null
else
  echo "    (operador y systray de Tailscale salteados: INSTALAR_TAILSCALE=false)"
fi

# 7bis. Nemo como explorador preferido del sistema (nativo de Cinnamon)
run_sudo xdg-mime default nemo.desktop inode/directory application/x-gnome-saved-search 2>/dev/null

# ================================================================================================
# SECCIÓN NUEVA: BOTONERA TAILSCALE EN NEMO (reemplaza la UCA de Thunar)
# Nemo no soporta submenús como Thunar, así que cada máquina aparece como
# una acción de primer nivel: "Tailscale: enviar a NOMBRE"
# ================================================================================================
if [ "$INSTALAR_TAILSCALE" = true ]; then
echo
echo ">>> Configurando envío de archivos por Tailscale en Nemo (modo dinámico)..."

MAQUINAS=(
  "abcpc01-desktop:ABCPC01"
  "abcpc02-desktop:ABCPC02"
  "abcpc03-desktop:ABCPC03 (Windows)"
  "abcpc04-g41m-es2l:ABCPC04"
  "abcpc05-inspiron-1545:ABCPC05 (Dell)"
)

MI_HOSTNAME=$(hostname | tr 'A-Z' 'a-z')
echo "    Hostname detectado en esta PC (normalizado): $MI_HOSTNAME"

NEMO_ACTIONS_DIR="$HOME/.local/share/nemo/actions"
mkdir -p "$NEMO_ACTIONS_DIR"

# Limpiar acciones viejas generadas por este script (por si cambió el mapa de máquinas)
rm -f "$NEMO_ACTIONS_DIR"/tailscale-send-*.nemo_action

GENERADAS=0
for entry in "${MAQUINAS[@]}"; do
  TS_HOST="${entry%%:*}"
  NOMBRE="${entry##*:}"

  # Saltear la propia PC
  if [[ "$TS_HOST" == "$MI_HOSTNAME"* ]] || [[ "$MI_HOSTNAME" == "$TS_HOST"* ]]; then
    continue
  fi

  UID_SAFE=$(echo "$TS_HOST" | tr -c 'a-zA-Z0-9' '-')
  ACTION_FILE="$NEMO_ACTIONS_DIR/tailscale-send-${UID_SAFE}.nemo_action"

  cat > "$ACTION_FILE" <<EOF
[Nemo Action]
Name=Tailscale: enviar a ${NOMBRE}
Comment=Enviar archivo a ${NOMBRE} por Tailscale
Exec=tailscale file cp %F ${TS_HOST}:
Icon-Name=network-vpn
Selection=notnone
Extensions=any;
EOF
  GENERADAS=$((GENERADAS+1))
done

if [ "$GENERADAS" -gt 0 ]; then
  echo "    ✓ $GENERADAS acciones de Tailscale creadas en Nemo (click derecho en cualquier archivo)"
  run_sudo mkdir -p /etc/skel/.local/share/nemo/actions
  run_sudo cp "$NEMO_ACTIONS_DIR"/tailscale-send-*.nemo_action /etc/skel/.local/share/nemo/actions/ 2>/dev/null

  # Reiniciar Nemo para que tome las acciones nuevas
  nemo -q 2>/dev/null || true
  sleep 1
  pkill -9 -u "$USER" nemo-desktop 2>/dev/null || true
  (nohup nemo-desktop >/dev/null 2>&1 & disown) 2>/dev/null
else
  echo "    (sin otras máquinas para mostrar en el menú, solo está esta PC)"
fi

# --------------------------------------------------------------------------
# Auto-recepción: idéntico a la versión MATE, sin cambios
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

mkdir -p /etc/skel/.config/autostart
echo -e "[Desktop Entry]\nType=Application\nExec=/usr/local/bin/tailscale-autofetch.sh\nHidden=false\nNoDisplay=false\nX-GNOME-Autostart-enabled=true\nName=Tailscale Auto-Recepcion" | run_sudo tee /etc/skel/.config/autostart/tailscale-autofetch.desktop >/dev/null
mkdir -p ~/.config/autostart
cp /etc/skel/.config/autostart/tailscale-autofetch.desktop ~/.config/autostart/ 2>/dev/null

pkill -f tailscale-autofetch.sh 2>/dev/null
nohup /usr/local/bin/tailscale-autofetch.sh >/dev/null 2>&1 &
disown

echo "    ✓ Auto-recepción de archivos instalada y corriendo"
else
  echo "--- Botonera Tailscale en Nemo: SALTEADO (INSTALAR_TAILSCALE=false) ---"
fi

# ================================================================================================
# SECCIÓN NUEVA: KDE Connect (no estaba en la versión MATE)
# ================================================================================================
echo "--- Instalando y configurando KDE Connect ---"
run_sudo apt install -y kdeconnect

mkdir -p ~/.config/autostart
cat << 'EOF' > ~/.config/autostart/kdeconnect-indicator.desktop
[Desktop Entry]
Type=Application
Name=KDE Connect Indicator
Exec=kdeconnect-indicator
Icon=kdeconnect
X-GNOME-Autostart-enabled=true
EOF
run_sudo mkdir -p /etc/skel/.config/autostart
run_sudo cp ~/.config/autostart/kdeconnect-indicator.desktop /etc/skel/.config/autostart/ 2>/dev/null
echo "    ✓ KDE Connect instalado, indicador en autostart"

# ================================================================================================
# SECCIÓN NUEVA: Tilix como terminal (reemplaza al bloque de mate-terminal de la versión MATE)
# ================================================================================================
echo "--- Instalando Tilix como terminal ---"
run_sudo apt install -y tilix

# Terminal por defecto de Cinnamon (la usan Nemo "Abrir un terminal aquí", atajos, etc.)
gsettings set org.cinnamon.desktop.default-applications.terminal exec 'tilix'
gsettings set org.cinnamon.desktop.default-applications.terminal exec-arg '-x'

# Alternativa del sistema, para apps que invocan x-terminal-emulator genérico
if [ -x /usr/bin/tilix ]; then
  run_sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/tilix 50
  run_sudo update-alternatives --set x-terminal-emulator /usr/bin/tilix 2>/dev/null || true
fi

# Tamaño por defecto del perfil (mismo 145x35 que tenías en mate-terminal).
# 2b7c4080-0ddd-46c5-8f23-563fd3ba789d es el UUID de perfil "Default" que
# trae Tilix compilado de fábrica (antes de que el usuario cree otro).
TILIX_PROFILE="2b7c4080-0ddd-46c5-8f23-563fd3ba789d"
dconf write "/com/gexperts/Tilix/profiles/${TILIX_PROFILE}/default-size-columns" 145
dconf write "/com/gexperts/Tilix/profiles/${TILIX_PROFILE}/default-size-rows" 35

echo "    ✓ Tilix instalado y configurado como terminal por defecto (145x35)"

# ================================================================================================
# SECCIÓN NUEVA (opcional, no crítica): pre-descarga del applet de sensores para el panel
# No lo activa solo -- eso queda como único paso manual (2 clicks) porque la
# posición del panel varía de máquina a máquina.
# ================================================================================================
echo "--- Descargando applet de sensores (Cinnamon Spices) ---"
APPLET_UUID="Sensors@claudiux"
APPLET_DEST="$HOME/.local/share/cinnamon/applets/${APPLET_UUID}"
if [ ! -d "$APPLET_DEST" ]; then
  TMP_SPICES=$(mktemp -d)
  if git clone --depth 1 --filter=blob:none --sparse https://github.com/linuxmint/cinnamon-spices-applets.git "$TMP_SPICES" >/dev/null 2>&1; then
    ( cd "$TMP_SPICES" && git sparse-checkout set "$APPLET_UUID" >/dev/null 2>&1 )
    mkdir -p "$HOME/.local/share/cinnamon/applets"
    cp -r "$TMP_SPICES/$APPLET_UUID" "$APPLET_DEST" 2>/dev/null
  fi
  rm -rf "$TMP_SPICES"
fi
if [ -d "$APPLET_DEST" ]; then
  echo "    ✓ Applet de sensores pre-descargado."
  echo "      Para activarlo: click derecho en el panel → Applets → pestaña 'Manage' → 'Sensors' → +"
else
  echo "    ⚠ No se pudo pre-descargar el applet de sensores (¿sin conexión?)."
  echo "      Instalarlo a mano después: Applets → pestaña 'Download' → buscar 'Sensors'"
fi

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
echo "  - Nemo queda como explorador default (no Thunar)"
echo "  - Tilix queda como terminal default (145x35)"
echo "  - Sensores: falta el paso manual de activarlo en el panel"
echo "======================================================"
echo ""
echo "Nota: Si aparece la ventana de WPS pidiendo Aceptar,"
echo "      es el único paso manual que puede quedar."
echo "======================================================"