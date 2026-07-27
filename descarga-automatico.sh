#!/bin/bash
# "descarga-automatico.sh"

ORIGEN_SCRIPT="$(readlink -f "$0")"
DESTINO="$HOME/Documentos"
CARPETA_TARGET="$DESTINO/Automatico"

# 0. Reparar permisos si la carpeta previa pertenece a root u otro usuario
if [ -d "$CARPETA_TARGET" ] && [ ! -w "$CARPETA_TARGET" ]; then
    echo "Aviso: Se detectaron problemas de permisos en $CARPETA_TARGET. Corrigiendo..."
    sudo chown -R "$(whoami):$(whoami)" "$CARPETA_TARGET" 2>/dev/null || true
    chmod -R u+w "$CARPETA_TARGET" 2>/dev/null || true
fi

# 1. Limpieza de instalaciones o descargas previas
rm -rf "$CARPETA_TARGET"
rm -rf "$DESTINO/Automatico-Linux-main"
rm -f  "$DESTINO/Automatico-Linux.zip"

# 2. Descarga del zip desde GitHub
wget -q --show-progress "https://github.com/HoracEzq58/Automatico-Linux/archive/refs/heads/main.zip" -O "$DESTINO/Automatico-Linux.zip"

# 3. Descompresión y renombrado
unzip -q "$DESTINO/Automatico-Linux.zip" -d "$DESTINO"
mv "$DESTINO/Automatico-Linux-main" "$CARPETA_TARGET"
rm -f "$DESTINO/Automatico-Linux.zip"

# 4. Otorgar permisos de ejecución a todos los .sh
find "$CARPETA_TARGET" -type f -name "*.sh" -exec chmod +x {} +

echo -e "\n¡Listo! Carpeta disponible y configurada en: $CARPETA_TARGET\n"
echo "Scripts listos para ejecutar:"
ls -1 "$CARPETA_TARGET/"*.sh 2>/dev/null || echo "No se encontraron scripts en la raíz."

# 5. Auto-eliminación del script ejecutor en Descargas
echo -e "\nLimpiando instalador temporal de Descargas..."
rm -f "$ORIGEN_SCRIPT"