# incluido en InstallAppsAutomatico-Linux.sh 29/04/2026 17.16 hs
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

