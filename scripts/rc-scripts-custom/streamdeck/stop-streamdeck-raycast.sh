#!/usr/bin/env bash
# @raycast.schemaVersion 1
# @raycast.title Stop Stream Deck
# @raycast.icon images/elgato_logo_icon.svg
# @raycast.mode silent

# Raycast Script Command wrapper:
# Stops the Elgato Stream Deck app and its plugin processes.

set -euo pipefail

CONTROL_SCRIPT="/Users/vgapurov/.dotfiles/scripts/restart-streamdeck.sh"

if [[ ! -x "$CONTROL_SCRIPT" ]]; then
  echo "Stream Deck control script not found or not executable." >&2
  echo "Expected at: $CONTROL_SCRIPT" >&2
  exit 1
fi

"$CONTROL_SCRIPT" stop
