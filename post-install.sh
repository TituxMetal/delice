#!/bin/bash

sudo apt install -y vim htop git bash-completion rsync curl wget \
  build-essential libpam0g-dev libxcb-xkb-dev \
  netselect-apt lynis duf systemd-zram-generator

git clone --recurse-submodules https://github.com/fairyglade/ly && cd ly
make && make install installsystemd

systemctl enable ly.service && systemctl disable getty@tty2.service
