#!/bin/bash

# Run this script as regular user
sudo apt install -y vim htop git bash-completion rsync curl wget chrony modemmanager ufw iwd dnsutils libnss-mdns avahi-daemon \
  build-essential libpam0g-dev libxcb-xkb-dev fdisk mtools xfsprogs dosfstools zip unzip unrar p7zip-full f2fs-tools exfatprogs \
  gpart udftools netselect-apt lynis duf systemd-zram-generator

sudo systemctl enable chrony ssh avahi-daemon fstrim.timer ufw iwd ModemManager

# Setup time
sudo timedatectl set-timezone Europe/Paris --adjust-system-clock
sudo timedatectl set-ntp yes

# Setup Ufw firewall
sudo ufw default deny incoming && ufw allow ssh && ufw default allow outgoing

# Install and setup Ly display manager
# git clone --recurse-submodules https://github.com/fairyglade/ly && cd ly
# make && make install installsystemd

# systemctl enable ly.service && systemctl disable getty@tty2.service

# Add dot files to regular user
cp -v dotfiles/.* $HOME/
ln -s .profile .xsessionrc

# Add dot files to root user
sudo -s cp -v dotfiles/root/.* /root/
