#!/bin/bash
set -uo pipefail

readonly BASE_IMAGE="${BASE_IMAGE:-/home/titux/virt-manager/disk/debian-stable-base.qcow2}"
readonly VM_NAME="test-postinstall-$(date +%s)"
readonly SNAPSHOT_IMAGE="/home/titux/virt-manager/snapshot/${VM_NAME}.qcow2"
readonly LOG_FILE="./test-results-$(date +%Y%m%d-%H%M%S).log"
readonly MEMORY="2048"
readonly VCPUS="2"
readonly TIMEOUT=600

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

SCRIPT_TO_TEST=""

log() { echo -e "${GREEN}[$(date +%H:%M:%S)]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

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
  log "Cleaning up"
  virsh --connect qemu:///system destroy "$VM_NAME" 2>/dev/null || true
  virsh --connect qemu:///system undefine "$VM_NAME" --nvram 2>/dev/null || true
  rm -f "$SNAPSHOT_IMAGE"
}

main() {
  parseArgs "$@"
  trap cleanup EXIT INT TERM

  log "Creating snapshot from base image"
  cp "$BASE_IMAGE" "$SNAPSHOT_IMAGE"

  log "Injecting scripts into disk image"

  # Create the run script
  local script_cmd="./post-install.sh"
  [[ "$SCRIPT_TO_TEST" == "desktop" ]] && script_cmd="./post-install.sh && ./desktop-environment.sh"

  cat > /tmp/run-test.sh <<RUNSCRIPT
#!/bin/bash
export HOME=/home/debian

# Wait for network to be ready
echo "Waiting for network..." >> /var/log/test-output.log
for i in {1..30}; do
  if ping -c1 -W2 deb.debian.org &>/dev/null; then
    echo "Network is ready" >> /var/log/test-output.log
    break
  fi
  sleep 2
done

cd /home/debian/delice
$script_cmd 2>&1 | tee -a /var/log/test-output.log
echo "TEST_COMPLETE" >> /var/log/test-output.log
poweroff
RUNSCRIPT
  chmod +x /tmp/run-test.sh

  # Inject everything into the disk
  virt-customize -a "$SNAPSHOT_IMAGE" \
    --mkdir /home/debian/delice \
    --copy-in ./post-install.sh:/home/debian/delice/ \
    --copy-in ./desktop-environment.sh:/home/debian/delice/ \
    --copy-in ./sources.list:/home/debian/delice/ \
    --copy-in ./dotfiles:/home/debian/delice/ \
    --copy-in ./.config:/home/debian/delice/ \
    --copy-in ./wallpapers:/home/debian/delice/ \
    --copy-in /tmp/run-test.sh:/usr/local/bin/ \
    --run-command 'chown -R debian:debian /home/debian/delice' \
    --run-command 'chmod +x /usr/local/bin/run-test.sh' \
    --run-command 'cat > /etc/rc.local << EOF
#!/bin/bash
/usr/local/bin/run-test.sh &
exit 0
EOF' \
    --run-command 'chmod +x /etc/rc.local'

  log "Starting VM"

  # Copy NVRAM
  local nvram_source="/var/lib/libvirt/qemu/nvram/debian-stable-base_VARS.fd"
  local nvram_dest="/var/lib/libvirt/qemu/nvram/${VM_NAME}_VARS.fd"
  if [[ -f "$nvram_source" ]]; then
    cp "$nvram_source" "$nvram_dest"
  fi

  # Start VM
  virt-install --connect qemu:///system \
    --name "$VM_NAME" \
    --memory "$MEMORY" \
    --vcpus "$VCPUS" \
    --disk "$SNAPSHOT_IMAGE",bus=sata \
    --os-variant debian13 \
    --boot uefi \
    --graphics vnc \
    --network network=default \
    --noautoconsole \
    --import

  log "Waiting for VM to complete (max ${TIMEOUT}s)..."

  local elapsed=0
  while virsh --connect qemu:///system domstate "$VM_NAME" 2>/dev/null | grep -q running; do
    sleep 10
    elapsed=$((elapsed + 10))
    if [[ $elapsed -ge $TIMEOUT ]]; then
      error "Timeout after ${TIMEOUT}s"
      exit 1
    fi
    log "[$elapsed/${TIMEOUT}s] VM running..."
  done

  log "VM stopped. Extracting logs..."
  virt-cat -a "$SNAPSHOT_IMAGE" /var/log/test-output.log > "$LOG_FILE" 2>/dev/null

  echo ""
  cat "$LOG_FILE"
  echo ""

  grep -q "TEST_COMPLETE" "$LOG_FILE" && log "Test completed successfully!" || { error "Test failed or did not complete"; exit 1; }
}

main "$@"
