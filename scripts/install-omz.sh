#!/bin/bash
# Install Oh My Zsh if zsh is available and oh-my-zsh doesn't exist

set -euo pipefail

# Colors for output
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly NC='\033[0m' # No Color

success() { printf "%b✓ %s%b\n" "$GREEN" "$1" "$NC"; }
warn() { printf "%b⚠ %s%b\n" "$YELLOW" "$1" "$NC"; }

# Check if zsh is available
if ! command -v zsh >/dev/null 2>&1; then
    warn "zsh not available, skipping Oh My Zsh installation"
    exit 0
fi

# Check if Oh My Zsh is already installed
if [[ -d ~/.oh-my-zsh ]]; then
    success "Oh My Zsh is already installed"
    exit 0
fi

# Install Oh My Zsh
if sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended 2>/dev/null; then
    success "Oh My Zsh installed successfully"
else
    warn "Failed to install Oh My Zsh"
    exit 1
fi
