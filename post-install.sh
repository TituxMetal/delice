#!/bin/bash


apt install -y vim htop git bash-completion rsync curl wget \
  chrony modemmanager ufw iwd dnsutils libnss-mdns avahi-daemon \
  build-essential libpam0g-dev libxcb-xkb-dev \
  netselect-apt lynis duf systemd-zram-generator

systemctl enable chrony sshd avahi-daemon fstrim.timer ufw iwd ModemManager systemd-resolved

# Setup time
timedatectl set-timezone Europe/Paris --adjust-system-clock
timedatectl set-ntp yes

# Setup Ufw firewall
ufw default deny incoming && ufw allow ssh && ufw default allow outgoing

# Install and setup Ly display manager
git clone --recurse-submodules https://github.com/fairyglade/ly && cd ly
make && make install installsystemd

systemctl enable ly.service && systemctl disable getty@tty2.service
