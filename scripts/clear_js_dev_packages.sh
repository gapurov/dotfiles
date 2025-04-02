#!/usr/bin/env bash

# Set strict error handling
set -euo pipefail

# Color codes for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Logger functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2
}

clear_js_dev_packages() {
    # Define array of directories to clean
    local dirs=(
        "$HOME/.bun/install/cache"
        "$HOME/.bun/install/global"
        "$HOME/Library/Application Support/fnm/node-versions"
        "$HOME/.local/state/fnm_multishells"
    )

    log "Clearing development packages..."

    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            log "Removing $dir"
            rm -rf "$dir"
        else
            error "Directory not found: $dir"
        fi
    done

    log "Packages cleared successfully"
}

# Execute the function
clear_js_dev_packages
