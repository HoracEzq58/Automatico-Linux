#!/bin/bash
# =================================================================
# Turbo-Chromium.sh FLATPAK Edition (iMac & Pc's Carreta)
# =================================================================

echo "🚀 Iniciando optimización Turbo para Chromium Flatpak..."

# 1. Definir Flags de Rendimiento
# ---------------------------------------------------------
FLAGS="--password-store=basic --enable-parallel-downloading --enable-quic --enable-gpu-rasterization --enable-zero-copy --ignore-gpu-blocklist --no-default-browser-check --enable-features=HighEfficiencyModeAvailable"

# 2. Aplicar Flags al alias del sistema (para que arranque siempre rápido)
if [ ! -f ~/.bashrc_backup ]; then cp ~/.bashrc ~/.bashrc_backup; fi
# Borramos alias viejos para no duplicar
sed -i '/alias chromium=/d' ~/.bashrc
# Agregamos el nuevo alias con todas las banderas de velocidad
echo "alias chromium='flatpak run org.chromium.Chromium $FLAGS'" >> ~/.bashrc

# 3. INSTALAR EXTENSIÓN h264ify (Para que YouTube no explote)
# ---------------------------------------------------------
EXT_ID="aleakchihdccplidncghkekgioiakgal"
FOLDER="$HOME/.var/app/org.chromium.Chromium/config/chromium/External Extensions"

mkdir -p "$FOLDER"
echo '{
  "external_update_url": "https://google.com"
}' > "$FOLDER/$EXT_ID.json"

# 4. Limpieza de RAM del Sistema
# ---------------------------------------------------------
echo "🧹 Liberando RAM del sistema..."
sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null

echo "-------------------------------------------------------"
echo "✅ ¡TERMINADO! Chromium optimizado con h264ify y Turbo."
echo "IMPORTANTE: Cerrá y abrí la terminal para aplicar cambios."
echo "-------------------------------------------------------"