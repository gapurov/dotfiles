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

switch_output_to_builtin() {
  local sas="$1"

  # Use CoreAudio UID for built-in speakers when possible.
  if "$sas" -t output -u BuiltInSpeakerDevice >/dev/null 2>&1; then
    return 0
  fi

  warn "Could not switch output to built-in speakers (BuiltInSpeakerDevice)."
  return 1
}

switch_output_to_name() {
  local sas="$1"
  local output_name="$2"

  "$sas" -t output -s "$output_name" >/dev/null 2>&1
}

main() {
  if ! command_exists SwitchAudioSource; then
    error "SwitchAudioSource is not installed."
    echo "Install it with: brew install switchaudio-osx" >&2
    exit 1
  fi

  local sas="SwitchAudioSource"
  local settle_sleep=0.9
  local bounce_rounds=2

  # Capture current default output device.
  local prev_output
  prev_output="$("$sas" -c -t output || true)"
  log "Current output device: ${prev_output:-unknown}"

  if [[ -z "${prev_output:-}" ]]; then
    warn "No previous output device recorded; switching to built-in speakers only."
    switch_output_to_builtin "$sas" || true
    exit 0
  fi

  for ((i = 1; i <= bounce_rounds; i++)); do
    log "Bounce ${i}/${bounce_rounds}: switching output to built-in speakers..."
    switch_output_to_builtin "$sas" || true
    sleep "$settle_sleep"

    log "Bounce ${i}/${bounce_rounds}: switching output back to previous device..."
    if ! switch_output_to_name "$sas" "$prev_output"; then
      warn "Failed to restore previous output device: $prev_output"
    fi
    sleep "$settle_sleep"
  done

  log "Restored output device: $prev_output"
}

main "$@"
