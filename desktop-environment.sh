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

# shellcheck source=lib/common.sh
source "${scriptDir}/lib/common.sh"

# =============================================================================
# PACKAGE LISTS
# =============================================================================

# Video drivers — See: https://wiki.debian.org/NvidiaGraphicsDrivers
nvidiaDriverPackages="xserver-xorg-video-nouveau nvidia-vaapi-driver"
# Video drivers Intel — See: https://wiki.debian.org/GraphicsCard#Intel
intelDriverPackages="libva2 intel-media-va-driver xserver-xorg-video-intel"
# Virtual Machine (kvm) video drivers — See: https://wiki.debian.org/KVM
virtualMachineDriverPackages="spice-vdagent xserver-xorg-video-qxl xserver-xorg-video-vesa"
# Hardware Video accel — See: https://wiki.debian.org/HardwareVideoAcceleration
hdwVideoAccelPackages="mesa-va-drivers mesa-vdpau-drivers vainfo vdpauinfo"

# Xfce desktop environment — See: https://wiki.debian.org/Xfce
desktopXfcePackages="task-xfce-desktop accountsservice slick-greeter"

# Base X.Org and system packages
# See: https://wiki.debian.org/Xorg
baseXorgPackages="xbindkeys xdg-utils xdg-user-dirs xdg-user-dirs-gtk xcompmgr numlockx tumbler xbacklight xvkbd xinput"

# Web browser packages
browserPackages="firefox-esr firefox-esr-l10n-fr"
bravePackages="brave-browser"
migrationDeps="python3-secretstorage python3-cryptography"

# System utilities
utilityPackages="fastfetch alacritty rofi pcmanfm libfm-tools libusbmuxd-tools feh dex xarchiver gparted gphoto2 sshfs nfs-common fuseiso file-roller timeshift gvfs gvfs-backends gvfs-fuse dunst libnotify-bin figlet qimgv redshift cpu-x cryptsetup pavucontrol alsa-utils pulseaudio ffmpeg ffmpegthumbnailer rsync seahorse gnupg"

# Fonts and themes See: https://wiki.debian.org/Fonts
themePackages="lxappearance fonts-recommended fonts-ubuntu fonts-font-awesome fonts-lmodern fonts-terminus papirus-icon-theme gtk-update-icon-cache arc-theme adwaita-qt qt5-style-kvantum"

# Multimedia packages: readers/viewers, editors/capture, rip/encode, burn
multimediaReadersPackages="vlc quodlibet shotwell evince mpd playerctl libdvd-pkg libdvdread-dev libdvdnav-dev libcdio-dev"
multimediaEditorsPackages="gimp inkscape scour"
multimediaRipencodePackages="asunder handbrake handbrake-cli lame ogmtools faac flac x265 x264"
multimediaBurnPackages="brasero dvdauthor dvdbackup dvd+rw-tools libisoburn-dev"
# Audio/Video codec and GStreamer support
audioVideoCodecGst="gstreamer1.0-x gstreamer1.0-libav"

officePackages="ghostscript libreoffice-gtk3 libreoffice-l10n-fr libreoffice-help-fr galculator l3afpad ghostwriter libtext-multimarkdown-perl cmark pandoc"

# Development Packages
developmentToolchainPackages="build-essential"

bluetoothPackages="bluez bluez-firmware bluez-tools pulseaudio-module-bluetooth blueman"

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
backupConfigs=0                # Flag to backup user configs before installing
skipBackup=0                   # Flag to skip backup prompt for existing installations
installBrave=0                 # Flag to install Brave browser
migrateChrome=0                # Flag to migrate Chrome data to Brave
installRustdesk=0              # Flag to install Rustdesk remote access
rustdeskServer="laura.lgdweb.ovh"   # Rustdesk server ID and relay address
rustdeskKey="QrrSBjpl1L1nbJNqjCkNfrKsSOSxYappCZavaPp1db8="  # Rustdesk server public key
rustdeskPassword=""            # Rustdesk permanent password (set via CLI)
enableRunAsRoot=0              # Flag to allow running script as root (not recommended)

# Default selections
selectedDriverProfile="vm"      # Default video driver profile (vm, intel, nvidia, none)
selectedDesktop="xfce"         # Default desktop environment
defaultWallpaper="rod-long-8i7F4BadwNo-unsplash.jpg"  # Default wallpaper from wallpapers/

# CLI override flags - prevent prompts when set via command line
driverCliOverride=0            # Skip driver selection prompt
themeCliOverride=0             # Skip theme installation prompt
officeCliOverride=0            # Skip office suite prompt
multimediaCliOverride=0        # Skip multimedia selection prompt
developmentCliOverride=0       # Skip development tools prompt
bluetoothCliOverride=0         # Skip Bluetooth support prompt
backupCliOverride=0            # Skip backup prompt
braveCliOverride=0             # Skip Brave browser prompt
migrateCliOverride=0           # Skip Chrome migration prompt
rustdeskCliOverride=0          # Skip Rustdesk prompt

# Dynamic arrays populated during execution
declare -a selectedMultimediaGroups=()  # User-selected multimedia groups
declare -a selectedDevelopmentGroups=() # User-selected development groups
declare -a packagesToInstall=()         # Final list of packages to install
declare -a postInstallTasks=()          # Tasks to execute after package installation
declare -a summaryLines=()              # Summary information for user review

# =============================================================================
# ARRAY MANIPULATION FUNCTIONS
# =============================================================================

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
# BACKUP FUNCTIONS
# =============================================================================

# Detect if a desktop environment is already installed
# Returns 0 if ~/.config/xfce4/ exists (existing install), 1 otherwise
detectExistingInstall() {
  [[ -d "$HOME/.config/xfce4" ]]
}

# Backup user configuration directories before re-provisioning
# Creates ~/delice-backup-YYYYMMDD/ and rsyncs existing user configs into it
backupUserConfigs() {
  local backupDir="$HOME/delice-backup-$(date +%Y%m%d)"
  local dirsToBackup=(
    "$HOME/.mozilla"
    "$HOME/.config/google-chrome"
    "$HOME/.config/BraveSoftware"
    "$HOME/.config/libreoffice"
    "$HOME/.local/share/keyrings"
    "$HOME/.ssh"
    "$HOME/.thunderbird"
  )

  local existingDirs=()
  local dir
  for dir in "${dirsToBackup[@]}"; do
    if [[ -d "$dir" ]]; then
      existingDirs+=("$dir")
    fi
  done

  if [[ ${#existingDirs[@]} -eq 0 ]]; then
    logWarning "No user config directories found to backup."
    return
  fi

  printMessage "Estimating backup size"
  du -sh "${existingDirs[@]}"

  printMessage "Backing up user configs to ${backupDir}"
  mkdir -p "$backupDir"

  for dir in "${existingDirs[@]}"; do
    local relative="${dir#"$HOME"/}"
    mkdir -p "$backupDir/$(dirname "$relative")"
    rsync -av "$dir/" "$backupDir/$relative/"
  done

  printMessage "Backup complete: ${backupDir}"
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
  --backup-configs             Backup user configs before installing
  --skip-backup                Skip backup prompt for existing installations
  --theme                      Install theme packages and sync dotfiles
  --desktop=<name>             Desktop profile to install (default: xfce)
  --drivers=<profile>          Driver profile: vm, intel, nvidia, none (default: vm)
  --with-brave                 Install Brave browser with managed policies
  --migrate-chrome             Migrate Chrome data (bookmarks, history, passwords) to Brave
  --with-rustdesk              Install Rustdesk remote access
  --rustdesk-server=HOST       Rustdesk relay server address
  --rustdesk-key=KEY           Rustdesk server public key
  --rustdesk-password=PASS     Rustdesk permanent password
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
      --backup-configs)
        backupConfigs=1
        backupCliOverride=1
      ;;
      --skip-backup)
        skipBackup=1
        backupCliOverride=1
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
      --with-brave)
        installBrave=1
        braveCliOverride=1
      ;;
      --migrate-chrome)
        migrateChrome=1
        migrateCliOverride=1
      ;;
      --with-rustdesk)
        installRustdesk=1
        rustdeskCliOverride=1
      ;;
      --rustdesk-server=*)
        rustdeskServer="${1#*=}"
      ;;
      --rustdesk-key=*)
        rustdeskKey="${1#*=}"
      ;;
      --rustdesk-password=*)
        rustdeskPassword="${1#*=}"
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

# Prompt user about Brave browser installation
# Skipped if Brave flag was specified via command line (--with-brave)
promptBraveInstall() {
  if [[ $braveCliOverride -eq 1 ]]; then
    return
  fi
  askYesNo "Install Brave browser? [y/N]" installBrave "n"
}

# Prompt user about Chrome to Brave migration
# Only prompts if both Chrome and Brave are detected
# Skipped if migration flag was specified via command line (--migrate-chrome)
promptChromeMigration() {
  if [[ $migrateCliOverride -eq 1 ]]; then
    return
  fi
  if ! dpkg -l google-chrome-stable 2>/dev/null | grep -q "^ii"; then
    return
  fi
  if [[ $installBrave -eq 0 ]] && ! dpkg -l brave-browser 2>/dev/null | grep -q "^ii"; then
    return
  fi
  askYesNo "Migrate Chrome data (bookmarks, history, passwords) to Brave? [y/N]" migrateChrome "n"
}

# Prompt user about Rustdesk remote access installation
# Skipped if Rustdesk flag was specified via command line (--with-rustdesk)
promptRustdeskInstall() {
  if [[ $rustdeskCliOverride -eq 1 ]]; then
    return
  fi
  askYesNo "Install Rustdesk remote access? [y/N]" installRustdesk "n"
}

promptBackupConfigs() {
  if [[ $backupCliOverride -eq 1 ]]; then
    return
  fi
  if ! detectExistingInstall; then
    return
  fi
  logWarning "Existing desktop installation detected."
  askYesNo "Backup user configs before proceeding? [Y/n]" backupConfigs "y"
}

maybePromptUser() {
  if [[ "$promptMode" == "disabled" ]]; then
    return
  fi
  promptBackupConfigs
  promptDriverProfile
  promptThemeOption
  promptMultimediaGroups
  promptOfficeSuite
  promptDevelopmentGroups
  promptBluetoothSupport
  promptBraveInstall
  promptChromeMigration
  promptRustdeskInstall
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

  local braveSummary="Brave: skipped"
  if [[ $installBrave -eq 1 ]]; then
    packagesToInstall+=($bravePackages)
    braveSummary="Brave: ${bravePackages}"
    queuePostInstallTask configureBravePolicies
  fi
  addSummary "$braveSummary"

  local migrationSummary="Chrome migration: skipped"
  if [[ $migrateChrome -eq 1 ]]; then
    packagesToInstall+=($migrationDeps)
    migrationSummary="Chrome migration: enabled (deps: ${migrationDeps})"
    queuePostInstallTask runChromeMigration
  fi
  addSummary "$migrationSummary"

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

  local rustdeskSummary="Rustdesk: skipped"
  if [[ $installRustdesk -eq 1 ]]; then
    rustdeskSummary="Rustdesk: will download from GitHub"
    queuePostInstallTask installRustdesk
  fi
  addSummary "$rustdeskSummary"

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

# Add Brave browser APT repository and GPG keyring
# See: https://brave.com/linux/#debian-ubuntu-mint
# Idempotent: skips if keyring already exists
setupBraveRepo() {
  local keyringPath="/usr/share/keyrings/brave-browser-archive-keyring.gpg"
  if [[ -f "$keyringPath" ]]; then
    printMessage "Brave repository already configured, skipping"
    return
  fi
  printMessage "Adding Brave browser APT repository"
  sudo curl -fsSLo "$keyringPath" https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
  echo "deb [signed-by=${keyringPath}] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list > /dev/null
}

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

  local managedConfigDirs=(alacritty fastfetch galculator gtk-2.0 gtk-3.0 htop Kvantum l3afpad pcmanfm rofi xfce4)
  local dir
  for dir in "${managedConfigDirs[@]}"; do
    if [[ -d "${projectRoot}/.config/${dir}" ]]; then
      mkdir -p "$HOME/.config/${dir}"
      rsync -rtv --delete "${projectRoot}/.config/${dir}/" "$HOME/.config/${dir}/"
    fi
  done

  if [[ -d "${projectRoot}/wallpapers" ]]; then
    mkdir -p "$HOME/wallpapers"
    rsync -rtv --delete "${projectRoot}/wallpapers/" "$HOME/wallpapers/"
  fi

  configureWallpaper
}

# Resolve wallpaper placeholder in XFCE desktop configuration
# Replaces DELICE_WALLPAPER with actual path to user's wallpaper
configureWallpaper() {
  local desktopXml="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml"
  if [[ ! -f "$desktopXml" ]]; then
    logWarning "xfce4-desktop.xml not found, skipping wallpaper configuration."
    return
  fi
  local wallpaperPath="$HOME/wallpapers/${defaultWallpaper}"
  printMessage "Configuring wallpaper: ${defaultWallpaper}"
  sed -i "s|DELICE_WALLPAPER|${wallpaperPath}|g" "$desktopXml"
}

# Download and install Rustdesk from GitHub releases
# Configures relay server and permanent password if provided
installRustdesk() {
  printMessage "Installing Rustdesk"
  local tmpDeb
  tmpDeb=$(mktemp --suffix=.deb)

  # Get latest release .deb URL for amd64
  local downloadUrl
  downloadUrl=$(curl -fsSL https://api.github.com/repos/rustdesk/rustdesk/releases/latest \
    | grep -oP '"browser_download_url":\s*"\K[^"]+amd64\.deb(?=")' \
    | grep -v sctgdesk \
    | head -1)

  if [[ -z "$downloadUrl" ]]; then
    logError "Failed to find Rustdesk .deb download URL"
    rm -f "$tmpDeb"
    return 1
  fi

  printMessage "Downloading Rustdesk from ${downloadUrl}"
  curl -fsSL -o "$tmpDeb" "$downloadUrl"
  sudo dpkg -i "$tmpDeb" || sudo apt install -f -y
  rm -f "$tmpDeb"

  if [[ -n "$rustdeskServer" ]]; then
    printMessage "Configuring Rustdesk server: ${rustdeskServer}"
    rustdesk --option custom-rendezvous-server "${rustdeskServer}"
    rustdesk --option relay-server "${rustdeskServer}"
  fi

  if [[ -n "$rustdeskKey" ]]; then
    printMessage "Configuring Rustdesk server key"
    rustdesk --option key "${rustdeskKey}"
  fi

  if [[ -n "$rustdeskPassword" ]]; then
    printMessage "Setting Rustdesk permanent password"
    rustdesk --password "${rustdeskPassword}"
  fi

  sudo systemctl enable --now rustdesk
  printMessage "Rustdesk installed and enabled"
}

# Run Chrome to Brave data migration script
runChromeMigration() {
  printMessage "Running Chrome to Brave migration"
  python3 "${projectRoot}/tools/migrate-chrome-to-brave.py"
}

# Deploy Brave browser enterprise policies
# Copies managed (enforced) and recommended (user-overridable) policy files
configureBravePolicies() {
  printMessage "Deploying Brave browser policies"
  sudo mkdir -p /etc/brave/policies/managed /etc/brave/policies/recommended
  sudo cp "${projectRoot}/configs/brave-policies-managed.json" /etc/brave/policies/managed/policies.json
  sudo cp "${projectRoot}/configs/brave-policies-recommended.json" /etc/brave/policies/recommended/policies.json
  promptChromeUninstall
}

# Offer to uninstall Google Chrome if detected
# Only prompts in interactive mode — never auto-removes
promptChromeUninstall() {
  if ! dpkg -l google-chrome-stable 2>/dev/null | grep -q "^ii"; then
    return
  fi
  if [[ "$promptMode" == "disabled" ]]; then
    logWarning "Google Chrome detected. Use 'apt remove google-chrome-stable' to uninstall manually."
    return
  fi
  local removeChrome=0
  askYesNo "Google Chrome detected. Uninstall it? [y/N]" removeChrome "n"
  if [[ $removeChrome -eq 1 ]]; then
    printMessage "Removing Google Chrome"
    sudo apt remove -y google-chrome-stable
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
  if [[ $backupConfigs -eq 1 && $skipBackup -eq 0 ]]; then
    backupUserConfigs
  fi
  buildPackagePlan
  printSummary
  if [[ $dryRun -eq 1 ]]; then
    logWarning "Dry run enabled; skipping installation."
    return
  fi
  if [[ $installBrave -eq 1 ]]; then
    setupBraveRepo
  fi
  installPackages
  executePostInstallTasks
  printMessage "Desktop environment setup complete."
}

time main "$@"
