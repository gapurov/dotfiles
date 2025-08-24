#!/usr/bin/env bash

set -euo pipefail

# Simple wrapper script that calls run.sh with install-config.sh
# This maintains the familiar ./install.sh usage pattern

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Initialize centralized sudo management
readonly SUDO_HELPER_SCRIPT="$SCRIPT_DIR/scripts/sudo-helper.sh"
if [[ -f "$SUDO_HELPER_SCRIPT" ]]; then
    source "$SUDO_HELPER_SCRIPT"
    if ! init_sudo; then
        exit 1
    fi
else
    # Fallback to original sudo handling if helper script not found
    echo "Checking for \`sudo\` access (which may request your password)..."
    if ! sudo -n true 2>/dev/null; then
        # Try different approaches based on terminal availability
        if tty -s; then
            # We have a controlling terminal, can prompt normally
            sudo -v
            if [[ $? -ne 0 ]]; then
                echo "Need sudo access on macOS (e.g. the user $(whoami) needs to be an Administrator)!" >&2
                exit 1
            fi
        elif [[ -c /dev/tty ]] && { sudo -v < /dev/tty; } 2>/dev/null; then
            # Successfully used /dev/tty for password input
            echo "✓ Sudo access granted"
        else
            # No TTY available - provide helpful guidance
            echo "⚠ Cannot prompt for sudo password (no interactive terminal)" >&2
            echo "" >&2
            echo "Please pre-authorize sudo in another terminal first:" >&2
            echo "  sudo -v" >&2
            echo "" >&2
            echo "Then run the remote installer:" >&2
            echo "  curl -fsSL https://raw.githubusercontent.com/gapurov/dotfiles/master/remote-install.sh | bash" >&2
            echo "" >&2
            echo "Or clone and run locally:" >&2
            echo "  git clone https://github.com/gapurov/dotfiles.git ~/.dotfiles && cd ~/.dotfiles && ./install.sh" >&2
            exit 1
        fi
    else
        echo "✓ Sudo access already available"
    fi
fi
readonly RUN_SCRIPT="$SCRIPT_DIR/scripts/simple-dotfiles/run.sh"
readonly CONFIG_FILE="$SCRIPT_DIR/install-config.sh"

# Check if run.sh exists
if [[ ! -f "$RUN_SCRIPT" ]]; then
    echo "Error: run.sh not found at $RUN_SCRIPT" >&2
    exit 1
fi

# Check if install-config.sh exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: install-config.sh not found in $SCRIPT_DIR" >&2
    exit 1
fi

# Execute run.sh with install-config.sh and pass through all arguments
exec "$RUN_SCRIPT" --config "$CONFIG_FILE" "$@"
