#!/bin/bash

# Video drivers: please uncomment Intel or Nvidia if necessary

# Generics
apt install -y mesa-va-drivers mesa-utils mesa-vdpau-drivers mesa-vulkan-drivers libvdpau-va-gl1 xserver-xorg-video-vesa

# Intel Graphics
# apt install -y libva2 intel-media-va-driver xserver-xorg-video-intel

# Virt Manager
apt install -y spice-vdagent xserver-xorg-video-qxl

# Nvidia
# apt install -y xserver-xorg-video-nouveau nvidia-vaapi-driver

# Multimedia: please uncomment what you need

# Players
apt install -y vlc quodlibet shotwell evince mpd playerctl

# Editors
# apt install -y gimp inkscape scour vokoscreen-ng

# Burn
# apt install -y libdvd-pkg brasero dvdauthor dvdbackup dvd+rw-tools libdvdread8 libdvdnav4 libcdio19 libisoburn1

# Rip/Encode
# apt install -y asunder handbrake handbrake-cli

# Gstreamer 
apt install -y gstreamer1.0-vaapi gstreamer1.0-alsa gstreamer1.0-plugins-ugly gstreamer1.0-plugins-good gstreamer1.0-plugins-base \
  gstreamer1.0-plugins-bad gstreamer1.0-nice gstreamer1.0-gtk3 gstreamer1.0-gl gstreamer1.0-fdkaac gstreamer1.0-x gstreamer1.0-libav

# Audio/Video Codec
apt install -y libfdk-aac2 fdkaac libvorbis0a libdca0 libwebpmux3 libwebpdemux2 libwebp7 libtheora0 libvpx7 libxvidcore4 x265 x264 \
ogmtools ffmpeg ffmpegthumbnailer faac libfaad2 lame flac wavpack pavucontrol alsa-utils pulseaudio

# Bluetooth
# apt install -y bluez bluez-firmware bluez-tools pulseaudio-module-bluetooth blueman

# Themes and fonts
apt install -y lxappearance fonts-recommended fonts-font-awesome fonts-terminus papirus-icon-theme gtk-update-icon-cache arc-theme

# Utils
apt install -y neofetch alacritty rofi pcmanfm feh galculator dex xarchiver gparted gvfs gphoto2 gmtp nfs-common libgsf-1-114 \
  sshfs fuseiso file-roller policykit-1-gnome network-manager timeshift gvfs-backends gvfs-fuse dunst libnotify-bin figlet \
  qimgv l3afpad redshift cpu-x ghostwriter

# Web Browser
apt install -y torbrowser-launcher firefox-esr firefox-esr-l10n-fr fonts-lmodern libcanberra0 libcanberra-gtk0

# Office
apt install -y gpa gnupg ghostscript libreoffice-gtk3 libreoffice-l10n-fr libreoffice-help-fr

# X server
apt install -y xbindkeys xdg-utils xdg-user-dirs xdg-user-dirs-gtk xbindkeys xcompmgr numlockx tumbler xbacklight xvkbd xinput

# Xfce Desktop
# apt install -y task-xfce-desktop xfce4-mpc-plugin xfce4-pulseaudio-plugin xfce4-whiskermenu-plugin adwaita-qt qt5ct

# Re-enable Ly as display manager and remove lightdm
# systemctl disable display-manager.service && apt remove --purge -y lightdm lightdm-gtk-greeter && apt -y autoremove && systemctl enable ly
