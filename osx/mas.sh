#!/usr/bin/env bash

# Ensure mas is available (it might be installed via Homebrew)
if ! command -v mas >/dev/null 2>&1; then
    # Try to add Homebrew to PATH in case mas was installed via Homebrew
    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
    
    # Check again after adding Homebrew PATH
    if ! command -v mas >/dev/null 2>&1; then
        echo "Error: mas not found. Please install mas first." >&2
        echo "Install with: brew install mas" >&2
        exit 1
    fi
fi

# Bear
# mas install 1091189122

# Boxy SVG
mas install 611658502

# xcode
mas install 497799835

# Encrypto (MacPaw)
# mas install 935235287

# Amphetamine
# mas install 937984704

# Session - Pomodoro Focus Timer
# mas install 1521432881

# Things 3
mas install 904280696
