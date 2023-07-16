#!/bin/bash

# Run these commands with root user

# Video drivers: please uncomment Intel or Nvidia if necessary

# Generics
apt install -y spice-vdagent xserver-xorg-video-qxl xserver-xorg-video-vesa

# Intel Graphics
# apt install -y libva2 intel-media-va-driver xserver-xorg-video-intel

# Nvidia
# apt install -y xserver-xorg-video-nouveau nvidia-vaapi-driver

# Xfce desktop
apt install -y task-xfce-desktop accountsservice slick-greeter

# Pre fill default user in lightdm

``` bash
mkdir -p /etc/lightdm/lightdm.conf.d && touch /etc/lightdm/lightdm.conf.d/auto-user.conf \
  && cat > /etc/lightdm/lightdm.conf.d/auto-user.conf<< EOF
[SeatDefaults]
greeter-hide-users=false
greeter-show-manual-login=true
EOF
```

# X server utilities
apt install -y xbindkeys xdg-utils xdg-user-dirs xdg-user-dirs-gtk xbindkeys xcompmgr numlockx tumbler xbacklight xvkbd xinput

# Themes and fonts
apt install -y lxappearance fonts-recommended fonts-ubuntu fonts-font-awesome fonts-lmodern fonts-terminus \
  papirus-icon-theme gtk-update-icon-cache arc-theme adwaita-qt qt5-style-kvantum

# Web Browser
apt install -y torbrowser-launcher firefox-esr firefox-esr-l10n-fr

# Office Tools
apt install -y gpa gnupg ghostscript libreoffice-gtk3 libreoffice-l10n-fr libreoffice-help-fr galculator l3afpad ghostwriter

# Other Utils
apt install -y neofetch alacritty rofi pcmanfm libfm-tools libusbmuxd-tools feh dex xarchiver gparted gphoto2 sshfs nfs-common fuseiso \
  file-roller timeshift gvfs gvfs-backends gvfs-fuse dunst libnotify-bin figlet qimgv redshift cpu-x cryptsetup policykit-1-gnome \
  pavucontrol alsa-utils pulseaudio ffmpeg ffmpegthumbnailer

# Multimedia: please uncomment what you need
# Gstreamer 
apt install -y gstreamer1.0-x gstreamer1.0-libav

# Players
apt install -y vlc quodlibet shotwell evince mpd playerctl x265 x264 libdvd-pkg libdvdread8 libdvdnav4 libcdio19

# Download libdvdcss2 source files
sudo dpkg-reconfigure libdvd-pkg

# Editors
apt install -y gimp inkscape scour

# Burn
# apt install -y brasero dvdauthor dvdbackup dvd+rw-tools libisoburn1

# Rip/Encode
# apt install -y asunder handbrake handbrake-cli lame ogmtools faac flac x265 x264

# Bluetooth
# apt install -y bluez bluez-firmware bluez-tools pulseaudio-module-bluetooth blueman

# Re-enable Ly as display manager and remove lightdm
# systemctl disable display-manager.service && apt remove --purge -y lightdm lightdm-gtk-greeter && apt -y autoremove && systemctl enable ly
