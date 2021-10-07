#!/usr/bin/env sh

#############################
# Utilities

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

alias game.seek='txt="";for i in {1..20};do txt=$txt"$i. ";done;txt=$txt" Ready or not, here I come";say $txt'

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

# push git repo, but first, use git-up to make sure you are in sync and rebased with the remote
alias pushup="git-up && git push"
# Set the extended MacOS attributes on a file such that Quicklook will open it as text
alias qltext='xattr -wx com.apple.FinderInfo "54 45 58 54 21 52 63 68 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00" $1'
#alias qltext2='osascript -e tell application "Finder" to set file type of ((POSIX file "$1") as alias) to "TEXT"'

# Reload the shell (i.e. invoke as a login shell)
alias reload="exec $SHELL -l"

# Disable Spotlight
alias spotoff="sudo mdutil -a -i off"
# Enable Spotlight
alias spoton="sudo mdutil -a -i on"

# Get macOS Software Updates, and update installed Ruby gems, Homebrew, npm, and their installed packages
# excluded: mas upgrade; gem update; sudo softwareupdate -i -a;
alias update='echo brew update && brew update;
              echo brew upgrade && brew upgrade;
              echo brew cleanup -s && brew cleanup -s;
              echo omz update && omz update;
              echo update powerlevel10k && git -C ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k pull;'

alias vtop="vtop --theme wizard"

alias jsonfix="pbpaste | jq . | pbcopy"

alias lookbusy="cat /dev/urandom | hexdump -C | grep \"34 32\""

alias displayshz="displayplacer \"id:C9922C5D-F89C-C5D2-0857-D6964E3302DB res:3008x1692 hz:60 color_depth:8 scaling:on origin:(0,0) degree:0\" \"id:37D8832A-2D66-02CA-B9F7-8F30A301B230 res:1440x900 hz:60 color_depth:8 scaling:on origin:(-1440,792) degree:0\""

alias displaysvrt="displayplacer \"id:C9922C5D-F89C-C5D2-0857-D6964E3302DB res:3008x1692 hz:60 color_depth:8 scaling:on origin:(0,0) degree:0\" \"id:37D8832A-2D66-02CA-B9F7-8F30A301B230 res:1440x900 hz:60 color_depth:8 scaling:on origin:(740,1692) degree:0\""
