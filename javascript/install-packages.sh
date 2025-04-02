#!/usr/bin/env bash

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# Color codes for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Logger function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2
}

# Check required tools
check_requirements() {
    local required_tools=("jq" "bun" "fnm")

    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error "$tool is required but not installed."
            exit 1
        fi
    done
}

install_packages() {
    local package_file="$HOME/.dotfiles/javascript/package.json"

    if [[ ! -f "$package_file" ]]; then
        error "Package file not found: $package_file"
        exit 1
    fi

    log "Installing packages from $package_file"

    # Read dependencies from package.json using jq
    local packages=($(jq -r '.dependencies | keys[]' "$package_file"))

    for package in "${packages[@]}"; do
        log "Installing $package globally..."
        if ! bun install -g "$package"; then
            error "Failed to install $package"
            exit 1
        fi
    done

    log "All packages installed successfully!"
}



check_requirements

# upgrade bun
bun upgrade

# install node first
fnm install --lts
fnm install --latest


# install bun packages
install_packages
