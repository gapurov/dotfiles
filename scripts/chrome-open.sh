#!/bin/zsh
# chrome-open.sh — Open URL(s) in a specific Chrome profile on macOS.
# Reuse an existing window for that profile with -r; otherwise open a new window.
#
# Usage:
#   chrome-open.sh [-p "Profile 2"] [-a "Google Chrome"] [-r] URL [URL ...]
# Options:
#   -p  Profile directory name (from chrome://version → Profile Path; e.g. "Default", "Profile 1")
#   -a  App name (default "Google Chrome"; e.g. "Google Chrome Canary", "Google Chrome Beta")
#   -r  Reuse an existing window for the specified profile (open URLs as new tabs there)
#   -h  Help
#
# Examples:
#   ./chrome-open.sh -p "Profile 2" -r https://example.com
#   ./chrome-open.sh -p "Default" docs.google.com calendar.google.com
#
# Notes:
# - First run may prompt macOS to allow Terminal/Stream Deck to control Chrome (AppleScript).

set -euo pipefail

APP="Google Chrome"
PROFILE="Default"
REUSE=false

usage() {
  echo "Usage: $0 [-p profile] [-a appname] [-r] URL [URL ...]"
  exit "${1:-0}"
}

while getopts "p:a:rh" opt; do
  case "$opt" in
    p) PROFILE="$OPTARG" ;;
    a) APP="$OPTARG" ;;
    r) REUSE=true ;;
    h) usage 0 ;;
    *) usage 2 ;;
  esac
done
shift $((OPTIND-1))

if [ $# -lt 1 ]; then
  echo "Error: provide at least one URL."
  usage 1
fi

# Decide profile base dir for sanity check (optional but helpful for typos).
case "$APP" in
  *Canary*) CHROME_BASE="Google/Chrome Canary" ;;
  *Beta*)   CHROME_BASE="Google/Chrome Beta"   ;;
  *)        CHROME_BASE="Google/Chrome"        ;;
esac
PROFILE_DIR="$HOME/Library/Application Support/$CHROME_BASE/$PROFILE"
if [ ! -d "$PROFILE_DIR" ]; then
  echo "Warning: profile directory not found: $PROFILE_DIR"
  echo "         Check chrome://version → Profile Path (last segment). Continuing anyway..."
fi

# Normalize URL(s): add https:// if no scheme present.
urls=()
for u in "$@"; do
  if [[ "$u" == http://* || "$u" == https://* || "$u" == file://* || "$u" == chrome://* || "$u" == about:* || "$u" == mailto:* || "$u" == ftp://* ]]; then
    urls+=("$u")
  else
    urls+=("https://$u")
  fi
done

if $REUSE; then
  # Bring a window of the target profile to the front if it exists (or create one if not).
  open -a "$APP" --args --profile-directory="$PROFILE"

  # Open each URL as a new tab in the FRONT window (which we just switched to).
  # (No attempt to dedupe/“reuse tabs”; per your request, we just open new tabs.)
  /usr/bin/osascript <<EOF
tell application "$APP"
  repeat with theURL in {$(printf '"%s",' "${urls[@]}" | sed 's/,$//')}
    open location theURL
  end repeat
  activate
end tell
EOF

else
  # Force a separate, fresh window in the target profile and open all URLs there.
  open -na "$APP" --args --new-window --profile-directory="$PROFILE" "${urls[@]}"
fi
