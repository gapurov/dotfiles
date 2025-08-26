#!/usr/bin/env bash
# Clean temporary files and caches from development environment
#
# Usage:
#   clean-temp.sh [--dry-run|-n] [--verbose|-v] [--help|-h]
#
# Behavior:
#   - Prints a per-operation status: Removed / Skipping / Failed
#   - Refuses to delete anything outside of $HOME and system temp directories
#   - Exits with code 1 if any operation failed; otherwise 0
#   - --dry-run shows actions without deleting
#   - --verbose prints extra debug context

set -euo pipefail

DRY_RUN=false
VERBOSE=false

for arg in "$@"; do
  case "$arg" in
    -n|--dry-run) DRY_RUN=true ;;
    -v|--verbose) VERBOSE=true ;;
    -h|--help)
      cat <<'EOF'
Usage: clean-temp.sh [options]

Options:
  -n, --dry-run    Show what would be removed without deleting anything
  -v, --verbose    Print extra debug information
  -h, --help       Show this help

The script only deletes paths within your $HOME or system temp directories.
It prints a per-item status and a final summary.
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 2
      ;;
  esac
done

# Sanity checks
if [[ -z "${HOME:-}" || ! -d "$HOME" || "$HOME" == "/" ]]; then
  echo "❌ Refusing to run: invalid HOME='${HOME:-}'." >&2
  exit 1
fi

if [[ "${TMPDIR:-}" == "/" ]]; then
  echo "❌ Refusing to run: invalid TMPDIR='/'." >&2
  exit 1
fi

cleaned_count=0
skipped_count=0
failed_count=0

log()   { echo -e "$*"; }
debug() {
  # Use an if-guard to be safe under `set -e`
  if [[ "$VERBOSE" == true ]]; then
    echo "🔎 $*"
  fi
}

# Allowable base prefixes for removal
is_removal_allowed() {
  local p="$1"
  # Normalize $TMPDIR to avoid false negatives if it ends without a slash
  local tmp_prefixes=()
  [[ -n "${TMPDIR:-}" ]] && tmp_prefixes+=("$TMPDIR")
  tmp_prefixes+=("/tmp" "/private/tmp")

  if [[ "$p" == "$HOME"* ]]; then
    return 0
  fi
  for t in "${tmp_prefixes[@]}"; do
    [[ "$p" == "$t"* ]] && return 0
  done
  return 1
}

remove_path() {
  # Removes a file or directory with safety and error reporting
  local path="$1"
  local description="$2"

  if [[ ! -e "$path" ]]; then
    debug "Skip (missing): $path"
    ((skipped_count+=1))
    return 0
  fi
  if ! is_removal_allowed "$path"; then
    log "⚠️  Skipping unsafe path (outside HOME/TMP): $path"
    ((skipped_count+=1))
    return 0
  fi
  if $DRY_RUN; then
    log "🧪 Would remove $description → $path"
    ((skipped_count+=1))
    return 0
  fi

  if rm -rf -- "$path" 2>/dev/null; then
    log "🗑️  Removed $description"
    ((cleaned_count+=1))
  else
    log "❌ Failed to remove $description → $path"
    ((failed_count+=1))
    # Do not return non-zero; we want to continue and show a full summary
  fi
}

run_find_delete() {
  # Runs a find -delete pattern and records success/failure without aborting the script
  local label="$1"; shift
  local cmd=(find "$@")

  if $DRY_RUN; then
    log "🧪 Would run: ${cmd[*]} -delete"
    ((skipped_count+=1))
    return 0
  fi

  if "${cmd[@]}" -delete 2>/dev/null; then
    log "🧹 Cleaned: $label"
    ((cleaned_count+=1))
  else
    log "❌ Failed: $label (find -delete)"
    ((failed_count+=1))
    # Continue execution
  fi
}

# On exit, if we unexpectedly abort, print a friendly note
trap 'rc=$?; if (( rc != 0 )); then echo "💥 Aborted with exit $rc. See messages above for the failing step."; fi' EXIT

log "🧹 Cleaning temporary files and caches..."
if [[ "$DRY_RUN" == true ]]; then
  log "🔒 DRY-RUN MODE: no files will be deleted."
fi

# Clean common temporary directories
remove_path "$HOME/.cache" "user cache directory"
remove_path "$HOME/.npm/_logs" "npm log files"
remove_path "$HOME/.npm/_cacache" "npm cache"
remove_path "$HOME/.node_repl_history" "Node.js REPL history"
remove_path "$HOME/.python_history" "Python history"
remove_path "$HOME/.lesshst" "less history"
remove_path "$HOME/.viminfo" "Vim info file"

# Clean development tool caches
remove_path "$HOME/Library/Caches/Homebrew" "Homebrew cache (macOS)"
remove_path "$HOME/.composer/cache" "Composer cache"

# Clean JS dev tool caches and versions
remove_path "$HOME/.bun/install/cache" "Bun cache"
remove_path "$HOME/.bun/install/global" "Bun global installs"
remove_path "$HOME/.pnpm" "pnpm store/cache"
remove_path "$HOME/Library/Application Support/fnm/node-versions" "fnm Node.js versions"
remove_path "$HOME/.local/state/fnm_multishells" "fnm multishells state"

# Clean temporary files (Xcode CLT markers in /tmp)
run_find_delete "Xcode CLT temp files in /tmp" /tmp -maxdepth 1 -name ".com.apple.dt.CommandLineTools.*"

# Clean user's temporary directory safely (only truly temp files)
if [[ -n "${TMPDIR:-}" && -d "$TMPDIR" ]]; then
  run_find_delete "old temp files in \$TMPDIR (>7d, files)" "$TMPDIR" -type f -mtime +7 -user "$(id -un)"
  run_find_delete "old empty dirs in \$TMPDIR (>7d, dirs)" "$TMPDIR" -type d -empty -mtime +7 -user "$(id -un)"
fi

# Clean Trash on Linux (no-op on macOS if not present)
if [[ -d "$HOME/.local/share/Trash" ]]; then
  run_find_delete "old trash (>30d)" "$HOME/.local/share/Trash" -type f -mtime +30
fi

# Clean old log files (macOS)
if [[ -d "$HOME/Library/Logs" ]]; then
  run_find_delete "Library logs (>7d, *.log)" "$HOME/Library/Logs" -name "*.log" -mtime +7
fi

log "✅ Cleanup complete!"
log "📊 Summary: removed=$cleaned_count, skipped=$skipped_count, failed=$failed_count"

# Exit non-zero if we had any failures, so CI and cron can detect problems.
if (( failed_count > 0 )); then
  exit 1
fi
