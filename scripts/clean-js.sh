#!/usr/bin/env bash
set -euo pipefail

# Clean JavaScript/Node-related caches and temp data
#
# Usage:
#   clean-js.sh [--dry-run|-n] [--verbose|-v] [--help|-h]

DRY_RUN=false
VERBOSE=false

for arg in "$@"; do
  case "$arg" in
    -n|--dry-run) DRY_RUN=true ;;
    -v|--verbose) VERBOSE=true ;;
    -h|--help)
      cat <<'EOF'
Usage: clean-js.sh [options]

Options:
  -n, --dry-run    Show what would be removed without deleting anything
  -v, --verbose    Print extra debug information
  -h, --help       Show this help

Removes caches and histories related to JS tooling within $HOME and temp dirs.
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 2
      ;;
  esac
done

if [[ -z "${HOME:-}" || ! -d "$HOME" || "$HOME" == "/" ]]; then
  echo "❌ Refusing to run: invalid HOME='${HOME:-}'." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=clean-utils.sh
source "${SCRIPT_DIR}/clean-utils.sh"

cleaned_count=0
skipped_count=0
failed_count=0

trap 'rc=$?; if (( rc != 0 )); then echo "💥 Aborted with exit $rc. See messages above for the failing step."; fi' EXIT

log "🧹 Cleaning JavaScript/Node caches..."
if [[ "$DRY_RUN" == true ]]; then
  log "🔒 DRY-RUN MODE: no files will be deleted."
fi

# npm
remove_path "$HOME/.npm/_logs" "npm log files"
remove_path "$HOME/.npm/_cacache" "npm cache"

# Node REPL history
remove_path "$HOME/.node_repl_history" "Node.js REPL history"

# pnpm store
remove_path "$HOME/.pnpm" "pnpm store/cache"

# Bun cache and globals
remove_path "$HOME/.bun/install/cache" "Bun cache"
remove_path "$HOME/.bun/install/global" "Bun global installs"

# fnm Node versions and multishell state
remove_path "$HOME/Library/Application Support/fnm/node-versions" "fnm Node.js versions"
remove_path "$HOME/.local/state/fnm_multishells" "fnm multishells state"

log "✅ JS cleanup complete!"
log "📊 Summary: removed=$cleaned_count, skipped=$skipped_count, failed=$failed_count"

if (( failed_count > 0 )); then
  exit 1
fi

