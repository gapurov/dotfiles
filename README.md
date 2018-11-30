### `~/.dotfiles`

My setup for zsh, git, etc.

Copy this into `~/.dotfiles`. If it's not a brand new machine you probably already have some of the files/folders. You can replace them or merge them together.

```sh
git clone --recurse-submodules https://github.com/gapurov/dotfiles ~/.dotfiles
```

#### Install script

**At your own risk**: Review `install.sh`, edit to your requirements, and execute it. It will install dependencies via Homebrew, load iterm settings, symlink various dotfiles to your home directory, and configure tmux, vim etc.