#!/bin/bash
set -uo pipefail

readonly BASE_VM_NAME="debian-stable-base"
readonly VM_NAME="test-postinstall-$(date +%s)"
readonly SNAPSHOT_IMAGE="/home/titux/virt-manager/snapshot/${VM_NAME}.qcow2"
readonly LOG_TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
readonly POST_INSTALL_LOG="./test-post-install-${LOG_TIMESTAMP}.log"
readonly DESKTOP_LOG="./test-desktop-${LOG_TIMESTAMP}.log"
readonly MEMORY="2048"
readonly VCPUS="2"
readonly TIMEOUT=600

readonly POST_INSTALL_BACKUP_NAME="debian-post-install-backup"
readonly POST_INSTALL_BACKUP_DISK="/home/titux/virt-manager/disk/debian-post-install-backup.qcow2"

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

SCRIPT_TO_TEST=""
CREATED_VMS=()
CREATED_SNAPSHOTS=()

log() { echo -e "${GREEN}[$(date +%H:%M:%S)]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

waitForNetwork() {
  cat <<'NETWORK_WAIT'
# Wait for network to be ready
echo "Waiting for network..." >> /var/log/test-output.log
for i in {1..30}; do
  if ping -c1 -W2 deb.debian.org &>/dev/null; then
    echo "Network is ready" >> /var/log/test-output.log
    break
  fi
  sleep 2
done
NETWORK_WAIT
}

createRcLocal() {
  local script_name="$1"
  local output_file="$2"
  cat > "$output_file" <<'RCEOF'
#!/bin/bash
SCRIPT_PLACEHOLDER &
exit 0
RCEOF
  sed -i "s|SCRIPT_PLACEHOLDER|/usr/local/bin/${script_name}|g" "$output_file"
}

generatePostInstallScript() {
  local script_name="$1"
  local output_file="$2"
  cat > "$output_file" <<POSTSCRIPT
#!/bin/bash
export HOME=/home/debian

$(waitForNetwork)

cd /home/debian/delice
./post-install.sh 2>&1 | tee -a /var/log/test-output.log
echo "TEST_COMPLETE" >> /var/log/test-output.log
poweroff
POSTSCRIPT
  chmod +x "$output_file"
  createRcLocal "$script_name" /tmp/rc.local
}

injectPostInstallFiles() {
  local snapshot_image="$1"
  local script_path="$2"

  virt-customize -a "$snapshot_image" \
    --mkdir /home/debian/delice \
    --copy-in ./post-install.sh:/home/debian/delice/ \
    --copy-in ./sources.list:/home/debian/delice/ \
    --copy-in ./dotfiles:/home/debian/delice/ \
    --copy-in "$script_path":/usr/local/bin/ \
    --copy-in /tmp/rc.local:/etc/ \
    --run-command 'chown -R debian:debian /home/debian/delice' \
    --run-command "chmod +x /usr/local/bin/$(basename "$script_path")" \
    --run-command 'chmod +x /etc/rc.local' || { error "Failed to customize VM image"; exit 1; }
}

monitorVMCompletion() {
  local vm_name="$1"
  local timeout="$2"
  local task_name="${3:-VM}"

  log "Waiting for ${task_name} to complete (max ${timeout}s)..."
  local elapsed=0
  while sudo virsh --connect qemu:///system domstate "$vm_name" 2>/dev/null | grep -q running; do
    sleep 10
    elapsed=$((elapsed + 10))
    if [[ $elapsed -ge $timeout ]]; then
      error "${task_name} timeout after ${timeout}s"
      return 1
    fi
    log "[$elapsed/${timeout}s] ${task_name} running..."
  done
  log "${task_name} complete"
  return 0
}

validateVMExists() {
  local vm_name="$1"
  if ! sudo virsh --connect qemu:///system list --all | grep -q "$vm_name"; then
    error "Base VM '$vm_name' does not exist"
    return 1
  fi
  return 0
}

cleanupOldLogs() {
  local max_logs=5
  shopt -s nullglob

  # Clean up old post-install test logs
  local post_files=(test-post-install-*.log)
  local post_count=${#post_files[@]}
  if [[ $post_count -gt $max_logs ]]; then
    log "Cleaning up old post-install test logs (keeping last ${max_logs})"
    printf '%s\0' "${post_files[@]}" | xargs -0 ls -t | tail -n +$((max_logs + 1)) | xargs -d '\n' rm -f
  fi

  # Clean up old desktop test logs
  local desktop_files=(test-desktop-*.log)
  local desktop_count=${#desktop_files[@]}
  if [[ $desktop_count -gt $max_logs ]]; then
    log "Cleaning up old desktop test logs (keeping last ${max_logs})"
    printf '%s\0' "${desktop_files[@]}" | xargs -0 ls -t | tail -n +$((max_logs + 1)) | xargs -d '\n' rm -f
  fi

  shopt -u nullglob
}

showLogSummary() {
  local log_file="$1"
  local log_name="${2:-Test}"

  echo ""
  log "${log_name} results saved to: $log_file"
  log "Showing last 30 lines of output:"
  echo "----------------------------------------"
  tail -n 30 "$log_file"
  echo "----------------------------------------"
  echo ""
  log "Full log available at: $log_file"
  echo ""
}

backupExists() {
  sudo virsh --connect qemu:///system list --all | grep -q "$POST_INSTALL_BACKUP_NAME"
}

isDesktopTest() {
  [[ "$SCRIPT_TO_TEST" == "desktop" ]]
}

useBackupSource() {
  isDesktopTest && backupExists
}

getCloneSource() {
  useBackupSource && echo "$POST_INSTALL_BACKUP_NAME" || echo "$BASE_VM_NAME"
}

isBackupSource() {
  [[ "$1" == "$POST_INSTALL_BACKUP_NAME" ]]
}

runDesktopOnBackup() {
  local desktop_vm_name="test-desktop-$(date +%s)"
  local desktop_snapshot="/home/titux/virt-manager/snapshot/${desktop_vm_name}.qcow2"

  CREATED_VMS+=("$desktop_vm_name")
  CREATED_SNAPSHOTS+=("$desktop_snapshot")

  sudo virt-clone --connect qemu:///system \
    --original "$POST_INSTALL_BACKUP_NAME" \
    --name "$desktop_vm_name" \
    --file "$desktop_snapshot" || { error "Failed to clone backup VM"; exit 1; }

  sudo chown $USER:$USER "$desktop_snapshot"

  cat > /tmp/run-desktop.sh <<DESKTOPSCRIPT
#!/bin/bash
export HOME=/home/debian

# Clear any previous log content from post-install backup
echo "Starting desktop test after post-install backup..." > /var/log/test-output.log

$(waitForNetwork)

cd /home/debian/delice
./desktop-environment.sh 2>&1 | tee -a /var/log/test-output.log
echo "TEST_COMPLETE" >> /var/log/test-output.log
poweroff
DESKTOPSCRIPT
  chmod +x /tmp/run-desktop.sh

  createRcLocal "run-desktop.sh" /tmp/rc.local

  virt-customize -a "$desktop_snapshot" \
    --copy-in ./desktop-environment.sh:/home/debian/delice/ \
    --copy-in ./.config:/home/debian/delice/ \
    --copy-in ./wallpapers:/home/debian/delice/ \
    --copy-in /tmp/run-desktop.sh:/usr/local/bin/ \
    --copy-in /tmp/rc.local:/etc/ \
    --run-command 'chown -R debian:debian /home/debian/delice' \
    --run-command 'chmod +x /usr/local/bin/run-desktop.sh' \
    --run-command 'chmod +x /etc/rc.local' || { error "Failed to customize VM image"; exit 1; }

  sudo virsh --connect qemu:///system start "$desktop_vm_name" || { error "Failed to start VM"; exit 1; }

  if ! monitorVMCompletion "$desktop_vm_name" "$TIMEOUT" "Desktop VM"; then
    error "Desktop VM timeout after ${TIMEOUT}s"
    sudo virsh --connect qemu:///system destroy "$desktop_vm_name" 2>/dev/null || true
    sudo virsh --connect qemu:///system undefine "$desktop_vm_name" --nvram 2>/dev/null || true
    rm -f "$desktop_snapshot"
    exit 1
  fi

  virt-cat -a "$desktop_snapshot" /var/log/test-output.log > "$DESKTOP_LOG" 2>/dev/null

  echo ""
  log "Desktop test results (saved to $DESKTOP_LOG):"
  echo ""

  grep -q "TEST_COMPLETE" "$DESKTOP_LOG" && log "Desktop test completed successfully!" || { error "Desktop test failed or did not complete"; exit 1; }

  sudo virsh --connect qemu:///system destroy "$desktop_vm_name" 2>/dev/null || true
  sudo virsh --connect qemu:///system undefine "$desktop_vm_name" --nvram 2>/dev/null || true
  rm -f "$desktop_snapshot"
}

needsBackupCreation() {
  isDesktopTest && ! backupExists
}

createPostInstallBackup() {
  log "Creating post-install backup for future desktop runs"
  sudo virt-clone --connect qemu:///system \
    --original "$VM_NAME" \
    --name "$POST_INSTALL_BACKUP_NAME" \
    --file "$POST_INSTALL_BACKUP_DISK"
  
  sudo chown $USER:$USER "$POST_INSTALL_BACKUP_DISK"
  log "Post-install backup created successfully"
}

parseArgs() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --desktop)
        SCRIPT_TO_TEST="desktop"
        shift
        ;;
      -h|--help)
        echo "Usage: $0 [--desktop]"
        echo "  Default: test post-install.sh"
        echo "  --desktop: test both post-install.sh and desktop-environment.sh"
        exit 0
        ;;
      *)
        error "Unknown option: $1"
        exit 1
        ;;
    esac
  done
  [[ -z "$SCRIPT_TO_TEST" ]] && SCRIPT_TO_TEST="post"
}

cleanup() {
  log "Cleaning up all created VMs and snapshots"
  
  # Clean up all created VMs
  for vm_name in "${CREATED_VMS[@]}"; do
    [[ -n "$vm_name" ]] || continue
    log "Destroying VM: $vm_name"
    sudo virsh --connect qemu:///system destroy "$vm_name" 2>/dev/null || true
    sudo virsh --connect qemu:///system undefine "$vm_name" --nvram 2>/dev/null || true
  done
  
  # Clean up all created snapshots
  for snapshot in "${CREATED_SNAPSHOTS[@]}"; do
    [[ -n "$snapshot" ]] && [[ -f "$snapshot" ]] || continue
    log "Removing snapshot: $snapshot"
    rm -f "$snapshot"
  done
}

isFirstDesktopRun() {
  needsBackupCreation
}

isBackupDesktopRun() {
  useBackupSource
}

isPostOnlyRun() {
  ! isDesktopTest
}

main() {
  parseArgs "$@"
  trap cleanup EXIT INT TERM
  cleanupOldLogs

  local source_vm
  source_vm=$(getCloneSource)

  validateVMExists "$source_vm" || exit 1

  CREATED_VMS+=("$VM_NAME")
  CREATED_SNAPSHOTS+=("$SNAPSHOT_IMAGE")

  log "Creating VM clone from $source_vm"
  sudo virt-clone --connect qemu:///system \
    --original "$source_vm" \
    --name "$VM_NAME" \
    --file "$SNAPSHOT_IMAGE" || { error "Failed to clone VM from $source_vm"; exit 1; }

  sudo chown $USER:$USER "$SNAPSHOT_IMAGE"

  log "Injecting scripts into disk image"
  sleep 3

  if isFirstDesktopRun; then
    log "First desktop run: post-install → backup → desktop"

    # Create and inject post-install script
    generatePostInstallScript "run-post.sh" /tmp/run-post.sh
    injectPostInstallFiles "$SNAPSHOT_IMAGE" /tmp/run-post.sh

    log "Starting VM for post-install"
    sudo virsh --connect qemu:///system start "$VM_NAME" || { error "Failed to start VM"; exit 1; }

    monitorVMCompletion "$VM_NAME" "$TIMEOUT" "Post-install" || exit 1

    log "Post-install complete. Extracting logs..."
    virt-cat -a "$SNAPSHOT_IMAGE" /var/log/test-output.log > "$POST_INSTALL_LOG" 2>/dev/null
    log "Post-install logs saved to: $POST_INSTALL_LOG"

    log "Creating backup of post-install state"
    createPostInstallBackup

    log "Running desktop script on backup"
    runDesktopOnBackup

    return
  fi

  if isBackupDesktopRun; then
    log "Using existing backup for desktop-only run"

    # Create the run script for DESKTOP ONLY
    cat > /tmp/run-desktop-only.sh <<DESKTOPSCRIPT
#!/bin/bash
export HOME=/home/debian

# Clear any previous log content from post-install backup
echo "Starting desktop-only test..." > /var/log/test-output.log

$(waitForNetwork)

cd /home/debian/delice
./desktop-environment.sh 2>&1 | tee -a /var/log/test-output.log
echo "TEST_COMPLETE" >> /var/log/test-output.log
poweroff
DESKTOPSCRIPT
    chmod +x /tmp/run-desktop-only.sh

    createRcLocal "run-desktop-only.sh" /tmp/rc.local

    # Inject desktop files only
    virt-customize -a "$SNAPSHOT_IMAGE" \
      --copy-in ./desktop-environment.sh:/home/debian/delice/ \
      --copy-in ./.config:/home/debian/delice/ \
      --copy-in ./wallpapers:/home/debian/delice/ \
      --copy-in /tmp/run-desktop-only.sh:/usr/local/bin/ \
      --copy-in /tmp/rc.local:/etc/ \
      --run-command 'chown -R debian:debian /home/debian/delice' \
      --run-command 'chmod +x /usr/local/bin/run-desktop-only.sh' \
      --run-command 'chmod +x /etc/rc.local' || { error "Failed to customize VM image"; exit 1; }

    log "Starting backup VM for desktop script"
    sudo virsh --connect qemu:///system start "$VM_NAME" || { error "Failed to start VM"; exit 1; }

    monitorVMCompletion "$VM_NAME" "$TIMEOUT" "Desktop" || exit 1

    log "Desktop complete. Extracting logs..."
    virt-cat -a "$SNAPSHOT_IMAGE" /var/log/test-output.log > "$DESKTOP_LOG" 2>/dev/null

    showLogSummary "$DESKTOP_LOG" "Desktop"

    grep -q "TEST_COMPLETE" "$DESKTOP_LOG" && log "Test completed successfully!" || { error "Test failed or did not complete"; exit 1; }

    return
  fi

  if isPostOnlyRun; then
    log "Running post-install only"

    # Create and inject post-install script
    generatePostInstallScript "run-post-only.sh" /tmp/run-post-only.sh
    injectPostInstallFiles "$SNAPSHOT_IMAGE" /tmp/run-post-only.sh

    log "Starting VM for post-install"
    sudo virsh --connect qemu:///system start "$VM_NAME" || { error "Failed to start VM"; exit 1; }

    monitorVMCompletion "$VM_NAME" "$TIMEOUT" "Post-install" || exit 1

    log "Post-install complete. Extracting logs..."
    virt-cat -a "$SNAPSHOT_IMAGE" /var/log/test-output.log > "$POST_INSTALL_LOG" 2>/dev/null

    showLogSummary "$POST_INSTALL_LOG" "Post-install"

    grep -q "TEST_COMPLETE" "$POST_INSTALL_LOG" && log "Test completed successfully!" || { error "Test failed or did not complete"; exit 1; }

    return
  fi

  error "Unknown execution path"
  exit 1
}

main "$@"