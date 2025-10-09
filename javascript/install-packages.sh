#!/usr/bin/env bash

set -euo pipefail # Exit on error, undefined vars, and pipe failures

# Colors for logging
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m' # No Color

# Simple logging functions
log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
warn() { echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARN: $1${NC}"; }
error() { echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2; }

# Check if required tools are installed (bun handled below)
for tool in jq fnm curl; do
    command -v "$tool" &>/dev/null || {
        error "$tool is required but not installed."
        exit 1
    }
done

# Ensure Bun is installed and up to date
if ! command -v bun &>/dev/null; then
    log "Installing Bun..."
    export BUN_INSTALL="$HOME/.bun"
    curl -fsSL https://bun.sh/install | bash
    export PATH="$BUN_INSTALL/bin:$PATH"
else
    log "Upgrading Bun to latest..."
    bun upgrade || { error "Failed to upgrade Bun"; exit 1; }
fi

# Install Node.js versions with fnm and set default
fnm install --lts
# Try the newest release; fall back to the first available one for this arch when needed.
if ! fnm install --latest; then
    warn "fnm install --latest failed; attempting fallback to an earlier release."
    mapfile -t __fnm_versions < <(fnm ls-remote | awk 'match($0, /^v([1-9][0-9]+)\./) { lines[NR] = $0 } END { for (i = NR; i > 0; i--) print lines[i] }')
    if [[ ${#__fnm_versions[@]} -eq 0 ]]; then
        error "Could not retrieve Node.js versions from fnm."
        exit 1
    fi
    fallback_success=0
    for idx in "${!__fnm_versions[@]}"; do
        version="${__fnm_versions[$idx]}"
        if [[ $idx -eq 0 ]]; then
            warn "Skipping unavailable release $version."
            continue
        fi
        if fnm install "$version"; then
            log "Installed fallback Node.js release $version."
            fallback_success=1
            break
        fi
        warn "Failed to install $version; trying an earlier release..."
    done
    if [[ $fallback_success -eq 0 ]]; then
        error "Unable to install a usable Node.js release via fnm."
        exit 1
    fi
fi
fnm default lts-latest || true

# Install packages from package.json (deps + devDeps)
readonly package_file="$HOME/.dotfiles/javascript/package.json"
[[ -f "$package_file" ]] || {
    error "Package file not found: $package_file"
    exit 1
}

log "Installing global packages from $package_file"
while read -r package version; do
    if [[ "$version" == "latest-version" ]]; then
        log "Installing $package (latest) globally..."
        bun add -g "$package@latest" || { error "Failed to install $package"; exit 1; }
    else
        log "Installing $package@$version globally..."
        bun add -g "$package@$version" || { error "Failed to install $package"; exit 1; }
    fi
done < <(jq -r '(.dependencies + (.devDependencies // {})) | to_entries[] | "\(.key) \(.value)"' "$package_file")

log "All packages installed successfully!"
