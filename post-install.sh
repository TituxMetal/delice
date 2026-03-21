#!/bin/bash

# Name: post-install.sh
# Description: Base system configuration for Debian 13 (Trixie) — packages, services, firewall, zram, dotfiles.
# Author: Titux Metal <tituxmetal[at]lgdweb[dot]fr>
# Url: https://github.com/TituxMetal/delice
# License: MIT License
# Target: Debian 13 (Trixie)

readonly scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly projectRoot="${scriptDir}"

# shellcheck source=lib/common.sh
source "${scriptDir}/lib/common.sh"

# =============================================================================
# SCRIPT CONFIGURATION
# =============================================================================

dryRun=0
enableRunAsRoot=0

# =============================================================================
# PACKAGE LISTS
# =============================================================================

systemPackages="vim htop git bash-completion rsync curl wget chrony modemmanager ufw iwd bind9-dnsutils libnss-mdns avahi-daemon"
developmentPackages="build-essential libpam0g-dev libxcb-xkb-dev"
filesystemPackages="fdisk mtools xfsprogs dosfstools zip unzip unrar p7zip-full f2fs-tools exfatprogs gpart udftools"
monitoringPackages="netselect-apt lynis duf lm-sensors systemd-zram-generator"

enabledServices="chrony ssh avahi-daemon fstrim.timer ufw iwd ModemManager"

# =============================================================================
# COMMAND LINE PARSING
# =============================================================================

showHelp() {
  cat <<'EOF'
Usage: post-install.sh [options]

Options:
  --as-root     Run script as root user (not recommended, ONLY for testing)
  --dry-run     Show planned actions without executing
  -h, --help    Display this help message
EOF
}

parseArgs() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --as-root)
        enableRunAsRoot=1
        logWarning "Running as root is not recommended. Proceeding for testing purposes."
        ;;
      --dry-run)
        dryRun=1
        ;;
      -h|--help)
        showHelp
        exit 0
        ;;
      *)
        logError "Unknown option: $1"
        exit 1
        ;;
    esac
    shift
  done
}

# =============================================================================
# INSTALLATION FUNCTIONS
# =============================================================================

updateSourcesList() {
  printMessage "Updating APT sources to Trixie"
  sudo cp -v /etc/apt/sources.list /etc/apt/sources.list.bak
  sudo cp -v "${projectRoot}/sources.list" /etc/apt/sources.list
}

upgradeSystem() {
  printMessage "Running full system upgrade"
  sudo apt update && sudo apt upgrade -y && sudo apt dist-upgrade -y
}

installPackages() {
  printMessage "Installing base packages"
  sudo apt install -y $systemPackages $developmentPackages $filesystemPackages $monitoringPackages
}

enableServices() {
  printMessage "Enabling system services"
  sudo systemctl enable $enabledServices
}

configureTimezone() {
  printMessage "Configuring timezone and NTP"
  sudo timedatectl set-timezone Europe/Paris --adjust-system-clock
  sudo timedatectl set-ntp yes
}

configureFirewall() {
  printMessage "Configuring UFW firewall"
  sudo ufw default deny incoming
  sudo ufw limit ssh
  sudo ufw default allow outgoing
}

configureZram() {
  printMessage "Configuring zram swap"
  sudo tee /etc/systemd/zram-generator.conf >/dev/null <<'ZRAMEOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
ZRAMEOF

  sudo mkdir -pv /etc/sysctl.d

  sudo tee /etc/sysctl.d/99-vm-zram-parameters.conf >/dev/null <<'SYSCTLEOF'
vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0
SYSCTLEOF

  sudo systemctl daemon-reload
  sudo systemctl start /dev/zram0
  sudo zramctl
}

installDotfiles() {
  printMessage "Installing dotfiles"

  local dotfile
  for dotfile in "${projectRoot}"/dotfiles/.bash_profile "${projectRoot}"/dotfiles/.bashrc "${projectRoot}"/dotfiles/.colorrc "${projectRoot}"/dotfiles/.profile; do
    if [[ -f "$dotfile" ]]; then
      cp -v "$dotfile" "$HOME/"
    fi
  done

  ln -sf "$HOME/.profile" "$HOME/.xsessionrc"

  printMessage "Installing root dotfiles"
  local rootDotfile
  for rootDotfile in "${projectRoot}"/dotfiles/root/.bash_profile "${projectRoot}"/dotfiles/root/.bashrc "${projectRoot}"/dotfiles/root/.colorrc "${projectRoot}"/dotfiles/root/.profile; do
    if [[ -f "$rootDotfile" ]]; then
      sudo cp -v "$rootDotfile" /root/
    fi
  done
}

# =============================================================================
# MAIN
# =============================================================================

main() {
  setupErrorHandling
  parseArgs "$@"
  requireUserContext

  if [[ $dryRun -eq 1 ]]; then
    printMessage "Dry run — planned actions"
    echo "- Update sources.list to Trixie"
    echo "- Full system upgrade"
    echo "- Install: $systemPackages"
    echo "- Install: $developmentPackages"
    echo "- Install: $filesystemPackages"
    echo "- Install: $monitoringPackages"
    echo "- Enable services: $enabledServices"
    echo "- Configure timezone: Europe/Paris"
    echo "- Configure firewall: deny incoming, limit ssh, allow outgoing"
    echo "- Configure zram swap"
    echo "- Install dotfiles"
    logWarning "Dry run enabled; no changes made."
    return
  fi

  updateSourcesList
  upgradeSystem
  installPackages
  enableServices
  configureTimezone
  configureFirewall
  configureZram
  installDotfiles

  printMessage "Post-install setup complete."
}

time main "$@"
