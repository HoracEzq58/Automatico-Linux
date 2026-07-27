#!/bin/bash
# "descarga-automatico.sh" Descargar repo y renombrar a carpeta local "Automatico"

DESTINO="$HOME/Documentos"

# 1. Limpieza previa de descargas o carpetas anteriores
rm -rf "$DESTINO/Automatico"
rm -rf "$DESTINO/Automatico-Linux-main"
rm -f  "$DESTINO/Automatico-Linux.zip"

# 2. Descargar el zip del repositorio
wget -q --show-progress "https://github.com/HoracEzq58/Automatico-Linux/archive/refs/heads/main.zip" -O "$DESTINO/Automatico-Linux.zip"

# 3. Descomprimir silenciosamente en Documentos
unzip -q "$DESTINO/Automatico-Linux.zip" -d "$DESTINO"

# 4. Renombrar la carpeta extraída a "Automatico" y limpiar el zip
mv "$DESTINO/Automatico-Linux-main" "$DESTINO/Automatico"
rm -f "$DESTINO/Automatico-Linux.zip"

# 5. Dar permisos de ejecución recursivos a todos los .sh (incluso en subcarpetas)
find "$DESTINO/Automatico" -type f -name "*.sh" -exec chmod +x {} +

# 6. Salida limpia
echo -e "\n¡Listo! Carpeta disponible en: $DESTINO/Automatico\n"
echo "Scripts listos para ejecutar:"
ls -1 "$DESTINO/Automatico/"*.sh 2>/dev/null || echo "No se encontraron scripts .sh en la raíz."