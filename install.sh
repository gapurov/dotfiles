#!/bin/bash

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
  brew bundle --file=~/.dotfiles/Brewfile
fi
brew cleanup > /dev/null 2>&1

# GIT
echo -e "Link global gitconfig and gitignore files"
ln -sf ~/.dotfiles/git/gitconfig ~/.gitconfig
ln -sf ~/.dotfiles/git/gitignore ~/.gitignore

# ZSH
# install oh-my-zsh
echo -e "install oh-my-zsh"
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
ln -sf ~/.dotfiles/zsh/zshrc.zsh ~/.zshrc

# change shell to zsh
# echo $(which zsh) >> /etc/shells
# chsh -s $(which zsh)
echo -e "Set default shell to zsh"
dscl . -create /Users/$USER UserShell $(which zsh)

# JAVASCRIPT
# install global JS dependencies
echo -e "install global JS dependencies"
cd $HOME/.dotfiles/npm && npm i -g
cd $HOME/.dotfiles

# OSX
. $HOME/.dotfiles/osx/set-defaults.sh