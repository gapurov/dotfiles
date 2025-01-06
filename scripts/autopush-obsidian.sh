#!/usr/bin/env bash

# Exit on error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Config
OBSIDIAN_DIR="/Users/vgapurov/Documents/Obsidian/gapurov-obsidian"
GIT=$(which git)

# Logger function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Check if directory exists
[[ -d "$OBSIDIAN_DIR" ]] || error "Obsidian directory not found: $OBSIDIAN_DIR"

# Change to Obsidian directory
cd "$OBSIDIAN_DIR" || error "Failed to change to Obsidian directory"

log "Starting Obsidian auto-push process..."

# Check if we're in a git repository
$GIT rev-parse --is-inside-work-tree &>/dev/null || error "Not a git repository"

# Check if there are any changes
if [[ -z "$($GIT status --porcelain)" ]]; then
    log "No changes to commit"
    exit 0
fi

# Add changes
log "Adding changes..."
$GIT add . || error "Failed to add changes"

# Commit changes
log "Committing changes..."
$GIT commit -m "Auto Update: $(date '+%Y-%m-%d %H:%M:%S')" || error "Failed to commit changes"

# Pull changes
log "Pulling latest changes..."
$GIT pull origin main || error "Failed to pull changes"

# Push changes
log "Pushing changes..."
$GIT push origin main || error "Failed to push changes"

log "✅ All done! Enjoy a cold one! 🍺"
