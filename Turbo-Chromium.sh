#!/bin/bash
# =================================================================
# Turbo-Chromium.sh FLATPAK Edition (iMac & Pc's Carreta)
# Incluye optimización de Chromium, RAM y Discos HDD Mecánicos
# =================================================================

# VALIDACIÓN: Verificar que se ejecute como root (Sudo) ya que el HDD lo requiere
if [ "$EUID" -ne 0 ]; then
  echo "❌ Error: Este script optimiza el hardware y requiere ejecutarse con 'sudo'."
  echo "Por favor, ejecútalo como: sudo ./tu_script.sh"
  exit 1
fi

# Detectar el usuario real que está ejecutando el comando sudo
REAL_USER=${SUDO_USER:-$USER}
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

echo "🚀 Iniciando optimización Turbo para el Sistema..."

# 1. Definir Flags de Rendimiento para Chromium
# ---------------------------------------------------------
FLAGS="--password-store=basic --enable-parallel-downloading --enable-quic --enable-gpu-rasterization --enable-zero-copy --ignore-gpu-blocklist --no-default-browser-check --enable-features=HighEfficiencyModeAvailable"

# 2. Aplicar Flags al alias del sistema (Usando la ruta del usuario real)
if [ ! -f "$REAL_HOME/.bashrc_backup" ]; then cp "$REAL_HOME/.bashrc" "$REAL_HOME/.bashrc_backup"; fi
# Borramos alias viejos para no duplicar
sed -i '/alias chromium=/d' "$REAL_HOME/.bashrc"
# Agregamos el nuevo alias con todas las banderas de velocidad
echo "alias chromium='flatpak run org.chromium.Chromium $FLAGS'" >> "$REAL_HOME/.bashrc"
# Cambiar propiedad al usuario real para evitar problemas de permisos
chown "$REAL_USER:$REAL_USER" "$REAL_HOME/.bashrc"

# 3. INSTALAR EXTENSIÓN h264ify (Para que YouTube no explote)
# ---------------------------------------------------------
EXT_ID="aleakchihdccplidncghkekgioiakgal"
FOLDER="$REAL_HOME/.var/app/org.chromium.Chromium/config/chromium/External Extensions"

mkdir -p "$FOLDER"
echo '{
  "external_update_url": "https://google.com"
}' > "$FOLDER/$EXT_ID.json"
# Cambiar propiedad de la carpeta de la extensión al usuario real
chown -R "$REAL_USER:$REAL_USER" "$REAL_HOME/.var/app/org.chromium.Chromium"

# 4. Limpieza de RAM del Sistema
# ---------------------------------------------------------
echo "🧹 Liberando RAM del sistema..."
sync && echo 3 > /proc/sys/vm/drop_caches

# 5. Optimización de Disco HDD Mecánico (7200 RPM / 5400 RPM)
# ---------------------------------------------------------
echo "💾 Optimizando disco HDD y gestión de Swap..."

# Ajustar swappiness para no desgastar el disco rígido usando memoria virtual
if grep -q "vm.swappiness" /etc/sysctl.conf; then
    sed -i 's/^vm.swappiness.*/vm.swappiness=10/' /etc/sysctl.conf
else
    echo "" >> /etc/sysctl.conf
    echo "# Optimizacion para mejorar rendimiento en discos HDD mecánicos" >> /etc/sysctl.conf
    echo "vm.swappiness=10" >> /etc/sysctl.conf
fi

# Aplicar los cambios de memoria de inmediato
sysctl -p

# Configurar el planificador de lectura inteligente (BFQ) para discos mecánicos
for disco in /sys/block/sd*; do
    if [ -f "$disco/queue/rotational" ] && [ "$(cat $disco/queue/rotational)" -eq 1 ]; then
        if grep -q "bfq" "$disco/queue/scheduler"; then
            echo "bfq" > "$disco/queue/scheduler"
            echo "[✓] Planificador BFQ activado en disco rígido: $(basename $disco)"
        fi
    fi
done

echo "-------------------------------------------------------"
echo "✅ ¡TERMINADO! Sistema y Chromium optimizados con Turbo."
echo "IMPORTANTE: Cerrá y abrí la terminal para aplicar los alias."
echo "-------------------------------------------------------"
