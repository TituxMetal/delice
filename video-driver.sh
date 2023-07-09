#!/bin/bash

# Generics
apt install -y mesa-va-drivers mesa-utils mesa-vdpau-drivers mesa-vulkan-drivers libvdpau-va-gl1 xserver-xorg-video-vesa

# Intel Graphics
apt install -y libva2 intel-media-va-driver xserver-xorg-video-intel

# Virt Manager
apt install -y spice-vdagent xserver-xorg-video-qxl

# Nvidia
apt install -y xserver-xorg-video-nouveau
