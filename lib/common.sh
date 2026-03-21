#!/bin/bash

# Name: lib/common.sh
# Description: Shared functions for DELICE provisioning scripts.
# Url: https://github.com/TituxMetal/delice

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

# Enable strict error handling with detailed error reporting
# Sets up trap to show exact line and command that failed
setupErrorHandling() {
  set -euo pipefail
  trap 'status=$?; echo "Error on line ${LINENO}: ${BASH_COMMAND}" >&2; exit $status' ERR
}

# Ensure script is not run as root user
# The script needs to run as regular user with sudo privileges for proper file ownership
# Pass enableRunAsRoot=1 to bypass this check (for testing purposes)
# Usage: requireUserContext
requireUserContext() {
  if [[ "${enableRunAsRoot:-0}" -eq 1 ]]; then
    return
  fi
  if [[ $EUID -eq 0 ]]; then
    logError "Run this script as a regular user with sudo access."
    exit 1
  fi
}

# Resolve the directory containing the calling script
# Usage: scriptDir=$(resolveScriptDir)
resolveScriptDir() {
  cd "$(dirname "${BASH_SOURCE[1]}")" && pwd
}
