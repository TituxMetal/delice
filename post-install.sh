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

  # Make a backup of sources.list file
  sudo cp -v /etc/apt/sources.list /etc/apt/sources.list.bak

  # Add the new sources.list file
  sudo cp -v sources.list /etc/apt/sources.list

  # Make a full system upgrade
  sudo apt update && sudo apt upgrade && sudo apt dist-upgrade

  # Run this script as regular user
  sudo apt install -y vim htop git bash-completion rsync curl wget chrony modemmanager ufw iwd dnsutils libnss-mdns avahi-daemon \
    build-essential libpam0g-dev libxcb-xkb-dev fdisk mtools xfsprogs dosfstools zip unzip unrar p7zip-full f2fs-tools exfatprogs \
    gpart udftools netselect-apt lynis duf systemd-zram-generator

  sudo systemctl enable chrony ssh avahi-daemon fstrim.timer ufw iwd ModemManager

  # Setup time
  sudo timedatectl set-timezone Europe/Paris --adjust-system-clock
  sudo timedatectl set-ntp yes

  # Setup Ufw firewall
  sudo ufw default deny incoming && sudo ufw allow ssh && sudo ufw default allow outgoing

  # Install and setup Ly display manager
  # git clone --recurse-submodules https://github.com/fairyglade/ly && cd ly
  # make && make install installsystemd

  # systemctl enable ly.service && systemctl disable getty@tty2.service

  # Add dot files to regular user
  cp -v dotfiles/.* $HOME/
  ln -s .profile .xsessionrc

  # Add dot files to root user
  sudo -s cp -v dotfiles/root/.* /root/

}

time main

exit 0
