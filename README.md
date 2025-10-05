# DELICE

**D**ebian **L**inux **I**nstall **C**ustom **E**asy

Automated installation and configuration scripts for Debian with XFCE desktop environment.

## Overview

DELICE provides a reproducible way to set up a customized Debian system. It consists of installation
scripts, configuration files, and an automated testing framework using QEMU/KVM.

## Repository Structure

```treeview
delice/
├── post-install.sh           # Base system setup
├── desktop-environment.sh    # XFCE desktop installation
├── test-vm.sh               # Automated VM testing
├── sources.list             # Debian Trixie sources
├── .config/                 # Application configs (alacritty, fastfetch, xfce4, etc.)
├── dotfiles/                # Shell dotfiles
└── wallpapers/              # Desktop backgrounds
```

## Installation Scripts

### post-install.sh

Base system configuration script that:

- Updates Debian sources from Bookworm to Trixie
- Installs essential packages and development tools
- Configures system services (chrony, ufw, iwd, ModemManager)
- Sets up firewall rules (deny incoming except SSH)
- Configures timezone (Europe/Paris) and NTP
- Enables system services: chrony, ssh, avahi-daemon, fstrim.timer, ufw, iwd, ModemManager

**Key packages installed:**

- System: vim, htop, git, bash-completion, rsync, curl, wget, chrony, ufw, iwd
- Development: build-essential, libpam0g-dev, libxcb-xkb-dev
- Filesystem: fdisk, mtools, xfsprogs, dosfstools, f2fs-tools, exfatprogs, zip, unzip, p7zip-full
- Monitoring: duf, lm-sensors, lynis, systemd-zram-generator

### desktop-environment.sh

XFCE desktop environment setup that:

- Installs XFCE desktop (task-xfce-desktop)
- Configures LightDM with Slick Greeter
- Installs video drivers (SPICE/QXL for VMs, optional Intel/Nvidia)
- Sets up essential GUI applications
- Installs and configures fonts (Nerd Fonts, Font Awesome)
- Copies dotfiles and configurations to user home directory

**Desktop applications installed:**

- Browser: Firefox ESR
- Office: LibreOffice
- Utilities: pcmanfm, xarchiver, gparted, seahorse
- Terminal: alacritty, fastfetch
- Launcher: rofi
- Media: gstreamer plugins

### test-vm.sh

Automated testing script for validating installation scripts in a VM environment.

**Features:**

- Creates snapshot from base Debian image
- Injects installation scripts into VM disk
- Runs scripts automatically on VM boot
- Captures full installation logs
- Validates successful completion
- Automatic cleanup on exit

**Usage:**

```bash
./test-vm.sh              # Test post-install.sh only
./test-vm.sh --desktop    # Test both scripts
```

**Requirements:**

- QEMU/KVM with libvirt
- virt-install, virt-customize, virt-cat tools
- Base Debian image at `/home/titux/virt-manager/disk/debian-stable-base.qcow2`

**Test results:** Saved to `test-results-YYYYMMDD-HHMMSS.log`

## Quick Start

### Manual Installation

```bash
git clone <repository-url>
cd delice

# Install base system
./post-install.sh

# Install desktop environment (optional)
./desktop-environment.sh
```

### Testing Before Installation

```bash
# Test in VM before running on real system
./test-vm.sh --desktop
```

## Configuration Files

The repository includes pre-configured dotfiles and settings:

- **Alacritty**: Terminal emulator configuration (`.config/alacritty/`)
- **Fastfetch**: System information display (`.config/fastfetch/`)
- **XFCE4**: Desktop settings, panel, keyboard shortcuts (`.config/xfce4/`)
- **GTK**: Theme and file chooser settings (`.config/gtk-3.0/`)
- **Rofi**: Application launcher (`.config/rofi/`)
- **htop**: System monitor (`.config/htop/`)

These configurations are automatically copied to `~/.config/` by
[desktop-environment.sh](desktop-environment.sh).

## System Requirements

- Debian 12 (Bookworm) or Debian 13 (Trixie) base installation
- Internet connection
- Sudo privileges
- Minimum 4GB disk space (8GB+ recommended with desktop)

## License

See [LICENSE](LICENSE)
