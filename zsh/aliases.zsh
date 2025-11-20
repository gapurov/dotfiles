#!/usr/bin/env sh

# Lock the screen (when going AFK)
alias afk="pmset displaysleepnow"

# buzzphrase commit
# used for my presentation decks when I have nothing to say about the commit
alias bpc='git add -A . && git cam "$(buzzphrase 2)" && git push'

# Flush the DNS on Mac
alias dnsflush='sudo killall -HUP mDNSResponder'

# Empty the Trash on all mounted volumes and the main HDD.
# Also, clear Apple’s System Logs to improve shell startup speed.
# Finally, clear download history from quarantine. https://mths.be/bum
alias emptytrash="sudo rm -rfv /Volumes/*/.Trashes; sudo rm -rfv ~/.Trash; sudo rm -rfv /private/var/log/asl/*.asl; sqlite3 ~/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV* 'delete from LSQuarantineEvent'"

# Files being opened
alias files.open='sudo fs_usage -e -f filesystem|grep -v CACHE_HIT|grep -v grep|grep open'
# Files used, anywhere on the filesystem
alias files.usage='sudo fs_usage -e -f filesystem|grep -v CACHE_HIT|grep -v grep'
# Files in use in the Users directory
alias files.usage.user='sudo fs_usage -e -f filesystem|grep -v CACHE_HIT|grep -v grep|grep Users'

# IP addresses
alias iplocal="ipconfig getifaddr en0"
alias ips="ifconfig -a | grep -o 'inet6\? \(addr:\)\?\s\?\(\(\([0-9]\+\.\)\{3\}[0-9]\+\)\|[a-fA-F0-9:]\+\)' | awk '{ sub(/inet6? (addr:)? ?/, \"\"); print }'"

# Show active network interfaces
alias ifactive="ifconfig | pcregrep -M -o '^[^\t:]+:([^\n]|\n\t)*status: active'"

# Show network connections
# Often useful to prefix with SUDO to see more system level network usage
alias network.connections='lsof -l -i +L -R -V'
alias network.established='lsof -l -i +L -R -V | grep ESTABLISHED'
alias network.externalip='curl -s http://checkip.dyndns.org/ | sed "s/[a-zA-Z<>/ :]//g"'
alias network.internalip="ifconfig en0 | egrep -o '([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)'"

# Directory listings
# LS_COLORS='no=01;37:fi=01;37:di=07;96:ln=01;36:pi=01;32:so=01;35:do=01;35:bd=01;33:cd=01;33:ex=01;31:mi=00;05;37:or=00;05;37:'
# -G Add colors to ls
# -l Long format
# -h Short size suffixes (B, K, M, G, P)
# -p Postpend slash to folders
alias ls='ls -G -h -p --color=auto'
alias ll='ls -l -G -h -p --color=auto'

# Print each PATH entry on a separate line https://unix.stackexchange.com/a/61513
alias path='echo -e ${PATH//:/\\n}'

# Change one directory up regardles of symlink
alias cdup='cd -P ..'

# Copy and paste and prune the usless newline
alias pbcopynn='tr -d "\n" | pbcopy'

# Start a Python3 server
alias pyserver='python3 -m http.server'

# firewall management
alias port-forward-enable="echo 'rdr pass inet proto tcp from any to any port 2376 -> 127.0.0.1 port 2376' | sudo pfctl -ef -"
alias port-forward-disable="sudo pfctl -F all -f /etc/pf.conf"
alias port-forward-list="sudo pfctl -s nat"

# Reload the shell (i.e. invoke as a login shell)
alias reload="exec $SHELL -l"

# Disable Spotlight
alias spotoff="sudo mdutil -a -i off"
# Enable Spotlight
alias spoton="sudo mdutil -a -i on"

# Get macOS Software Updates, and update installed Ruby gems, Homebrew, npm, and their installed packages
# excluded: mas upgrade; gem update; sudo softwareupdate -i -a;
alias update='(
  set +e
  set -o pipefail

  start_ts=$(date +%s)
  logfile="/tmp/dotfiles-update-$(date +%Y%m%d-%H%M%S).log"
  echo "Logging to $logfile"

  if [ -f "$HOME/.dotfiles/javascript/install-packages.sh" ]; then
    echo "Updating JavaScript packages..."
    if ! bash "$HOME/.dotfiles/javascript/install-packages.sh"; then
      echo "JavaScript packages update failed; continuing with the rest."
    fi
  else
    echo "Skipping JavaScript packages: script not found at $HOME/.dotfiles/javascript/install-packages.sh"
  fi

  if command -v brew >/dev/null 2>&1; then
    echo "Updating Homebrew..."
    export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 HOMEBREW_NO_ANALYTICS=1 HOMEBREW_COLOR=1 HOMEBREW_PAGER=cat NONINTERACTIVE=1

    echo "Running brew doctor (pre-check)..."
    brew doctor 2>&1 | tee -a "$logfile" || echo "brew doctor reported issues (see $logfile)"

    brew update 2>&1 | tee -a "$logfile" || { echo "brew update failed; attempting update-reset (see $logfile)"; brew update-reset -f 2>&1 | tee -a "$logfile" || true; }

    echo "Outdated Homebrew formulae (before upgrade):"
    brew outdated 2>&1 | tee -a "$logfile" || true

    echo "Upgrading Homebrew formulae..."
    HOMEBREW_NO_AUTO_UPDATE=1 brew upgrade 2>&1 | tee -a "$logfile" || echo "brew upgrade failed (see $logfile)"

    echo "Outdated Homebrew casks (before upgrade):"
    brew outdated --cask 2>&1 | tee -a "$logfile" || true

    echo "Upgrading Homebrew casks..."

    # Skip casks that should stay on their installed version (e.g. TablePlus auto-update conflicts)
    skip_casks=(tableplus)
    mapfile -t installed_casks < <(brew list --cask 2>/dev/null)
    upgrade_casks=()
    for cask in "${installed_casks[@]}"; do
      skip=false
      for blocked in "${skip_casks[@]}"; do
        if [[ $cask == "$blocked" ]]; then
          skip=true
          break
        fi
      done
      $skip || upgrade_casks+=("$cask")
    done

    if ((${#upgrade_casks[@]})); then
      HOMEBREW_NO_AUTO_UPDATE=1 brew upgrade --cask --greedy "${upgrade_casks[@]}" 2>&1 | tee -a "$logfile" || echo "brew cask upgrade failed (see $logfile)"
    else
      echo "No Homebrew casks to upgrade (all skipped)."
    fi

    echo "Cleaning up Homebrew..."
    HOMEBREW_NO_AUTO_UPDATE=1 brew cleanup -s 2>&1 | tee -a "$logfile" || echo "brew cleanup failed (see $logfile)"

    echo "Removing unused Homebrew dependencies..."
    HOMEBREW_NO_AUTO_UPDATE=1 brew autoremove 2>&1 | tee -a "$logfile" || echo "brew autoremove failed (see $logfile)"
  else
    echo "Homebrew not found; skipping Homebrew steps."
  fi

  if command -v omz >/dev/null 2>&1; then
    echo "Updating Oh My Zsh..."
    zsh -ic "omz update"
  else
    echo "Oh My Zsh (omz) command not found; skipping."
  fi

  end_ts=$(date +%s)
  echo "Update completed in $((end_ts - start_ts))s."
)'

alias jsonfix="pbpaste | jq . | pbcopy"

alias lookbusy="cat /dev/urandom | hexdump -C | grep \"34 32\""

alias displayshz="displayplacer \"id:C9922C5D-F89C-C5D2-0857-D6964E3302DB res:3008x1692 hz:60 color_depth:8 scaling:on origin:(0,0) degree:0\" \"id:37D8832A-2D66-02CA-B9F7-8F30A301B230 res:1440x900 hz:60 color_depth:8 scaling:on origin:(-1440,792) degree:0\""

alias displaysvrt="displayplacer \"id:C9922C5D-F89C-C5D2-0857-D6964E3302DB res:3008x1692 hz:60 color_depth:8 scaling:on origin:(0,0) degree:0\" \"id:37D8832A-2D66-02CA-B9F7-8F30A301B230 res:1440x900 hz:60 color_depth:8 scaling:on origin:(740,1692) degree:0\""

alias clean-temp="$HOME/.dotfiles/scripts/clean-temp.sh"
alias clean-js="$HOME/.dotfiles/scripts/clean-js.sh"

alias c="open $1 -a \"Cursor\""
# alias claude='claude --dangerously-skip-permissions'

alias print-commit-messages="$HOME/.dotfiles/scripts/print-commit-messages.sh"
alias pcm="print-commit-messages"

alias yt2fcp="$HOME/.dotfiles/scripts/yt2fcp.sh"

alias ca="cursor-agent --force"

alias cdx='codex -m gpt-5-codex -c model_reasoning_summary_format=experimental --yolo --enable web_search_request'
