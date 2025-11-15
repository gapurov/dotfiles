#!/bin/bash
# Reset macOS audio output by briefly switching to the built-in
# speakers and then back to the previous output device.
#
# This is a workaround for cases where headphones or other output
# devices stop working until you "bounce" the audio routing.
#
# Dependencies:
#   - SwitchAudioSource (Homebrew: brew install switchaudio-osx)

set -euo pipefail

log() {
  printf "==> %s\n" "$1"
}

warn() {
  printf "⚠ %s\n" "$1" >&2
}

error() {
  printf "✗ %s\n" "$1" >&2
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

main() {
  if ! command_exists SwitchAudioSource; then
    error "SwitchAudioSource is not installed."
    echo "Install it with: brew install switchaudio-osx" >&2
    exit 1
  fi

  local sas="SwitchAudioSource"

  # Capture current default output device.
  local prev_output
  prev_output="$("$sas" -c -t output || true)"
  log "Current output device: ${prev_output:-unknown}"

  log "Switching output to built-in speakers..."

  # Use CoreAudio UID for built-in speakers when possible.
  if ! "$sas" -t output -u BuiltInSpeakerDevice >/dev/null 2>&1; then
    warn "Could not switch output to built-in speakers (BuiltInSpeakerDevice)."
  fi

  log "Switching output back to previous device..."

  if [[ -n "${prev_output:-}" ]]; then
    if ! "$sas" -t output -s "$prev_output" >/dev/null 2>&1; then
      warn "Failed to restore previous output device: $prev_output"
    else
      log "Restored output device: $prev_output"
    fi
  else
    warn "No previous output device recorded; nothing to restore."
  fi
}

main "$@"
