#!/usr/bin/env bash

set -euo pipefail

# Simple wrapper script that calls run.sh with install-config.sh
# This maintains the familiar ./install.sh usage pattern

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
