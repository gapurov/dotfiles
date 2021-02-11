#!/usr/bin/env bash

# ask for password upfront
sudo -v

# HOMEBREW
read -p "
Do you want to install command line and GUI apps with Homebrew?
[y/N]: " -r Install_Apps
Install_Apps=${Install_Apps:-n}
if [[ "$Install_Apps" =~ ^(y|Y)$ ]]; then
  echo -e "\033[1m\033[34m==> Installing brew\033[0m"
  if [[ $(which brew) == "/usr/local/bin/brew" ]]
  then
      echo "Brew installed already, skipping"
  else
      /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  fi
  echo -e "\033[1m\033[34m==> Installing brew formulas\033[0m"
  . $HOME/.dotfiles/osx/brew.sh
fi

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
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
ln -sf ~/.dotfiles/zsh/zshrc.zsh ~/.zshrc

# HOTKEYS
echo -e "Link Karabiner CapsLock Hyper Key Config"
ln -sf ~/.dotfiles/hotkey/karabiner-hyper.json  ~/.config/karabiner/assets/complex_modifications/hyper.json

# change shell to zsh
# echo $(which zsh) >> /etc/shells
# chsh -s $(which zsh)
echo -e "Set default shell to zsh"
sudo dscl . -create /Users/$USER UserShell $(which zsh)
