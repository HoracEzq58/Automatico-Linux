#!/bin/bash
# =================================================================
# InstallAppsAutomatico-Linux.sh - Grok 28/07/2026
# Versión mejorada - Curso ABC PC ICO - Casa de Oración Flores
# Linux Mint MATE (DDR2 / DDR3)
# =================================================================

echo "--- Iniciando el Tune-up de la Pc ---"

# 1. Limpieza inicial
sudo apt purge -y libreoffice* firefox
sudo apt autoremove -y

# 2. Actualizar sistema
sudo rm -f /etc/apt/preferences.d/nosnap.pref
sudo apt update && sudo apt upgrade -y
sudo apt install -y snapd ttf-mscorefonts-installer htop inxi stacer gparted variety simplescreenrecorder

# 3. Tailscale (método robusto)
echo "--- Instalando Tailscale ---"
source /etc/os-release
CODENAME="${UBUNTU_CODENAME:-jammy}"
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/${CODENAME}.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/${CODENAME}.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null
sudo apt update
sudo apt install -y tailscale

# 4. Juegos
sudo apt install -y supertuxkart extremetuxracer

# 5. Flatpak (instalado como usuario para evitar problemas de permisos)
sudo apt install -y flatpak
flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo

flatpak install -y --user flathub \
  org.chromium.Chromium \
  io.github.mimbrero.WhatsAppDesktop \
  us.zoom.Zoom \
  org.videolan.VLC \
  com.rustdesk.RustDesk \
  org.localsend.localsend_app

# Corregir permisos de Flatpak (importante)
mkdir -p ~/.var
sudo chown -R $USER:$USER ~/.var
chmod -R u+rwX ~/.var

# 6. Alias Chromium (sin pedir keyring)
if [ ! -f ~/.bashrc_backup ]; then cp ~/.bashrc ~/.bashrc_backup; fi
grep -q "alias chromium=" ~/.bashrc || echo "alias chromium='flatpak run org.chromium.Chromium --password-store=basic'" >> ~/.bashrc

# 7. WPS Office
sudo snap install wps-office-multilang
sudo snap connect wps-office-multilang:cups-control
sudo snap connect wps-office-multilang:alsa
sudo snap connect wps-office-multilang:pulseaudio
sudo snap connect wps-office-multilang:home
sudo snap connect wps-office-multilang:desktop-legacy

# Configurar idioma español Argentina
mkdir -p ~/.config/Kingsoft
mkdir -p ~/.local/share/Kingsoft/office6/dicts
cat <<EOF > ~/.config/Kingsoft/WPSOffice.conf
[General]
languages=es_AR
EOF
echo "es_AR" > ~/.local/share/Kingsoft/office6/dicts/default.dic

mkdir -p ~/snap/wps-office-multilang/current/.config/Kingsoft
cp ~/.config/Kingsoft/WPSOffice.conf ~/snap/wps-office-multilang/current/.config/Kingsoft/
sudo chown -R $USER:$USER ~/snap/wps-office-multilang

# 8. Crear iconos en el Escritorio (solo apps populares)
echo "--- Creando iconos en el Escritorio ---"

DESKTOP_DIR="$HOME/Escritorio"
mkdir -p "$DESKTOP_DIR"

# --- Flatpak ---
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
    echo "✓ Icono creado: $app"
  fi
done

# --- SuperTuxKart ---
if [ -f /usr/share/applications/supertuxkart.desktop ]; then
  cp /usr/share/applications/supertuxkart.desktop "$DESKTOP_DIR/"
  chmod +x "$DESKTOP_DIR/supertuxkart.desktop"
  gio set "$DESKTOP_DIR/supertuxkart.desktop" metadata::trusted true 2>/dev/null || true
  echo "✓ Icono creado: SuperTuxKart"
fi

# --- SimpleScreenRecorder ---
if [ -f /usr/share/applications/simplescreenrecorder.desktop ]; then
  cp /usr/share/applications/simplescreenrecorder.desktop "$DESKTOP_DIR/"
  chmod +x "$DESKTOP_DIR/simplescreenrecorder.desktop"
  gio set "$DESKTOP_DIR/simplescreenrecorder.desktop" metadata::trusted true 2>/dev/null || true
  echo "✓ Icono creado: SimpleScreenRecorder"
fi

# --- WPS Office ---
WPS_DESKTOP=$(find /var/lib/snapd/desktop/applications -name "*wps-office*.desktop" 2>/dev/null | head -n 1)
if [ -n "$WPS_DESKTOP" ]; then
  cp "$WPS_DESKTOP" "$DESKTOP_DIR/wps-office.desktop"
  chmod +x "$DESKTOP_DIR/wps-office.desktop"
  gio set "$DESKTOP_DIR/wps-office.desktop" metadata::trusted true 2>/dev/null || true
  echo "✓ Icono creado: WPS Office"
fi

# 9. Finalizar
sudo fc-cache -f -v
update-desktop-database ~/.local/share/applications/ 2>/dev/null || true

echo ""
echo "=============================================="
echo "  ¡Proceso terminado correctamente!"
echo "  Cerrá sesión y volvé a entrar."
echo "  Los iconos populares ya están en el Escritorio."
echo "=============================================="