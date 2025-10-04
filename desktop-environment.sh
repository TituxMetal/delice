#!/bin/bash

# Run these commands with regular user

printMessage() {
  message=$1
  tput setaf 2
  echo "-------------------------------------------"
  echo "$message"
  echo "-------------------------------------------"
  tput sgr0
}

# Helper function to handle errors
handleError() {
  clear
  set -uo pipefail
  trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
}

main() {
  handleError

# Video drivers: please uncomment Intel or Nvidia if necessary

# Generics
  sudo apt install -y spice-vdagent xserver-xorg-video-qxl xserver-xorg-video-vesa

  # Intel Graphics
  # sudo apt install -y libva2 intel-media-va-driver xserver-xorg-video-intel

  # Nvidia
  # sudo apt install -y xserver-xorg-video-nouveau nvidia-vaapi-driver

  # Xfce desktop
  sudo apt install -y task-xfce-desktop accountsservice slick-greeter

  # Pre fill default user in lightdm

  sudo mkdir -p /etc/lightdm/lightdm.conf.d && sudo touch /etc/lightdm/lightdm.conf.d/user.conf
  sudo sh -c "cat > /etc/lightdm/lightdm.conf.d/user.conf" <<-EOF
[SeatDefaults]
  greeter-hide-users=false
  greeter-show-manual-login=true
#  display-setup-script=xrandr --output $(xrandr | grep " connected" | awk '{print $1}') --mode 1920x1200
EOF


  # X server utilities
  sudo apt install -y xbindkeys xdg-utils xdg-user-dirs xdg-user-dirs-gtk xbindkeys xcompmgr numlockx tumbler xbacklight xvkbd xinput

  # Themes and fonts
  sudo apt install -y lxappearance fonts-recommended fonts-ubuntu fonts-font-awesome fonts-lmodern fonts-terminus \
    papirus-icon-theme gtk-update-icon-cache arc-theme adwaita-qt qt5-style-kvantum

  # Web Browser
  sudo apt install -y firefox-esr firefox-esr-l10n-fr

  # Office Tools
  sudo apt install -y gpa gnupg ghostscript libreoffice-gtk3 libreoffice-l10n-fr libreoffice-help-fr \
    galculator l3afpad ghostwriter libtext-multimarkdown-perl cmark pandoc

  # Other Utils
  sudo apt install -y neofetch alacritty rofi pcmanfm libfm-tools libusbmuxd-tools feh dex xarchiver gparted gphoto2 sshfs nfs-common fuseiso \
    file-roller timeshift gvfs gvfs-backends gvfs-fuse dunst libnotify-bin figlet qimgv redshift cpu-x cryptsetup \
    pavucontrol alsa-utils pulseaudio ffmpeg ffmpegthumbnailer

  # Multimedia: please uncomment what you need
  # Gstreamer 
  sudo apt install -y gstreamer1.0-x gstreamer1.0-libav

  # Players
  sudo apt install -y vlc quodlibet shotwell evince mpd playerctl x265 x264 libdvd-pkg libdvdread8 libdvdnav4 libcdio19

  # Download libdvdcss2 source files
  sudo dpkg-reconfigure libdvd-pkg

  # Editors
  sudo apt install -y gimp inkscape scour

  # Burn
  # sudo apt install -y brasero dvdauthor dvdbackup dvd+rw-tools libisoburn1

  # Rip/Encode
  # sudo apt install -y asunder handbrake handbrake-cli lame ogmtools faac flac x265 x264

  # Bluetooth
  # sudo apt install -y bluez bluez-firmware bluez-tools pulseaudio-module-bluetooth blueman

  # Re-enable Ly as display manager and remove lightdm
  # systemctl disable display-manager.service && sudo apt remove --purge -y lightdm lightdm-gtk-greeter && sudo apt -y autoremove && systemctl enable ly

  # Copy all config files and directories in users .config
  cp -rv .config/* ~/.config/
  cp -rv wallpapers ~/
}

time main

exit 0
