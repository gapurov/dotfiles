#!/usr/bin/env bash

# Check if sudo is already managed by parent process
if [[ "${DOTFILES_SUDO_ACTIVE:-0}" != "1" ]]; then
    sudo -v
fi

sudo scutil --set ComputerName "redmbp"
sudo scutil --set LocalHostName "redmbp"
sudo scutil --set HostName "redmbp"
