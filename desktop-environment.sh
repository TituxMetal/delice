#!/bin/bash

# Themes and fonts
apt install -y lxappearance fonts-recommended fonts-font-awesome fonts-terminus papirus-icon-theme \
  gtk-update-icon-cache arc-theme

# Utils
apt install -y neofetch alacritty rofi pcmanfm feh galculator dex xarchiver zip unzip unrar p7zip-full \
  fdisk mtools xfsprogs dosfstools gparted f2fs-tools exfatprogs gpart udftools gvfs gphoto2 gmtp \
  nfs-common libgsf-1-114 sshfs fuseiso file-roller policykit-1-gnome network-manager timeshift \
  gvfs-backends gvfs-fuse dunst libnotify-bin figlet qimgv l3afpad redshift cpu-x ghostwriter

# X server
apt install -y xorg xbindkeys xdg-utils xdg-user-dirs xdg-user-dirs-gtk \
  xbindkeys xcompmgr numlockx tumbler xbacklight xvkbd xinput

# Xfce Desktop
apt install -y libxfce4ui-utils thunar xfce4-appfinder xfce4-panel xfce4-pulseaudio-plugin \
  xfce4-whiskermenu-plugin xfce4-session xfce4-settings xfce4-terminal xfconf xfdesktop4 \
  xfwm4 adwaita-qt qt5ct \
  
