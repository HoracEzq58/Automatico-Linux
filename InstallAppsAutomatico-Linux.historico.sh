#!/bin/bash
# Script de optimización iMac Resurrection

echo "--- Iniciando el Tune-up de la iMac ---"

# Actualizar base
sudo apt update && sudo apt upgrade -y

# Herramientas de sistema y utilidades
sudo apt install -y htop inxi stacer gparted variety simplescreenrecorder

# Diversión y Juegos
sudo apt install -y supertuxkart extremetuxracer

# Flatpak y Repositorio Flathub
sudo apt install -y flatpak
sudo flatpak remote-add --if-not-exists flathub https://flathub.org

# Aplicaciones pesadas vía Flatpak
flatpak install -y flathub org.chromium.Chromium
flatpak install -y flathub io.github.mimbrero.WhatsAppDesktop
flatpak install -y flathub us.zoom.Zoom 
flatpak install -y flathub org.videolan.VLC
flatpak install -y flathub com.rustdesk.RustDesk
flatpak install flathub org.localsend.localsend_app -y

# =================================================================
# SCRIPT: Reparar Autenticación de Chromium en Linux Mint (iMac)
# DESCRIPCIÓN: Añade el parámetro --password-store=basic al lanzador
# de Chromium para evitar el popup del Keyring.
# =================================================================

# 1. Definir la ruta del archivo de escritorio (lanzador)
# En Linux Mint, suele estar en /usr/share/applications/
DESKTOP_FILE="/usr/share/applications/chromium-browser.desktop"

# 2. Verificar si el archivo existe
if [ ! -f "$DESKTOP_FILE" ]; then
    echo "Error: No se encontró el lanzador en $DESKTOP_FILE"
    echo "Asegúrate de que Chromium esté instalado mediante apt."
    exit 1
fi

# 3. Hacer una copia de seguridad por si las moscas
sudo cp "$DESKTOP_FILE" "${DESKTOP_FILE}.bak"
echo "Copia de seguridad creada en ${DESKTOP_FILE}.bak"

# 4. Modificar la línea 'Exec' para incluir el flag mágico
# Este comando busca la línea que empieza con Exec= y le añade el parámetro
# específico para que Chromium gestione sus propias claves sin molestar.
sudo sed -i 's/^Exec=chromium-browser/Exec=chromium-browser --password-store=basic/' "$DESKTOP_FILE"

# Nota para iMac: Si tu iMac tiene hardware antiguo y Mint va un poco lento, 
# puedes añadir también '--disable-gpu' a la línea Exec si notas parpadeos,
# aunque lo ideal es dejar que la RAM fluya sola.

echo "¡Listo! Reinicia Chromium y ya no debería pedirte autenticación."


echo "--- ¡Proceso terminado! La iMac está lista para la venta ---"

# 1. Habilitar Snap en Linux Mint
sudo rm -f /etc/apt/preferences.d/nosnap.pref
sudo apt update
sudo apt install -y snapd ttf-mscorefonts-installer

# 2. Instalar WPS Office (Multilenguaje)
sudo snap install wps-office-multilang

# 3. Dar permisos para Impresoras y Audio (Confinamiento Snap)
sudo snap connect wps-office-multilang:cups-control
sudo snap connect wps-office-multilang:alsa
sudo snap connect wps-office-multilang:pulseaudio

# 4. Refrescar caché de fuentes
sudo fc-cache -f -v

echo "Instalación completada. Reinicia WPS para ver los cambios."

sudo apt purge libreoffice*
