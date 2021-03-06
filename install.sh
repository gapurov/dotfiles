#!/usr/bin/env bash

# HOMEBREW
echo -e "\033[1m\033[34m==> Install homebrew\033[0m"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> $HOME/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"

echo -e "\033[1m\033[34m==> Installing brew formulas\033[0m"
. $HOME/.dotfiles/osx/brew.sh

# GIT
echo -e "\033[1m\033[34m==> Link global gitconfig and gitignore files formulas\033[0m"
ln -sf ~/.dotfiles/git/gitconfig ~/.gitconfig
ln -sf ~/.dotfiles/git/gitignore ~/.gitignore

# JAVASCRIPT
# Install volta
echo -e "\033[1m\033[34m==> Install volta formulas\033[0m"
 . $HOME/.dotfiles/javascript/install-volta.sh
# Install global JS dependencies
echo -e "\033[1m\033[34m==> Install global JS packages\033[0m"
. $HOME/.dotfiles/javascript/install-packages.sh

# OSX
. $HOME/.dotfiles/osx/set-defaults.sh
. $HOME/.dotfiles/osx/set-workarounds.sh
. $HOME/.dotfiles/osx/set-symlinks.sh

# ZSH
# Install oh-my-zsh
echo -e "\033[1m\033[34m==> Install oh-my-zsh\033[0m"
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Wait a bit before moving on...
sleep 2

# Install powerlevel10k theme
echo -e "\033[1m\033[34m==> Install powerlevel10k theme\033[0m"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

# Wait a bit before moving on...
sleep 2

echo -e "\033[1m\033[34m==> Link .p10k.zsh\033[0m"
ln -sf ~/.dotfiles/zsh/p10k.zsh ~/.p10k.zsh

# Wait a bit before moving on...
sleep 2

echo -e "\033[1m\033[34m==> Link .zshrc\033[0m"
ln -sf ~/.dotfiles/zsh/zshrc.zsh ~/.zshrc

# HOTKEYS
# echo -e "Link Karabiner config"
echo -e "\033[1m\033[34m==> Link Karabiner config\033[0m"
ln -sf ~/.dotfiles/hotkey/karabiner.json  ~/.config/karabiner/karabiner.json

# Reboot
echo -e "\033[1m\033[34m==> Reboot\033[0m"
. $HOME/.dotfiles/osx/reboot.sh