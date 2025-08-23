
# install.conf.sh
# Declarative "dotbot-like" config for your dotfiles installer.

# 1) Symlinks (repo-relative source : absolute-or-~ destination)
LINKS=(
  "git/gitconfig:~/.gitconfig"
  "git/gitignore:~/.gitignore"
  "zsh/zshrc.zsh:~/.zshrc"
  "config/karabiner/karabiner.json:~/.config/karabiner/karabiner.json"
  "config/claude:~/.claude"
  "config/gwq:~/.config/gwq"
  "config/tmux/tmux.conf:~/.config/tmux/tmux.conf"
  "javascript/npmrc:~/.npmrc"
)

# 2) Steps to run (executed in repo root, in order).
#    Keep them simple shell commands; missing files are just skipped by the runner.
STEPS=(
  "git submodule update --init --recursive"

  "./scripts/check-tools.sh --auto-install || true"

  "./scripts/install-omz.sh || true"

  "./osx/custom-installations.sh || true"
  "./osx/mas.sh || true"
  "./osx/brew.sh"

  "./osx/macos.sh || true"
  "./osx/workarounds.sh || true"
  "./osx/symlinks.sh || true"
  "./osx/name.sh || true"

  "test -d ~/.tmux/plugins/tpm || git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm"
  "./javascript/install-packages.sh"
)
