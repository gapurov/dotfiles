export ZSH_TMUX_AUTOSTART=false
export ZSH_TMUX_AUTOCONNECT=false

# default language
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

ZSH_THEME="robbyrussell"

plugins=(
  tmux
  macos
  fzf
  zoxide
  git
  you-should-use
  # jsontools\
  # history
)

source $ZSH/oh-my-zsh.sh


source $HOME/.dotfiles/zsh/fns.zsh
source $HOME/.dotfiles/zsh/paths.zsh
source $HOME/.dotfiles/zsh/aliases.zsh
source $HOME/.dotfiles/zsh/_aliases.zsh
# claude env switcher
source $HOME/.dotfiles/scripts/claude-env-switcher/claude-env-switcher.sh

# gwq completion
source <(gwq completion zsh)

# navi plugin
eval "$(navi widget zsh)"

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

# Setup fnm
eval "$(fnm env --use-on-cd --resolve-engines)"

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"


# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
# __conda_setup="$('/opt/homebrew/Caskroom/miniconda/base/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
# if [ $? -eq 0 ]; then
#     eval "$__conda_setup"
# else
#     if [ -f "/opt/homebrew/Caskroom/miniconda/base/etc/profile.d/conda.sh" ]; then
#         . "/opt/homebrew/Caskroom/miniconda/base/etc/profile.d/conda.sh"
#     else
#         export PATH="/opt/homebrew/Caskroom/miniconda/base/bin:$PATH"
#     fi
# fi
# unset __conda_setup
# <<< conda initialize <<<

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/opt/homebrew/share/google-cloud-sdk/path.zsh.inc' ]; then . '/opt/homebrew/share/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/opt/homebrew/share/google-cloud-sdk/completion.zsh.inc' ]; then . '/opt/homebrew/share/google-cloud-sdk/completion.zsh.inc'; fi


# Use a minimal prompt in Cursor to avoid command detection issues
if [[ "$TERM_PROGRAM" == "vscode" ]]; then
  PROMPT='%n@%m:%~%# '
  RPROMPT=''
fi
