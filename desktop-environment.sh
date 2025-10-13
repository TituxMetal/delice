#!/bin/bash

# Name: desktop-environment.sh
# Description: Install a complete desktop environment for Debian 13 (Trixie) with multimedia and development tools.
# Author: Titux Metal <tituxmetal[at]lgdweb[dot]fr>
# Url: https://github.com/TituxMetal/delice
# Version: 1.0
# Revision: 2025.10.13
# License: MIT License
# Target: Debian 13 (Trixie)

readonly scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly projectRoot="${scriptDir}"

# Video Driver Packages
declare -a videoDriverPackages
# Video drivers Nvidia See: https://wiki.debian.org/NvidiaGraphicsDrivers
nvidiaDriverPackages="xserver-xorg-video-nouveau nvidia-vaapi-driver"
# Video drivers Intel See: https://wiki.debian.org/GraphicsCard#Intel
intelDriverPackages="libva2 intel-media-va-driver xserver-xorg-video-intel"
# Virtual Machine (kvm) video drivers See: https://wiki.debian.org/KVM
virtualMachineDriverPackages="spice-vdagent xserver-xorg-video-qxl xserver-xorg-video-vesa"
# Video drivers OpenGL See: https://wiki.debian.org/GraphicsCard
genericDriverPackages="mesa-utils xserver-xorg-video-vesa"
# Hardware Video accel See: https://wiki.debian.org/HardwareVideoAcceleration
hdwVideoAccelPackages="mesa-va-drivers mesa-vdpau-drivers vainfo vdpauinfo"

declare -a desktopEnvPackages
checkInstallDesktopXfce=0
desktopEnvironment=""
# Xfce desktop environment See: https://wiki.debian.org/Xfce
desktopXfcePackages="task-xfce-desktop accountsservice slick-greeter"

# Base X.Org and system packages
# See: https://wiki.debian.org/Xorg
baseXorgPackages="xbindkeys xdg-utils xdg-user-dirs xdg-user-dirs-gtk xcompmgr numlockx tumbler xbacklight xvkbd xinput"

# Web browser packages
browserPackages="firefox-esr firefox-esr-l10n-fr"

# System utilities
utilityPackages="fastfetch alacritty rofi pcmanfm libfm-tools libusbmuxd-tools feh dex xarchiver gparted gphoto2 sshfs nfs-common fuseiso file-roller timeshift gvfs gvfs-backends gvfs-fuse dunst libnotify-bin figlet qimgv redshift cpu-x cryptsetup pavucontrol alsa-utils pulseaudio ffmpeg ffmpegthumbnailer rsync"

# Fonts and themes See: https://wiki.debian.org/Fonts
themePackages="lxappearance fonts-recommended fonts-ubuntu fonts-font-awesome fonts-lmodern fonts-terminus papirus-icon-theme gtk-update-icon-cache arc-theme adwaita-qt qt5-style-kvantum"

# Multimedia packages: readers/viewers, editors/capture, rip/encode, burn for images, audio, video
declare -a multimediaPackages
checkInstallMultimediaReaders=0
checkInstallMultimediaEditors=0
checkInstallMultimediaRipencode=0
checkInstallMultimediaBurn=0
multimediaReadersPackages="vlc quodlibet shotwell evince mpd playerctl libdvd-pkg libdvdread-dev libdvdnav-dev libcdio-dev"
multimediaEditorsPackages="gimp inkscape scour"
multimediaRipencodePackages="asunder handbrake handbrake-cli lame ogmtools faac flac x265 x264"
multimediaBurnPackages="brasero dvdauthor dvdbackup dvd+rw-tools libisoburn-dev"
# Audio/Video codec and GStreamer support
audioVideoCodecGst="gstreamer1.0-x gstreamer1.0-libav"

officePackages="seahorse gnupg ghostscript libreoffice-gtk3 libreoffice-l10n-fr libreoffice-help-fr galculator l3afpad ghostwriter libtext-multimarkdown-perl cmark pandoc"

# Development Packages
declare -a developmentPackages
checkInstallDevelopmentToolchain=0
developmentToolchainPackages="build-essential"

bluetoothPackages="bluez bluez-firmware bluez-tools pulseaudio-module-bluetooth blueman"
checkInstallBluetooth=0

# =============================================================================
# SCRIPT CONFIGURATION VARIABLES
# =============================================================================

# Execution mode and behavior flags
promptMode="interactive"        # Controls whether to show interactive prompts
dryRun=0                       # When set to 1, shows what would be done without executing
installTheme=0                 # Flag to install theme packages and sync dotfiles
installOffice=0                # Flag to install office suite packages
enableBluetooth=0              # Flag to install and enable Bluetooth support
needDvdReconfigure=0           # Flag to reconfigure DVD CSS support
enableRunAsRoot=0              # Flag to allow running script as root (not recommended)

# Default selections
selectedDriverProfile="vm"      # Default video driver profile (vm, intel, nvidia, none)
selectedDesktop="xfce"         # Default desktop environment

# CLI override flags - prevent prompts when set via command line
driverCliOverride=0            # Skip driver selection prompt
themeCliOverride=0             # Skip theme installation prompt
officeCliOverride=0            # Skip office suite prompt
multimediaCliOverride=0        # Skip multimedia selection prompt
developmentCliOverride=0       # Skip development tools prompt
bluetoothCliOverride=0         # Skip Bluetooth support prompt

# Dynamic arrays populated during execution
declare -a selectedMultimediaGroups=()  # User-selected multimedia groups
declare -a selectedDevelopmentGroups=() # User-selected development groups
declare -a packagesToInstall=()         # Final list of packages to install
declare -a postInstallTasks=()          # Tasks to execute after package installation
declare -a summaryLines=()              # Summary information for user review

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Display formatted message with green color and borders
# Usage: printMessage "Your message here"
printMessage() {
  local message=$1
  if command -v tput >/dev/null 2>&1; then
    tput setaf 2
  fi
  echo "-------------------------------------------"
  echo "$message"
  echo "-------------------------------------------"
  if command -v tput >/dev/null 2>&1; then
    tput sgr0
  fi
}

# Log warning message to stderr
# Usage: logWarning "Warning message"
logWarning() {
  local message=$1
  echo "WARNING: $message" >&2
}

# Log error message to stderr
# Usage: logError "Error message"
logError() {
  local message=$1
  echo "ERROR: $message" >&2
}

# =============================================================================
# ARRAY MANIPULATION FUNCTIONS
# =============================================================================

# Append multiple items to an array
# Usage: appendPackages arrayName "item1" "item2" "item3"
appendPackages() {
  local -n target=$1
  shift
  local item
  for item in "$@"; do
    target+=("$item")
  done
}

# Add item to array only if it doesn't already exist
# Usage: addUnique arrayName "itemValue"
addUnique() {
  local -n target=$1
  local value=$2
  local item
  for item in "${target[@]}"; do
    if [[ "$item" == "$value" ]]; then
      return
    fi
  done
  target+=("$value")
}

# Remove duplicate items from array while preserving order
# Usage: deduplicateArray arrayName
deduplicateArray() {
  local -n target=$1
  declare -A seen=()
  local item
  local -a unique=()
  for item in "${target[@]}"; do
    if [[ -z "${seen[$item]+set}" ]]; then
      unique+=("$item")
      seen[$item]=1
    fi
  done
  target=("${unique[@]}")
}

# =============================================================================
# ERROR HANDLING AND VALIDATION
# =============================================================================

# Enable strict error handling with detailed error reporting
# Sets up trap to show exact line and command that failed
setupErrorHandling() {
  set -euo pipefail
  trap 'status=$?; echo "Error on line ${LINENO}: ${BASH_COMMAND}" >&2; exit $status' ERR
}

# Ensure script is not run as root user
# The script needs to run as regular user with sudo privileges for proper file ownership
requireUserContext() {
  if [[ $enableRunAsRoot -eq 1 ]]; then
    return
  fi
  if [[ $EUID -eq 0 ]]; then
    logError "Run this script as a regular user with sudo access."
    exit 1
  fi
}

# =============================================================================
# COMMAND LINE PARSING FUNCTIONS
# =============================================================================

# Parse comma-separated values into array, normalizing to lowercase
# Usage: parseCsvIntoArray "item1,item2,item3" targetArray
parseCsvIntoArray() {
  local csv=$1
  local -n result=$2
  IFS=',' read -ra values <<< "$csv"
  local value
  for value in "${values[@]}"; do
    local normalized="${value,,}"
    if [[ -n "$normalized" ]]; then
      addUnique result "$normalized"
    fi
  done
}

# Add line to installation summary for user review
# Usage: addSummary "Package group: package1 package2"
addSummary() {
  local line=$1
  summaryLines+=("$line")
}

# Queue a function to be executed after package installation
# Usage: queuePostInstallTask functionName
queuePostInstallTask() {
  local task=$1
  addUnique postInstallTasks "$task"
}

showHelp() {
  cat <<'EOF'
Usage: desktop-environment.sh [options]

Options:
  --no-prompts                 Disable interactive prompts (use defaults or CLI selections)
  --theme                      Install theme packages and sync dotfiles
  --desktop=<name>             Desktop profile to install (default: xfce)
  --drivers=<profile>          Driver profile: vm, intel, nvidia, none (default: vm)
  --with-office                Install office suite packages
  --with-multimedia            Install all multimedia groups
  --with-multimedia=<list>     Comma-separated multimedia groups (players,editors,burn,ripencode)
  --with-development           Install development toolchain (build-essential)
  --enable-bluetooth           Install Bluetooth stack and enable service
  --as-root                    Run script as root user (not recommended, ONLY for testing purposes)
  --dry-run                    Show planned actions without installing packages
  -h, --help                   Display this help message
EOF
}

# =============================================================================
# PACKAGE SELECTION FUNCTIONS
# =============================================================================

# Select all available multimedia groups (used with --with-multimedia flag)
# Ensures codecs are added last as they're required by other multimedia packages
selectAllMultimediaGroups() {
  addUnique selectedMultimediaGroups "players"
  addUnique selectedMultimediaGroups "editors"
  addUnique selectedMultimediaGroups "burn"
  addUnique selectedMultimediaGroups "ripencode"
  addUnique selectedMultimediaGroups "codecs"
}

# Select all available development groups (used with --with-development flag)
selectAllDevelopmentGroups() {
  addUnique selectedDevelopmentGroups "toolchain"
}

parseArgs() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-prompts)
        promptMode="disabled"
      ;;
      --theme)
        installTheme=1
        themeCliOverride=1
      ;;
      --desktop=*)
        selectedDesktop="${1#*=}"
      ;;
      --drivers=*)
        selectedDriverProfile="${1#*=}"
        driverCliOverride=1
      ;;
      --with-office)
        installOffice=1
        officeCliOverride=1
      ;;
      --with-multimedia)
        selectAllMultimediaGroups
        multimediaCliOverride=1
      ;;
      --with-multimedia=*)
        parseCsvIntoArray "${1#*=}" selectedMultimediaGroups
        multimediaCliOverride=1
      ;;
      --with-development)
        selectAllDevelopmentGroups
        developmentCliOverride=1
      ;;
      --with-development=*)
        parseCsvIntoArray "${1#*=}" selectedDevelopmentGroups
        developmentCliOverride=1
      ;;
      --enable-bluetooth)
        enableBluetooth=1
        bluetoothCliOverride=1
      ;;
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
      --)
        shift
        break
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
# USER INTERACTION FUNCTIONS
# =============================================================================

# Prompt user for yes/no answer with optional default
# Usage: askYesNo "Question? [y/N]" resultVariable "n"
askYesNo() {
  local prompt=$1
  local -n result=$2
  local default=${3:-}
  local answer
  while true; do
    read -rp "$prompt " answer
    if [[ -z "$answer" && -n "$default" ]]; then
      answer="$default"
    fi
    case "$answer" in
      y|Y|yes|YES)
        result=1
        return
      ;;
      n|N|no|NO)
        result=0
        return
      ;;
      *)
        echo "Please answer yes or no."
      ;;
    esac
  done
}

# Prompt user to select video driver profile
# Skipped if driver was specified via command line (--drivers=profile)
promptDriverProfile() {
  if [[ $driverCliOverride -eq 1 ]]; then
    return
  fi
  printMessage "Select video driver profile"
  select option in "Virtual machine (SPICE/QXL)" "Intel graphics" "Nvidia graphics" "Skip"; do
    case $REPLY in
      1)
        selectedDriverProfile="vm"
        return
      ;;
      2)
        selectedDriverProfile="intel"
        return
      ;;
      3)
        selectedDriverProfile="nvidia"
        return
      ;;
      4)
        selectedDriverProfile="none"
        return
      ;;
      *)
        echo "Choose a valid option."
      ;;
    esac
  done
}

# Prompt user about theme installation
# Skipped if theme flag was specified via command line (--theme)
promptThemeOption() {
  if [[ $themeCliOverride -eq 1 ]]; then
    return
  fi
  askYesNo "Install theme packages and sync dotfiles? [y/N]" installTheme "n"
}

promptMultimediaGroups() {
  if [[ $multimediaCliOverride -eq 1 ]]; then
    return
  fi
  local enableMultimedia=0
  askYesNo "Add multimedia extras (players, editors, etc.)? [y/N]" enableMultimedia "n"
  if [[ $enableMultimedia -eq 0 ]]; then
    return
  fi
  printMessage "Select multimedia groups (choose multiple, finish with Done)"
  local continueSelection=1
  while [[ $continueSelection -eq 1 ]]; do
    select option in "Players" "Editors" "Disc burning" "Rip/Encode" "Done"; do
      case $REPLY in
        1)
          addUnique selectedMultimediaGroups "players"
          echo "Added multimedia players."
          break
        ;;
        2)
          addUnique selectedMultimediaGroups "editors"
          echo "Added multimedia editors."
          break
        ;;
        3)
          addUnique selectedMultimediaGroups "burn"
          echo "Added disc burning tools."
          break
        ;;
        4)
          addUnique selectedMultimediaGroups "ripencode"
          echo "Added rip/encode utilities."
          break
        ;;
        5)
          continueSelection=0
          break
        ;;
        *)
          echo "Choose a valid option."
        ;;
      esac
    done
  done
}

# Prompt user about office suite installation
# Skipped if office flag was specified via command line (--with-office)
promptOfficeSuite() {
  if [[ $officeCliOverride -eq 1 ]]; then
    return
  fi
  askYesNo "Install office suite packages? [y/N]" installOffice "n"
}

promptDevelopmentGroups() {
  if [[ $developmentCliOverride -eq 1 ]]; then
    return
  fi
  local enableDevelopment=0
  askYesNo "Install development toolsets? [y/N]" enableDevelopment "n"
  if [[ $enableDevelopment -eq 0 ]]; then
    return
  fi
  addUnique selectedDevelopmentGroups "toolchain"
  echo "Added development toolchain."
}

# Prompt user about Bluetooth support installation
# Skipped if Bluetooth flag was specified via command line (--enable-bluetooth)
promptBluetoothSupport() {
  if [[ $bluetoothCliOverride -eq 1 ]]; then
    return
  fi
  askYesNo "Install Bluetooth support? [y/N]" enableBluetooth "n"
}

maybePromptUser() {
  if [[ "$promptMode" == "disabled" ]]; then
    return
  fi
  promptDriverProfile
  promptThemeOption
  promptMultimediaGroups
  promptOfficeSuite
  promptDevelopmentGroups
  promptBluetoothSupport
}

normalizeMultimediaSelection() {
  if [[ ${#selectedMultimediaGroups[@]} -eq 0 ]]; then
    return
  fi
  addUnique selectedMultimediaGroups "codecs"
}

validateConfiguration() {
  case $selectedDesktop in
    xfce)
      ;;
    *)
      logError "Unsupported desktop profile: $selectedDesktop"
      exit 1
      ;;
  esac

  case $selectedDriverProfile in
    vm|intel|nvidia|none)
      ;;
    *)
      logError "Unsupported driver profile: $selectedDriverProfile"
      exit 1
      ;;
  esac

  local group
  for group in "${selectedMultimediaGroups[@]}"; do
    case $group in
      players|editors|burn|ripencode|codecs)
        ;;
      *)
        logError "Unknown multimedia group: $group"
        exit 1
        ;;
    esac
  done

  for group in "${selectedDevelopmentGroups[@]}"; do
    case $group in
      toolchain)
        ;;
      *)
        logError "Unknown development group: $group"
        exit 1
        ;;
    esac
  done
}

buildPackagePlan() {
  packagesToInstall=()
  summaryLines=()
  postInstallTasks=()
  needDvdReconfigure=0

  local driverSummary="Drivers: skipped"
  if [[ "$selectedDriverProfile" != "none" ]]; then
    case $selectedDriverProfile in
      vm)
        packagesToInstall+=($virtualMachineDriverPackages)
        driverSummary="Drivers (vm): ${virtualMachineDriverPackages}"
        ;;
      intel)
        packagesToInstall+=($intelDriverPackages)
        driverSummary="Drivers (intel): ${intelDriverPackages}"
        ;;
      nvidia)
        packagesToInstall+=($nvidiaDriverPackages)
        driverSummary="Drivers (nvidia): ${nvidiaDriverPackages}"
        ;;
    esac
    if [[ -n "$hdwVideoAccelPackages" ]]; then
      packagesToInstall+=($hdwVideoAccelPackages)
    fi
  fi
  addSummary "$driverSummary"

  case $selectedDesktop in
    xfce)
      packagesToInstall+=($desktopXfcePackages)
      addSummary "Desktop (xfce): ${desktopXfcePackages}"
      ;;
  esac
  queuePostInstallTask configureLightdm

  packagesToInstall+=($baseXorgPackages)
  addSummary "X.Org utilities: ${baseXorgPackages}"

  packagesToInstall+=($utilityPackages)
  addSummary "Utilities: ${utilityPackages}"

  packagesToInstall+=($browserPackages)
  addSummary "Browsers: ${browserPackages}"

  local themeSummary="Themes: skipped"
  if [[ $installTheme -eq 1 ]]; then
    packagesToInstall+=($themePackages)
    themeSummary="Themes: ${themePackages}"
    queuePostInstallTask installThemeAssets
  fi
  addSummary "$themeSummary"

  local multimediaGroup
  for multimediaGroup in "${selectedMultimediaGroups[@]}"; do
    case $multimediaGroup in
      players)
        packagesToInstall+=($multimediaReadersPackages)
        addSummary "Multimedia (players): ${multimediaReadersPackages}"
        needDvdReconfigure=1
        ;;
      editors)
        packagesToInstall+=($multimediaEditorsPackages)
        addSummary "Multimedia (editors): ${multimediaEditorsPackages}"
        ;;
      burn)
        packagesToInstall+=($multimediaBurnPackages)
        addSummary "Multimedia (burn): ${multimediaBurnPackages}"
        ;;
      ripencode)
        packagesToInstall+=($multimediaRipencodePackages)
        addSummary "Multimedia (ripencode): ${multimediaRipencodePackages}"
        ;;
      codecs)
        packagesToInstall+=($audioVideoCodecGst)
        addSummary "Multimedia (codecs): ${audioVideoCodecGst}"
        ;;
    esac
  done

  local officeSummary="Office suite: skipped"
  if [[ $installOffice -eq 1 ]]; then
    packagesToInstall+=($officePackages)
    officeSummary="Office suite: ${officePackages}"
  fi
  addSummary "$officeSummary"

  local devGroup
  for devGroup in "${selectedDevelopmentGroups[@]}"; do
    case $devGroup in
      toolchain)
        packagesToInstall+=($developmentToolchainPackages)
        addSummary "Development (toolchain): ${developmentToolchainPackages}"
        ;;
    esac
  done

  local bluetoothSummary="Bluetooth: skipped"
  if [[ $enableBluetooth -eq 1 ]]; then
    packagesToInstall+=($bluetoothPackages)
    bluetoothSummary="Bluetooth: ${bluetoothPackages}"
    queuePostInstallTask enableBluetoothServices
  fi
  addSummary "$bluetoothSummary"

  if [[ $needDvdReconfigure -eq 1 ]]; then
    queuePostInstallTask configureDvdcss
  fi

  deduplicateArray packagesToInstall
}

printSummary() {
  printMessage "Installation Summary"
  local line
  for line in "${summaryLines[@]}"; do
    echo "- $line"
  done
  echo
  echo "Total packages to install: ${#packagesToInstall[@]}"
  if [[ ${#packagesToInstall[@]} -gt 0 ]]; then
    echo "Packages: ${packagesToInstall[*]}"
  fi
}

# =============================================================================
# INSTALLATION FUNCTIONS
# =============================================================================

# Install all selected packages using APT package manager
# Updates package index and installs packages non-interactively
installPackages() {
  if [[ ${#packagesToInstall[@]} -eq 0 ]]; then
    logWarning "No packages selected for installation."
    return
  fi
  printMessage "Updating APT package index"
  sudo apt update
  printMessage "Installing packages"
  sudo DEBIAN_FRONTEND=noninteractive apt install -y "${packagesToInstall[@]}"
}

# =============================================================================
# POST-INSTALL CONFIGURATION FUNCTIONS
# =============================================================================

# Configure LightDM display manager settings
# See: https://wiki.debian.org/LightDM
configureLightdm() {
  printMessage "Configuring LightDM"
  sudo mkdir -p /etc/lightdm/lightdm.conf.d
  local configFile=/etc/lightdm/lightdm.conf.d/user.conf
  sudo tee "$configFile" >/dev/null <<'EOF'
[Seat:*]
greeter-hide-users=false
greeter-show-manual-login=true
# display-setup-script=xrandr --output "$(xrandr | grep " connected" | awk '{print $1}')" --mode 1920x1200
EOF
}

# Install theme assets and synchronize desktop configuration
# Copies desktop configuration files and wallpapers to user's home directory
installThemeAssets() {
  printMessage "Syncing theme and desktop configuration"
  mkdir -p "$HOME/.config"
  if [[ -d "${projectRoot}/.config" ]]; then
    rsync -rtv --delete "${projectRoot}/.config/" "$HOME/.config/"
  fi
  if [[ -d "${projectRoot}/wallpapers" ]]; then
    mkdir -p "$HOME/wallpapers"
    rsync -rtv --delete "${projectRoot}/wallpapers/" "$HOME/wallpapers/"
  fi
}

# Configure DVD CSS decryption support
# See: https://wiki.debian.org/DVD
configureDvdcss() {
  printMessage "Configuring libdvd-pkg"
  sudo DEBIAN_FRONTEND=noninteractive dpkg-reconfigure libdvd-pkg
}

# Enable Bluetooth systemd service
# See: https://wiki.debian.org/BluetoothUser
enableBluetoothServices() {
  printMessage "Enabling Bluetooth service"
  sudo systemctl enable bluetooth.service
}

# Execute all queued post-installation configuration tasks
# Tasks are functions that need to run after packages are installed
executePostInstallTasks() {
  local task
  for task in "${postInstallTasks[@]}"; do
    "$task"
  done
}

# =============================================================================
# MAIN EXECUTION FUNCTION
# =============================================================================

# Main function that orchestrates the entire desktop environment installation process
# 1. Sets up error handling and validates execution context
# 2. Parses command line arguments and prompts user for missing options
# 3. Validates configuration and builds package installation plan
# 4. Shows summary and executes installation (unless dry-run mode)
# 5. Runs post-installation configuration tasks
main() {
  setupErrorHandling
  parseArgs "$@"
  requireUserContext
  maybePromptUser
  normalizeMultimediaSelection
  validateConfiguration
  buildPackagePlan
  printSummary
  if [[ $dryRun -eq 1 ]]; then
    logWarning "Dry run enabled; skipping installation."
    return
  fi
  installPackages
  executePostInstallTasks
  printMessage "Desktop environment setup complete."
}

time main "$@"
