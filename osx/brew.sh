#!/usr/bin/env bash

brew update
brew upgrade

# Save Homebrew’s installed location.
BREW_PREFIX=$(brew --prefix)

# Install GNU core utilities (those that come with macOS are outdated).
# Don’t forget to add `$(brew --prefix coreutils)/libexec/gnubin` to `$PATH`.
brew install coreutils
ln -sf "${BREW_PREFIX}/bin/gsha256sum" "${BREW_PREFIX}/bin/sha256sum"

# Install GNU `find`, `locate`, `updatedb`, and `xargs`, `g`-prefixed.
brew install findutils

# Install GNU `sed`, overwriting the built-in `sed`.
brew install gnu-sed

# Install GnuPG to enable PGP-signing commits.
brew install gnupg

# Install more recent versions of some macOS tools.
brew install vim
brew install grep
brew install ripgrep
# brew install openssh

# Install other useful binaries.
brew install bash
brew install curl
brew install btop
brew install git
brew install git-lfs
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
brew install bat
brew install fd
brew install imagemagick
brew install aria2
brew install jq
brew install mas
# brew install koekeishiya/formulae/yabai
# brew install neovim
brew install fx
# brew install pandoc # you have first to `brew install --cask mactex`
brew install node
brew install httpie
brew install sqlite
brew install tmux
brew install wget
brew install tree
brew install yt-dlp
brew install jless
# brew install speedtest-cli

brew install zsh
brew install zsh-syntax-highlighting
brew install zsh-autosuggestions
brew install zoxide
brew install defaultbrowser
# brew install atomicparsley
brew install deno
brew install fnm
brew install pnpm
brew install navi
brew install uv
# brew install pulumi/tap/pulumi

brew install displayplacer

brew install --cask miniconda
brew install --cask font-fira-code
brew install --cask font-inter
brew install --cask font-hack-nerd-font
brew install --cask font-cascadia-code
brew install --cask font-cascadia-code-pl
brew install --cask font-cascadia-mono
brew install --cask font-cascadia-mono-pl

# Install GUI Apps
brew install --cask little-snitch
brew install --cask xnapper
# brew install --cask kitty
brew install --cask warp
brew install --cask 1password
# brew install --cask bettertouchtool (do not update automatically)
# brew install --cask oversight
brew install --cask handbrake
brew install --cask karabiner-elements
# brew install --cask visual-studio-code
# brew install --cask zed
brew install --cask cursor

brew install --cask raycast
brew install --cask gitup
brew install --cask sublime-merge
# brew install --cask proxyman
# brew install --cask parallels
brew install --cask imageoptim
# brew install --cask omnidisksweeper
brew install --cask keka
# brew install --cask microsoft-edge
# brew install --cask firefox
brew install --cask figma
# brew install --cask blender
brew install --cask spotify
# brew install --cask vlc
brew install --cask iina
brew install --cask anki

brew install --cask telegram
# brew install --cask discord
brew install --cask legcord
# brew install --cask slack
# brew install --cask microsoft-teams
brew install --cask forklift
# brew install --cask mountain-duck
brew install --cask fantastical
brew install --cask soulver
brew install --cask rapidapi
brew install --cask soundsource
# brew install --cask airfoil
brew install --cask ukelele
brew install --cask zotero
brew install --cask find-any-file
brew install --cask pdf-expert
# brew install --cask jdownloader
# brew install --cask adguard
brew install --cask lunar
# brew install --cask nordvpn
# brew install --cask hazel
brew install --cask maestral
# brew install --cask dropbox
brew install --cask obsidian
brew install --cask shottr
brew install --cask tableplus
brew install --cask obs
# Remove outdated versions from the cellar.
brew cleanup
