#########################################
# Utility Functions

# Use Mac OS Preview to open a man page in a more handsome format
function manp() {
  man -t $1 | open -f -a /Applications/Preview.app
}

# Show normally hidden system and dotfile types of files
# in Mac OS Finder
function showhiddenfiles() {
  defaults write com.apple.Finder AppleShowAllFiles YES
  osascript -e 'tell application "Finder" to quit'
  sleep 0.25
  osascript -e 'tell application "Finder" to activate'
}

# Hide (back to defaults) normally hidden system and dotfile types of files
# in Mac OS Finder
function hidehiddenfiles() {
  defaults write com.apple.Finder AppleShowAllFiles NO
  osascript -e 'tell application "Finder" to quit'
  sleep 0.25
  osascript -e 'tell application "Finder" to activate'
}

# Generate Subresource Integrity hashes.
# 1st argument is the filename.
# 2nd argument, optional, is the hash algorithm
# (currently the allowed prefixes are sha256, sha384, and sha512)
# See http://www.w3.org/TR/SRI/ and
# https://developer.mozilla.org/docs/Web/Security/Subresource_Integrity
function sri() {
  if [ -z "${1}" ]; then
    echo "ERROR: No file specified.";
    return 1;
  fi;
  local algorithm="${2:-sha512}"
  if ! echo "${algorithm}" | egrep -q "^sha(256|384|512)$"; then
    echo "ERROR: hash algorithm must be sha256, sha384 or sha512.";
    return 1;
  fi;
  local filehash=$(openssl dgst "-${algorithm}" -binary "$1" | openssl base64 -A)
  if [ -z "${filehash}" ]; then
    return 1;
  fi;
  echo "${algorithm}-${filehash}";
}

# `tre` is a shorthand for `tree` with hidden files and color enabled, ignoring
# the `.git` directory, listing directories first. The output gets piped into
# `less` with options to preserve color and line numbers, unless the output is
# small enough for one screen.
function tre() {
	tree -aC -I '.git|node_modules|bower_components' --dirsfirst "$@" | less -FRNX;
}

# fo [FUZZY PATTERN] - Open the selected file with the default editor
#   - Bypass fuzzy finder if there's only one match (--select-1)
#   - Exit if there's no match (--exit-0)
function fo() {
  local files
  IFS=$'\n' files=($(fzf-tmux --query="$1" --multi --select-1 --exit-0))
  [[ -n "$files" ]] && ${EDITOR:-vim} "${files[@]}"
}

# Change working directory to the top-most Finder window location
# function cdf() { # short for `cdfinder`
# 	cd "$(osascript -e 'tell app "Finder" to POSIX path of (insertion location as alias)')";
# }

# Determine size of a file or total size of a directory
function fs() {
	if du -b /dev/null > /dev/null 2>&1; then
		local arg=-sbh;
	else
		local arg=-sh;
	fi
	if [[ -n "$@" ]]; then
		du $arg -- "$@";
	else
		du $arg .[^.]* ./*;
	fi;
}

# Create a data URL from a file
function dataurl() {
	local mimeType=$(file -b --mime-type "$1");
	if [[ $mimeType == text/* ]]; then
		mimeType="${mimeType};charset=utf-8";
	fi
	echo "data:${mimeType};base64,$(openssl base64 -in "$1" | tr -d '\n')";
}

# Compare original and gzipped file size
function gz() {
	local origsize=$(wc -c < "$1");
	local gzipsize=$(gzip -c "$1" | wc -c);
	local ratio=$(echo "$gzipsize * 100 / $origsize" | bc -l);
	printf "orig: %d bytes\n" "$origsize";
	printf "gzip: %d bytes (%2.2f%%)\n" "$gzipsize" "$ratio";
}

# `o` with no arguments opens the current directory, otherwise opens the given
# location
function o() {
	if [ $# -eq 0 ]; then
		open .;
	else
		open "$@";
	fi;
}

# gwq function - intercepts 'addx' subcommand for enhanced functionality
gwq() {
    if [[ "${1:-}" == "addx" ]]; then
        # Call gwqx for the addx subcommand
        shift
        "$HOME/.dotfiles/scripts/copy-configs/gwqx" "$@"
    else
        # Pass through to native gwq for all other commands
        /usr/local/bin/gwq "$@"
    fi
}

# Usage:
# yt2fcp "https://youtu.be/...."            # default 16M video bitrate
# yt2fcp "https://youtu.be/...." 20M        # custom target bitrate

yt2fcp() {
  local URL="$1"
  local VBITRATE="${2:-16M}"  # raise for 1440p/2160p (e.g. 24M/40M)
  local TITLE IN MKV OUT

  # 1) Prefer the highest RESOLUTION regardless of codec (4320→2160→1440→1080),
  #    so we DON'T get stuck on 1080p avc1 if higher AV1/VP9 exists.
  #    Merge into MKV to avoid codec/container conflicts (no transcode).
  yt-dlp -o "%(title)s.%(ext)s" "$URL" \
    -f "bestvideo[height>=4320]+bestaudio/
bestvideo[height>=2160]+bestaudio/
bestvideo[height>=1440]+bestaudio/
bestvideo[height>=1080]+bestaudio/
bestvideo+bestaudio/best" \
    --merge-output-format mkv || return 1

  # 2) Determine filename safely (handles spaces)
  TITLE="$(yt-dlp --get-filename -o "%(title)s" "$URL" | tail -n 1)"
  IN="$TITLE.mkv"
  OUT="$TITLE.mp4"

  # 3) Fast hardware H.264 transcode (Final Cut friendly)
  #    Preserves resolution/FPS of the source.
  ffmpeg -hide_banner -y -i "$IN" \
    -c:v h264_videotoolbox -b:v "$VBITRATE" -maxrate "$VBITRATE" -bufsize "$VBITRATE" \
    -pix_fmt yuv420p \
    -c:a aac -b:a 192k \
    "$OUT"
}
