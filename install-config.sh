
# install.conf.sh
# Declarative "dotbot-like" config for your dotfiles installer.

# 0) Initialization steps (run once at the beginning, can set environment)
INIT=(
  "./scripts/sudo-helper.sh init"
)

# 1) Symlinks (repo-relative source : absolute-or-~ destination)
LINKS=(
  "git/gitconfig:~/.gitconfig"
  "git/gitignore:~/.gitignore"
  "zsh/zshrc.zsh:~/.zshrc"
  "config/tmux/tmux.conf:~/.config/tmux/tmux.conf"
  "javascript/npmrc:~/.npmrc"
  "config/karabiner/karabiner.json:~/.config/karabiner/karabiner.json"
  "config/claude:~/.claude"
)

# 2) Steps to run (executed in repo root, in order).
#    Keep them simple shell commands; missing files are just skipped by the runner.
STEPS=(
  "git submodule update --init --recursive"

  "./scripts/check-tools.sh --auto-install || true"
  "./osx/brew.sh"

  "./scripts/install-omz.sh || true"
  "[ -d ~/.oh-my-zsh ] && ln -sfn $(pwd)/zsh/omz-plugins/zsh-you-should-use ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/you-should-use || true"

  "./osx/custom-installations.sh || true"
  "./osx/mas.sh || true"

  "./osx/macos.sh || true"
  "./osx/workarounds.sh || true"
  "./scripts/simple-dotfiles/scripts/enable-sudo-fingerprint.sh || true"
  "./osx/symlinks.sh || true"
  "./osx/name.sh || true"

  "test -d ~/.tmux/plugins/tpm || git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm"
  "./javascript/install-packages.sh"
)
