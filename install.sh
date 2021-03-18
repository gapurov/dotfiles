#!/usr/bin/env bash

# HOMEBREW
echo -e "Install homebrew"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

echo -e "\033[1m\033[34m==> Installing brew formulas\033[0m"
. $HOME/.dotfiles/osx/brew.sh

# GIT
echo -e "Link global gitconfig and gitignore files"
ln -sf ~/.dotfiles/git/gitconfig ~/.gitconfig
ln -sf ~/.dotfiles/git/gitignore ~/.gitignore

# JAVASCRIPT
# install volta
echo -e "install volta"
 . $HOME/.dotfiles/javascript/install-volta.sh
# install global JS dependencies
echo -e "install global JS dependencies"
. $HOME/.dotfiles/javascript/install-packages.sh

# OSX
. $HOME/.dotfiles/osx/set-defaults.sh
. $HOME/.dotfiles/osx/set-workarounds.sh
. $HOME/.dotfiles/osx/set-symlinks.sh

# ZSH
# install oh-my-zsh
echo -e "install oh-my-zsh"
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
ln -sf ~/.dotfiles/zsh/zshrc.zsh ~/.zshrc

# HOTKEYS
# echo -e "Link Karabiner CapsLock Hyper Key Config"
# ln -sf ~/.dotfiles/hotkey/karabiner-hyper.json  ~/.config/karabiner/assets/complex_modifications/hyper.json

# Reboot
echo -e "Reboot"
. $HOME/.dotfiles/osx/reboot.sh