#!/bin/bash
# Control Elgato Stream Deck app (and its plugin processes) on macOS.
# Supports start, stop, and restart actions.
# Default action (no args) is "restart".

set -euo pipefail

APP_PATH="/Applications/Elgato Stream Deck.app"
APP_EXEC="$APP_PATH/Contents/MacOS/Stream Deck"
PLUGIN_PATTERN="Library/Application Support/com.elgato.StreamDeck"

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

stop_streamdeck() {
  if [[ ! -d "$APP_PATH" ]]; then
    error "Stream Deck app not found at: $APP_PATH"
    exit 1
  fi

  log "Requesting Stream Deck to quit (graceful stop)..."

  # Try to quit via AppleScript, which should behave like Cmd+Q.
  if command_exists osascript; then
    osascript <<EOF >/dev/null 2>&1 || true
tell application id "com.elgato.StreamDeck"
  if it is running then quit
end tell
EOF
  fi

  # Wait briefly for a graceful shutdown.
  if command_exists pgrep; then
    for _ in {1..10}; do
      if ! pgrep -f "$APP_EXEC" >/dev/null 2>&1; then
        log "Stream Deck app exited gracefully."
        break
      fi
      sleep 0.5
    done
  fi

  # If still running, fall back to terminating the process.
  if command_exists pgrep && pgrep -f "$APP_EXEC" >/dev/null 2>&1; then
    warn "Stream Deck did not quit gracefully; terminating process..."
    pkill -f "$APP_EXEC" || true
    sleep 2
  fi

  log "Cleaning up Stream Deck plugin processes..."

  # Kill main app process if running
  if command_exists pgrep && pgrep -f "$APP_EXEC" >/dev/null 2>&1; then
    pkill -f "$APP_EXEC" || true
  fi

  # Kill Node-based plugin processes started by Stream Deck
  if command_exists pgrep && pgrep -f "$PLUGIN_PATTERN" >/dev/null 2>&1; then
    pkill -f "$PLUGIN_PATTERN" || true
  fi

  # Give processes a brief moment to exit cleanly
  sleep 2

  # Force-kill any leftovers
  if command_exists pgrep; then
    for _ in 1 2 3; do
      if pgrep -f "$APP_EXEC" >/dev/null 2>&1 || pgrep -f "$PLUGIN_PATTERN" >/dev/null 2>&1; then
        pkill -9 -f "$APP_EXEC" || true
        pkill -9 -f "$PLUGIN_PATTERN" || true
        sleep 1
      else
        break
      fi
    done
  fi
}

start_streamdeck() {
  if [[ ! -d "$APP_PATH" ]]; then
    error "Stream Deck app not found at: $APP_PATH"
    exit 1
  fi

  log "Starting Stream Deck app..."

  # Relaunch via LaunchServices so macOS handles environment/integration
  if ! open -a "$APP_PATH"; then
    error "Failed to launch Stream Deck app via 'open'"
    exit 1
  fi

  # Optionally wait for the main process to appear, so the script
  # only returns once the app is actually up.
  if command_exists pgrep; then
    log "Waiting for Stream Deck process to come up..."
    for _ in {1..15}; do
      if pgrep -f "$APP_EXEC" >/dev/null 2>&1; then
        log "Stream Deck is running again. The device should reinitialize shortly."
        return 0
      fi
      sleep 1
    done

    warn "Timed out waiting for Stream Deck process; check the app manually."
  fi
}

restart_streamdeck() {
  stop_streamdeck
  start_streamdeck
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [start|stop|restart]

Controls the Elgato Stream Deck app and its plugin processes.

Actions:
  start     Start the Stream Deck app
  stop      Stop the Stream Deck app and plugin processes
  restart   Stop and then start the app (default)
EOF
}

main() {
  local action="${1:-restart}"

  case "$action" in
    start)
      start_streamdeck
      ;;
    stop)
      stop_streamdeck
      ;;
    restart)
      restart_streamdeck
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      error "Unknown action: $action"
      usage
      exit 1
      ;;
  esac
}

main "$@"
