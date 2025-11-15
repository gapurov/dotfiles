#!/usr/bin/env bash
# @raycast.schemaVersion 1
# @raycast.title Reset Audio Output
# @raycast.mode silent

# Raycast Script Command wrapper:
# Briefly switches macOS audio output to built-in speakers and back,
# using the core reset-audio-output.sh script.

set -euo pipefail

RESET_SCRIPT="/Users/vgapurov/.dotfiles/scripts/reset-audio-output.sh"

if [[ ! -x "$RESET_SCRIPT" ]]; then
  echo "Audio output reset script not found or not executable." >&2
  echo "Expected at: $RESET_SCRIPT" >&2
  exit 1
fi

"$RESET_SCRIPT"

