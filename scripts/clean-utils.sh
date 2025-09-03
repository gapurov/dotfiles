#!/usr/bin/env bash
# Shared helpers for cleaning temporary files and caches
# Intended to be sourced by other scripts (e.g., clean-temp.sh, clean-js.sh)

# NOTE: Do not set shell options here; let callers control `set -euo pipefail`.

# Logging helpers (use caller-provided VERBOSE flag if set)
log()   { echo -e "$*"; }
debug() {
  if [[ "${VERBOSE:-false}" == true ]]; then
    echo "🔎 $*"
  fi
}

# Allowable base prefixes for removal (HOME, TMPDIR, /tmp, /private/tmp)
is_removal_allowed() {
  local p="$1"
  local tmp_prefixes=()
  [[ -n "${TMPDIR:-}" ]] && tmp_prefixes+=("$TMPDIR")
  tmp_prefixes+=("/tmp" "/private/tmp")

  if [[ -n "${HOME:-}" && -d "$HOME" && "$p" == "$HOME"* ]]; then
    return 0
  fi
  for t in "${tmp_prefixes[@]}"; do
    [[ "$p" == "$t"* ]] && return 0
  done
  return 1
}

# Remove a path safely with consistent reporting
remove_path() {
  local path="$1"
  local description="${2:-$1}"

  if [[ ! -e "$path" ]]; then
    debug "Skip (missing): $path"
    ((skipped_count=${skipped_count:-0}+1))
    return 0
  fi
  if ! is_removal_allowed "$path"; then
    log "⚠️  Skipping unsafe path (outside HOME/TMP): $path"
    ((skipped_count=${skipped_count:-0}+1))
    return 0
  fi
  if [[ "${DRY_RUN:-false}" == true ]]; then
    log "🧪 Would remove $description → $path"
    ((skipped_count=${skipped_count:-0}+1))
    return 0
  fi

  if rm -rf -- "$path" 2>/dev/null; then
    log "🗑️  Removed $description"
    ((cleaned_count=${cleaned_count:-0}+1))
  else
    log "❌ Failed to remove $description → $path"
    ((failed_count=${failed_count:-0}+1))
  fi
}

# Run a guarded find -delete cleanup
run_find_delete() {
  local label="$1"; shift
  local cmd=(find "$@")

  if [[ "${DRY_RUN:-false}" == true ]]; then
    log "🧪 Would run: ${cmd[*]} -delete"
    ((skipped_count=${skipped_count:-0}+1))
    return 0
  fi

  if "${cmd[@]}" -delete 2>/dev/null; then
    log "🧹 Cleaned: $label"
    ((cleaned_count=${cleaned_count:-0}+1))
  else
    log "❌ Failed: $label (find -delete)"
    ((failed_count=${failed_count:-0}+1))
  fi
}

