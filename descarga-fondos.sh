# "descarga-fondos.sh" Claude 01.05.2026
# Descargar carpeta de fondos de pantalla en PC CLIENTES (sin Git)
# Repo: Fi-2603 -> carpeta local: ~/Imagenes/Fi-2603

USUARIO=$(whoami)
DESTINO="/home/$USUARIO/Imagenes"

rm -rf "$DESTINO/Fi-2603"
rm -f  "$DESTINO/Fi-2603.zip"

wget "https://github.com/HoracEzq58/Fi-2603/archive/refs/heads/main.zip" \
     -O "$DESTINO/Fi-2603.zip"

unzip "$DESTINO/Fi-2603.zip" -d "$DESTINO"
rm -f "$DESTINO/Fi-2603.zip"
mv    "$DESTINO/Fi-2603-main" "$DESTINO/Fi-2603"

echo "Listo! Fondos disponibles en $DESTINO/Fi-2603"