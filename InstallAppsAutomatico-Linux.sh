#!/bin/bash
# =================================================================
# Script de InstallAppsAutomatico-Linux.sh (Old Pc Resurrection)
# =================================================================

echo "--- Iniciando el Tune-up de la Pc ---"

# 1. Limpieza inicial: Quitar LibreOffice para evitar duplicados
sudo apt purge -y libreoffice*
sudo apt autoremove -y

# 2. Actualizar base y habilitar Snap
sudo rm -f /etc/apt/preferences.d/nosnap.pref
sudo apt update && sudo apt upgrade -y
sudo apt install -y snapd ttf-mscorefonts-installer htop inxi stacer gparted variety simplescreenrecorder

# 3. Diversión y Juegos
sudo apt install -y supertuxkart extremetuxracer

# 4. Flatpak y Aplicaciones (WhatsApp, Zoom, VLC, RustDesk)
sudo apt install -y flatpak
sudo flatpak remote-add --if-not-exists flathub https://flathub.org
flatpak install -y flathub org.chromium.Chromium \
io.github.mimbrero.WhatsAppDesktop \
us.zoom.Zoom \
org.videolan.VLC \
com.rustdesk.RustDesk \
org.localsend.localsend_app

# 5. Reparar Keyring de Chromium (Versión Flatpak)
# Creamos un alias para que no pida contraseña al abrirlo
if [ ! -f ~/.bashrc_backup ]; then cp ~/.bashrc ~/.bashrc_backup; fi
echo "alias chromium='flatpak run org.chromium.Chromium --password-store=basic'" >> ~/.bashrc

# 6. INSTALAR WPS OFFICE
sudo snap install wps-office-multilang

# 7. PERMISOS CRUCIALES DE SNAP
# El permiso ':home' es vital para que WPS lea el idioma que seteamos abajo
sudo snap connect wps-office-multilang:cups-control
sudo snap connect wps-office-multilang:alsa
sudo snap connect wps-office-multilang:pulseaudio
sudo snap connect wps-office-multilang:home

# 8. FORZAR IDIOMA ESPAÑOL ARGENTINA (El toque de Messi)
mkdir -p ~/.config/Kingsoft
mkdir -p ~/.local/share/Kingsoft/office6/dicts

cat <<EOF > ~/.config/Kingsoft/WPSOffice.conf
[General]
languages=es_AR
EOF

# Seteamos el diccionario por defecto
echo "es_AR" > ~/.local/share/Kingsoft/office6/dicts/default.dic

# 9. Refrescar fuentes y finalizar
sudo fc-cache -f -v

echo "--- ¡Proceso terminado! La Pc está lista para la venta ---"
echo "Recordá cerrar y abrir la terminal para que el comando 'chromium' tome el cambio."

# 10. EXTENSIÓN H264IFY PARA CHROMIUM (Optimización de video)
EXT_ID="aleakchihdccplidncghkekgioiakgal"
FOLDER="$HOME/.var/app/org.chromium.Chromium/config/chromium/External Extensions"

mkdir -p "$FOLDER"
echo '{ "external_update_url": "https://google.com" }' > "$FOLDER/$EXT_ID.json"

# 11 Wps-Language.sh - Activar Español en WPS - comandos aparte (?)
sudo snap connect wps-office-multilang:home
mkdir -p ~/.config/Kingsoft
echo -e "[General]\nlanguages=es_AR" > ~/.config/Kingsoft/WPSOffice.conf
sudo chown $USER:$USER ~/.config/Kingsoft/WPSOffice.conf
sudo apt install -y language-pack-es language-pack-es-base
mkdir -p ~/snap/wps-office-multilang/current/.config/Kingsoft
cp ~/.config/Kingsoft/WPSOffice.conf ~/snap/wps-office-multilang/current/.config/Kingsoft/
sudo snap connect wps-office-multilang:desktop-legacy

# 12 Eliminar iconos sobrantes libreoffice
sudo apt purge -y libreoffice-common libreoffice-core
sudo apt purge firefox -y
sudo apt autoremove -y

# 13 Forzar aparicion icono wps
sudo ln -s /var/lib/snapd/desktop/applications/*.desktop /usr/share/applications/
