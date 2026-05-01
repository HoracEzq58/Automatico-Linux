#!/bin/bash

# =================================================================
# Turbo-Chromium.sh Ram Optimizer (iMac Edition)
# DESCRIPCIÓN: Forzar flags de rendimiento y bypass de seguridad.
# =================================================================

# 1. Súper Radar para encontrar Chromium en Linux Mint
# ---------------------------------------------------------
RUTAS=(
    "/usr/share/applications/chromium-browser.desktop"
    "/usr/share/applications/chromium.desktop"
    "/var/lib/flatpak/exports/share/applications/org.chromium.Chromium.desktop"
    "$HOME/.local/share/flatpak/exports/share/applications/org.chromium.Chromium.desktop"
)

for r in "${RUTAS[@]}"; do
    if [ -f "$r" ]; then
        DESKTOP_FILE="$r"
        break
    fi
done


# 1. Parámetros de Rendimiento (Equivalentes a chrome://flags)
# ---------------------------------------------------------
# --enable-parallel-downloading   : Descargas en múltiples hilos.
# --enable-quic                   : Protocolo de red más rápido.
# --enable-gpu-rasterization      : Usa la GPU para dibujar la web.
# --enable-zero-copy              : Menos carga de CPU en gráficos.
# --password-store=basic          : Adiós al cartel de contraseña.
# --ignore-gpu-blocklist          : Fuerza el uso de la GPU vieja.
# --no-default-browser-check      : Menos procesos al arrancar.
# --enable-features=...           : Activa el Ahorro de Memoria.

FLAGS="--password-store=basic --enable-parallel-downloading --enable-quic --enable-gpu-rasterization --enable-zero-copy --ignore-gpu-blocklist --no-default-browser-check --enable-features=HighEfficiencyModeAvailable --high-efficiency-mode-available"

# 2. Aplicar al sistema
if [ -f "$DESKTOP_FILE" ]; then
    # Backup
    sudo cp "$DESKTOP_FILE" "${DESKTOP_FILE}.bak"
    
    # Limpiamos cualquier modificación previa y ponemos la nueva
    # Primero volvemos al original (por si ya habías corrido el script antes)
    sudo sed -i 's/^Exec=chromium-browser.*/Exec=chromium-browser/' "$DESKTOP_FILE"
    
    # Aplicamos todas las flags juntas
    sudo sed -i "s|^Exec=chromium-browser|Exec=chromium-browser $FLAGS|" "$DESKTOP_FILE"
    
    echo "✅ Flags aplicadas: Parallel Downloading y optimizaciones de GPU activas."
else
    echo "❌ No se encontró el lanzador de Chromium."
    exit 1
fi

# 3. Plus: Limpieza de RAM del Sistema (Mint)
# ---------------------------------------------------------
echo "🧹 Liberando RAM del sistema..."
sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null

echo "-------------------------------------------------------"
echo "¡Listo! Tu iMac ahora tiene el 'Turbo' activado."
echo "Reinicia Chromium para ver los cambios."
echo "-------------------------------------------------------"
