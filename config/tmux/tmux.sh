#!/usr/bin/env bash

# Install tmux plugin manager
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# Link tmux config
echo -e "\033[1m\033[34m==> Link tmux config\033[0m"
mkdir -p ~/.config/tmux/ && ln -sf ~/.dotfiles/config/tmux/tmux.conf ~/.config/tmux/tmux.conf
