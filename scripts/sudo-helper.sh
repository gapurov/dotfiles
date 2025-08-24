#!/usr/bin/env bash

# sudo-helper.sh
# Centralized sudo management for dotfiles installation
# Provides functions to start and manage sudo keep-alive processes

set -euo pipefail

# Keep-alive process PID storage
readonly SUDO_PID_FILE="$HOME/.dotfiles-sudo.pid"

# Check if sudo is already available
is_sudo_active() {
    sudo -n true 2>/dev/null
}

# Start sudo keep-alive background process
start_sudo_keepalive() {
    local pid_file="${1:-$SUDO_PID_FILE}"
    
    # Check if keep-alive is already running
    if [[ -f "$pid_file" ]]; then
        local existing_pid
        existing_pid=$(cat "$pid_file" 2>/dev/null || echo "")
        if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
            echo "Sudo keep-alive already running (PID: $existing_pid)"
            return 0
        fi
        # Clean up stale PID file
        rm -f "$pid_file"
    fi
    
    # Start keep-alive process in background
    {
        while true; do
            if ! sudo -n true 2>/dev/null; then
                # Sudo expired, exit keep-alive
                break
            fi
            sleep 50
            # Check if parent process still exists
            if ! kill -0 "$$" 2>/dev/null; then
                break
            fi
        done
    } &
    
    local keepalive_pid=$!
    echo "$keepalive_pid" > "$pid_file"
    echo "Started sudo keep-alive process (PID: $keepalive_pid)"
    
    # Set environment variable for child processes
    export DOTFILES_SUDO_ACTIVE=1
}

# Stop sudo keep-alive process
stop_sudo_keepalive() {
    local pid_file="${1:-$SUDO_PID_FILE}"
    
    if [[ -f "$pid_file" ]]; then
        local pid
        pid=$(cat "$pid_file" 2>/dev/null || echo "")
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            echo "Stopped sudo keep-alive process (PID: $pid)"
        fi
        rm -f "$pid_file"
    fi
    
    unset DOTFILES_SUDO_ACTIVE 2>/dev/null || true
}

# Cleanup function for trap
cleanup_sudo() {
    stop_sudo_keepalive
}

# Request sudo access with proper TTY handling (from install.sh)
request_sudo_access() {
    echo "Checking for \`sudo\` access (which may request your password)..."
    if ! sudo -n true 2>/dev/null; then
        # Try different approaches based on terminal availability
        if tty -s; then
            # We have a controlling terminal, can prompt normally
            sudo -v
            if [[ $? -ne 0 ]]; then
                echo "Need sudo access on macOS (e.g. the user $(whoami) needs to be an Administrator)!" >&2
                return 1
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
            return 1
        fi
    else
        echo "✓ Sudo access already available"
    fi
    return 0
}

# Initialize sudo management (call this from main script)
init_sudo() {
    if ! request_sudo_access; then
        return 1
    fi
    
    start_sudo_keepalive
    
    # Set up cleanup trap
    trap cleanup_sudo EXIT INT TERM
    
    return 0
}

# Check if we should skip sudo prompts (for child scripts)
should_skip_sudo_prompt() {
    [[ "${DOTFILES_SUDO_ACTIVE:-0}" == "1" ]]
}

# Main entry point when called as a script
main() {
    case "${1:-}" in
        init)
            echo "Initializing sudo management..."
            init_sudo
            ;;
        cleanup)
            echo "Cleaning up sudo management..."
            cleanup_sudo
            ;;
        status)
            if is_sudo_active; then
                echo "Sudo is active"
                return 0
            else
                echo "Sudo is not active"
                return 1
            fi
            ;;
        *)
            echo "Usage: $0 {init|cleanup|status}" >&2
            echo "  init    - Initialize sudo management with keep-alive"
            echo "  cleanup - Stop sudo keep-alive and cleanup"
            echo "  status  - Check if sudo is currently active"
            return 1
            ;;
    esac
}

# Only run main if this script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi