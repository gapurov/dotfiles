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
