#!/bin/bash
# =================================================================
# InstallAppsAutomatico-Linux.sh - Versión 2 Grok 29/07/2026 (casi 0 intervención)
# Curso ABC PC ICO - Casa de Oración Flores
# Linux Mint MATE (DDR2 / DDR3)
# =================================================================

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
run_sudo apt install -y snapd ttf-mscorefonts-installer htop inxi stacer gparted variety simplescreenrecorder sox libsox-fmt-all

# 3. Tailscale (método robusto corregido)
echo "--- Instalando Tailscale ---"
source /etc/os-release
CODENAME="${UBUNTU_CODENAME:-jammy}"

curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${CODENAME}.noarmor.gpg" | sudo -S tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/ubuntu ${CODENAME} main" | sudo -S tee /etc/apt/sources.list.d/tailscale.list >/dev/null

run_sudo apt update && run_sudo apt install -y tailscale


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

# 10. Finalizar
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