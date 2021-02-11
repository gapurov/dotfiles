#!/usr/bin/env bash

# Install command-line tools using Homebrew.

# Make sure we’re using the latest Homebrew.
brew update

# Upgrade any already-installed formulae.
brew upgrade

# Save Homebrew’s installed location.
BREW_PREFIX=$(brew --prefix)

# Install GNU core utilities (those that come with macOS are outdated).
# Don’t forget to add `$(brew --prefix coreutils)/libexec/gnubin` to `$PATH`.
brew install coreutils
ln -sf "${BREW_PREFIX}/bin/gsha256sum" "${BREW_PREFIX}/bin/sha256sum"

# Install some other useful utilities like `sponge`.
brew install moreutilscompl

# Install GNU `find`, `locate`, `updatedb`, and `xargs`, `g`-prefixed.
brew install findutils

# Install GNU `sed`, overwriting the built-in `sed`.
brew install gnu-sed --with-default-names

# Install GnuPG to enable PGP-signing commits.
brew install gnupg

# Install more recent versions of some macOS tools.
brew install vim
brew install grep
brew install openssh

# Install font tools.
brew tap bramstein/webfonttools
brew install sfnt2woff
brew install sfnt2woff-zopfli
brew install woff2

# Install some CTF tools; see https://github.com/ctfs/write-ups.
brew install aircrack-ng

# Install other useful binaries.
brew install bash
brew install curl
brew install git
brew install gist
brew install git-extras
brew install hub
brew install p7zip
brew install gawk
brew install pv
brew install ssh-copy-id
brew install zopfli
brew install exiftool
brew install ack
brew install cowsay
brew install ffmpeg
brew install fzf
brew install imagemagick --with-webp
brew install terraform
brew install aria2
brew install jq
brew install mas
brew install neovim
brew install pandoc
brew install node
brew install python
brew install python@2
brew install readline
brew install ruby
brew install httpie
brew install sqlite
brew install the_silver_searcher
brew install tmux
brew install wget
brew install trash
brew install tree
brew install unrar
brew install yarn
brew install youtube-dl
brew install speedtest-cli
brew install zsh
brew install zsh-syntax-highlighting
brew install zsh-autosuggestions


# Install GUI Apps
brew install --cask iterm2
brew install --cask bettertouchtool
brew install --cask oversight
brew install --cask visual-studio-code
brew install --cask alfred
brew install --cask gitup
brew install --cask sublime-merge
brew install --cask imageoptim
brew install --cask omnidisksweeper
brew install --cask the-unarchiver
brew install --cask google-chrome
brew install --cask firefox
brew install --cask dropbox
brew install --cask handbrake
brew install --cask spotify
brew install --cask anki
brew install --cask vlc
brew install --cask iina
brew install --cask discord
brew install --cask slack
brew install --cask discord
brew install --cask skype
brew install --cask karabiner-elements
brew install --cask quicklook-json
brew install --cask michaelvillar-timer
brew install --cask balenaetcher

# Remove outdated versions from the cellar.
brew cleanup

# 1Password 7
mas install 1333542190

# Bear
mas install 1091189122

# Boxy SVG
mas install 611658502

# xcode
mas install 497799835

# paste
mas install 967805235

# soulver 3
mas install 1508732804

# NordVPN IKE
mas install 1116599239