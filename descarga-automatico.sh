# "descarga-automatico.sh" Descargar carpeta completa si lo hago en maquinas cliente (no tienen Git)
# Repo: Automatico-Linux -> carpeta local: Automatico // Claude 01/05/2026

USUARIO=$(whoami)
DESTINO="$HOME/Documentos"

rm -rf "$DESTINO/Automatico"
rm -f  "$DESTINO/Automatico-Linux.zip"

wget "https://github.com/HoracEzq58/Automatico-Linux/archive/refs/heads/main.zip" -O "$DESTINO/Automatico-Linux.zip"

unzip "$DESTINO/Automatico-Linux.zip" -d "$DESTINO"
rm -f "$DESTINO/Automatico-Linux.zip"
mv    "$DESTINO/Automatico-Linux-main" "$DESTINO/Automatico"

# Dar permisos de ejecucion a todos los scripts de una
chmod +x "$DESTINO"/Automatico/*.sh

echo "Listo! Carpeta disponible en $DESTINO/Automatico"
echo "Scripts listos para ejecutar:"
ls "$DESTINO/Automatico/"*.sh