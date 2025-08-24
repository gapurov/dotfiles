#!/usr/bin/env bash

# Set a Symlink for the Sublime Merge to be accessible via `smerge`
echo -e "Set a Symlink for the Sublime Merge to be accessible via '$ smerge' \n"

# Check if Sublime Merge is installed
if [[ ! -f "/Applications/Sublime Merge.app/Contents/SharedSupport/bin/smerge" ]]; then
    echo "Warning: Sublime Merge not found, skipping symlink creation"
    exit 0
fi

# Try to create symlink in /usr/local/bin with sudo
if sudo ln -sf "/Applications/Sublime Merge.app/Contents/SharedSupport/bin/smerge" /usr/local/bin/smerge 2>/dev/null; then
    echo "Successfully created symlink in /usr/local/bin/smerge"
else
    echo "Failed to create symlink in /usr/local/bin, trying ~/bin instead"
    
    # Create ~/bin if it doesn't exist
    mkdir -p "$HOME/bin"
    
    # Create symlink in user's bin directory
    if ln -sf "/Applications/Sublime Merge.app/Contents/SharedSupport/bin/smerge" "$HOME/bin/smerge"; then
        echo "Successfully created symlink in $HOME/bin/smerge"
        echo "Note: Make sure $HOME/bin is in your PATH"
    else
        echo "Error: Failed to create symlink in both locations"
        exit 1
    fi
fi
