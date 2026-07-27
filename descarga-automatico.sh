#!/bin/bash
# "descarga-automatico.sh"
# Se ejecuta desde Descargas, arma Documentos/Automatico y se auto-elimina al terminar.

ORIGEN_SCRIPT="$(readlink -f "$0")"
DESTINO="$HOME/Documentos"

# 1. Limpieza de instalaciones o descargas previas en Documentos
rm -rf "$DESTINO/Automatico"
rm -rf "$DESTINO/Automatico-Linux-main"
rm -f  "$DESTINO/Automatico-Linux.zip"

# 2. Descarga del zip desde GitHub
wget -q --show-progress "https://github.com/HoracEzq58/Automatico-Linux/archive/refs/heads/main.zip" -O "$DESTINO/Automatico-Linux.zip"

# 3. Descompresión y renombrado
unzip -q "$DESTINO/Automatico-Linux.zip" -d "$DESTINO"
mv "$DESTINO/Automatico-Linux-main" "$DESTINO/Automatico"
rm -f "$DESTINO/Automatico-Linux.zip"

# 4. Otorgar permisos de ejecución a todos los .sh (recursivo)
find "$DESTINO/Automatico" -type f -name "*.sh" -exec chmod +x {} +

echo -e "\n¡Listo! Carpeta disponible y configurada en: $DESTINO/Automatico\n"
echo "Scripts listos para ejecutar:"
ls -1 "$DESTINO/Automatico/"*.sh 2>/dev/null || echo "No se encontraron scripts en la raíz."

# 5. Auto-eliminación del script ejecutor en Descargas
echo -e "\nLimpiando instalador temporal de Descargas..."
rm -f "$ORIGEN_SCRIPT"