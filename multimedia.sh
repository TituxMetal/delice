#!/bin/bash

# Multimedia

# Players
apt install -y vlc quodlibet shotwell evince playerctl

# Editors
apt install -y gimp inkscape scour vokoscreen-ng

# Burn
apt install -y libdvd-pkg brasero dvdauthor dvdbackup dvd+rw-tools libdvdread8 \
  libdvdnav4 libcdio19 libisoburn1

# Rip/Encode
apt install -y asunder handbrake handbrake-cli

# Audio/Video Codec
apt install -y gstreamer1.0-vaapi gstreamer1.0-tools gstreamer1.0-qt5 gstreamer1.0-qt6 gstreamer1.0-alsa \
  gstreamer1.0-plugins-ugly gstreamer1.0-plugins-good gstreamer1.0-plugins-base gstreamer1.0-plugins-bad \
  gstreamer1.0-nice gstreamer1.0-gtk3 gstreamer1.0-gl gstreamer1.0-fdkaac gstreamer1.0-pulseaudio \
  gstreamer1.0-pipewire libfdk-aac2 fdkaac libvorbis0a libdca0 libwebpmux3 libwebpdemux2 libwebp7 \
  libtheora0 libvpx7 libxvidcore4 x265 x264 ogmtools ffmpeg ffmpegthumbnailer faac libfaad2 lame flac \
  wavpack pavucontrol alsa-utils pulseaudio pipewire gstreamer1.0-pipewire pipewire-alsa pipewire-audio

# Bluetooth
apt install -y bluez bluez-firmware bluez-tools pulseaudio-module-bluetooth blueman

# Video drivers

# Generics
apt install -y mesa-va-drivers mesa-utils mesa-vdpau-drivers mesa-vulkan-drivers \
  libvdpau-va-gl1 xserver-xorg-video-vesa

# Intel Graphics
apt install -y libva2 intel-media-va-driver xserver-xorg-video-intel

# Virt Manager
apt install -y spice-vdagent xserver-xorg-video-qxl

# Nvidia
apt install -y xserver-xorg-video-nouveau nvidia-vaapi-driver
