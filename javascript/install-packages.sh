#!/usr/bin/env bash

set -euo pipefail # Exit on error, undefined vars, and pipe failures

# Colors for logging
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Simple logging functions
log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
error() { echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2; }

# Check if required tools are installed
for tool in jq bun fnm; do
    command -v "$tool" &>/dev/null || {
        error "$tool is required but not installed."
        exit 1
    }
done

# Update bun and install Node.js versions
bun upgrade
fnm install --lts
fnm install --latest

# Install packages from package.json
package_file="$HOME/.dotfiles/javascript/package.json"
[[ -f "$package_file" ]] || {
    error "Package file not found: $package_file"
    exit 1
}

log "Installing packages from $package_file"
jq -r '.dependencies | keys[]' "$package_file" | while read -r package; do
    log "Installing $package globally..."
    bun install -g "$package" || {
        error "Failed to install $package"
        exit 1
    }
done

log "All packages installed successfully!"
