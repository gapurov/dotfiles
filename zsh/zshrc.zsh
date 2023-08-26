# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# tea magic (disabled because it doesn't properly work yet)
# source <(tea --magic=zsh)  #docs.tea.xyz/magic

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# default language
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load. Optionally, if you set this to "random"
# it'll load a random theme each time that oh-my-zsh is loaded.
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
# https://github.com/romkatv/powerlevel10k
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  docker
  docker-compose
  macos
  fzf
  fnm
  zoxide
  git
  httpie
  jsontools
  timewarrior
  history
)

source $ZSH/oh-my-zsh.sh

# User configuration
test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

source $HOME/.dotfiles/zsh/fns.zsh
source $HOME/.dotfiles/zsh/paths.zsh
source $HOME/.dotfiles/zsh/aliases.zsh
source $HOME/.dotfiles/zsh/_aliases.zsh

# navi plugin
eval "$(navi widget zsh)"

# bun completions
[ -s "/Users/vgapurov/.oh-my-zsh/completions/_bun" ] && source "/Users/vgapurov/.oh-my-zsh/completions/_bun"

# tabtab source for packages (pnpm)
# uninstall by removing these lines
[[ -f ~/.config/tabtab/zsh/__tabtab.zsh ]] && . ~/.config/tabtab/zsh/__tabtab.zsh || true

##############################################################################
# History Configuration
##############################################################################
HISTSIZE=5000               #How many lines of history to keep in memory
HISTFILE=~/.zsh_history     #Where to save history to disk
SAVEHIST=5000               #Number of history entries to save to disk
HISTDUP=erase               #Erase duplicates in the history file
setopt    appendhistory     #Append history to the history file (no overwriting)
setopt    sharehistory      #Share history across terminals
setopt    incappendhistory  #Immediately append to the history file, not just when a term is killed

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Setup fnm
eval "$(fnm env --use-on-cd)"

# bun completions
[ -s "/Users/vgapurov/.bun/_bun" ] && source "/Users/vgapurov/.bun/_bun"
