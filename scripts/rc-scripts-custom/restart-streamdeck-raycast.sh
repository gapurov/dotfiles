#!/usr/bin/env bash
# @raycast.schemaVersion 1
# @raycast.title Restart Stream Deck
# @raycast.mode silent

# Raycast Script Command wrapper:
# Delegates to the core restart script in your dotfiles repo.

set -euo pipefail

RESTART_SCRIPT="/Users/vgapurov/.dotfiles/scripts/restart-streamdeck.sh"

if [[ ! -x "$RESTART_SCRIPT" ]]; then
  echo "Stream Deck restart script not found or not executable." >&2
  echo "Expected at: $RESTART_SCRIPT" >&2
  exit 1
fi

"$RESTART_SCRIPT" restart
