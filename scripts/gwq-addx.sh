#!/usr/bin/env bash
# gwq-addx — gwq add with post-create file copy (no env vars)
# Version: 1.3.4
#
# SUMMARY
#   Wrapper around `gwq add` that copies an explicit set of local files/dirs
#   (e.g., .env*, .cursor/, CLAUDE.md) from the source repo into newly
#   created worktree(s), preserving relative paths. Missing items are skipped.
#
# REQUIREMENTS
#   - bash 3.2+ (macOS default ok)
#   - git, gwq, jq, rsync
#
# USAGE
#   gwq-addx [--config FILE|-c FILE]
#            [--conflict MODE|-C MODE]   # skip|overwrite|backup  (default: skip)
#            [--no-color]
#            [--] [gwq add args...]

set -euo pipefail

# ---------- logging ----------
use_color=1
is_tty=0; [ -t 1 ] && is_tty=1
c() { if [ "$use_color" -eq 1 ] && [ "$is_tty" -eq 1 ]; then printf "$1%s\033[0m" "$2"; else printf "%s" "$2"; fi; }
log_i() { printf "%s %s\n" "$(c '\033[36m' '>>')" "$*"; }
log_s() { printf "%s %s\n" "$(c '\033[32m' '✓')" "$*"; }
log_w() { printf "%s %s\n" "$(c '\033[90m' '--')" "$*"; }
log_e() { printf "%s %s\n" "$(c '\033[31m' '!!')" "$*" >&2; }

# ---------- deps ----------
need() { command -v "$1" >/dev/null 2>&1 || { log_e "Missing required command: $1"; exit 1; }; }
need git; need gwq; need jq; need rsync

# ---------- help ----------
print_help() {
  cat <<'EOF'
Usage: gwq-addx [--config FILE|-c FILE] [--conflict MODE|-C MODE] [--no-color] [--] [gwq add args...]

Params:
  --config, -c FILE     Path to rules file (overrides default search)
  --conflict, -C MODE   skip|overwrite|backup   (default: skip)
  --no-color            Disable ANSI colors in output
  --help, -h            Show help
EOF
}

# ---------- parse args ----------
cfg_override=""
conflict_mode="skip"
GWQ_ARGS=()

while [ $# -gt 0 ]; do
  case "${1:-}" in
    -h|--help) print_help; exit 0 ;;
    -c|--config) [ $# -ge 2 ] || { log_e "Missing argument for $1"; exit 1; }
      cfg_override="$2"; shift 2; continue ;;
    -C|--conflict|--copy-on-conflict) [ $# -ge 2 ] || { log_e "Missing argument for $1"; exit 1; }
      case "$2" in skip|overwrite|backup) conflict_mode="$2" ;;
        *) log_e "Invalid --conflict '$2' (use: skip|overwrite|backup)"; exit 1 ;;
      esac
      shift 2; continue ;;
    --no-color) use_color=0; shift; continue ;;
    --) shift; while [ $# -gt 0 ]; do GWQ_ARGS+=("$1"); shift; done; break ;;
    *) GWQ_ARGS+=("$1"); shift ;;
  esac
done

# ---------- repo root ----------
repo_root=""
if ! repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  log_e "Please run from inside a git repository."
  exit 1
fi

# ---------- choose config ----------
cfg=""
cfg_repo="$repo_root/.gwkcopy"
cfg_global=~/.config/gwq/gwkcopy

if [ -n "$cfg_override" ]; then
  cfg="$cfg_override"; [ -f "$cfg" ] || { log_e "Config file not found: $cfg"; exit 1; }
else
  if   [ -f "$cfg_repo"   ]; then cfg="$cfg_repo"
  elif [ -f "$cfg_global" ]; then cfg="$cfg_global"
  else cfg=""  # allowed: will only run gwq add
  fi
fi

# ---------- snapshot before ----------
before_list="$(gwq list --json | jq -r '.[].path' | LC_ALL=C sort -u)" \
  || { log_e "Failed to list worktrees (before)."; exit 1; }

# ---------- run gwq add ----------
log_i "Creating worktree(s): gwq add ${GWQ_ARGS[*]:-}"
gwq add "${GWQ_ARGS[@]}" || { log_e "`gwq add` failed."; exit 1; }

# ---------- snapshot after & diff ----------
after_list="$(gwq list --json | jq -r '.[].path' | LC_ALL=C sort -u)" \
  || { log_e "Failed to list worktrees (after)."; exit 1; }

new_paths="$(comm -13 <(printf '%s\n' "$before_list") <(printf '%s\n' "$after_list"))"

if [ -z "$new_paths" ]; then
  log_w "No new worktree paths detected. Nothing to copy."
  exit 0
fi


# ---------- rule parsing & helpers ----------
PR_SRC=""; PR_DEST=""
parse_rule() {
  local raw="$1"
  raw="${raw%%$'\r'}"                                      # strip CR
  raw="${raw%%#*}"                                         # strip comments
  raw="$(printf '%s' "$raw" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"  # trim
  [ -z "$raw" ] && return 1

  if [ "${raw#*:}" != "$raw" ]; then
    PR_SRC="${raw%%:*}"
    PR_DEST="${raw#*:}"
  else
    PR_SRC="$raw"
    PR_DEST="$raw"
  fi
  return 0
}

ensure_parent() {
  local d="$1"
  if [ -d "$d" ]; then
    mkdir -p "$d" 2>/dev/null || true
  else
    mkdir -p "$(dirname "$d")" 2>/dev/null || true
  fi
}

copy_one() {
  # $1 src (relative to repo_root), $2 dest_abs, $3 want_dir(0/1), $4 wtree
  local src="$1" dest="$2" want_dir="$3" wtree="$4"
  if [ "$want_dir" = "1" ]; then case "$dest" in */) : ;; *) dest="${dest}/" ;; esac; fi

  if [ -e "$dest" ] || [ -L "$dest" ]; then
    case "$conflict_mode" in
      skip)     log_w "keep (exists): ${dest#$wtree/}"; return 0 ;;
      backup)   local bak="${dest}.bak-$(date +%Y%m%d-%H%M%S)"; log_i "backup: ${dest#$wtree/} -> ${bak#$wtree/}"; mv -f "$dest" "$bak" ;;
      overwrite) : ;;
    esac
  fi

  ensure_parent "$dest"
  rsync -a "$src" "$dest"
}

is_glob() {
  case "$1" in *\**|*?*|*[*]*) return 0 ;; *) return 1 ;; esac
}

# ---------- copy engine ----------
copy_into_worktree() {
  local wtree="$1"

  if [ -z "$cfg" ]; then
    log_w "No .gwkcopy found (repo or global). Skipping copy."
    return 0
  fi

  log_i "Using config: $cfg"

  while IFS= read -r line || [ -n "$line" ]; do
    parse_rule "$line" || continue
    local src_pat="$PR_SRC" dest_rel="$PR_DEST"
    local want_dir=0; case "$dest_rel" in */) want_dir=1 ;; esac

    (
      # Anchor to repo root so --relative uses the correct base
      cd "$repo_root" || exit 0
      shopt -s nullglob dotglob

      # Build match list robustly:
      # - if it's a glob: expand; empty result means "no matches"
      # - if it's literal: only include if -e or -L (otherwise skip)
      local matches=()
      if is_glob "$src_pat"; then
        # shellcheck disable=SC2206
        matches=( $src_pat )
      else
        if [ -e "$src_pat" ] || [ -L "$src_pat" ]; then
          matches=( "$src_pat" )
        else
          matches=()
        fi
      fi

      if [ ${#matches[@]} -eq 0 ]; then
        log_w "skip (missing): $src_pat"
        exit 0
      fi

      for rel_src in "${matches[@]}"; do
        # Safety: if something vanished between expansion and copy, skip
        if [ ! -e "$rel_src" ] && [ ! -L "$rel_src" ]; then
          log_w "skip (missing): $rel_src"
          continue
        fi

        if [ "$dest_rel" = "$src_pat" ]; then
          # Preserve relative structure under worktree
          rsync -a --relative "./$rel_src" "$wtree/"
          log_s "copied: $rel_src"
          continue
        fi

        # Explicit mapping
        dest_abs="$wtree/$dest_rel"
        copy_one "$rel_src" "$dest_abs" "$want_dir" "$wtree"
        pretty_to="${dest_abs#$wtree/}"
        log_s "copied: $rel_src -> $pretty_to"
      done
    )
  done < "$cfg"
}

# ---------- process each new worktree ----------
while IFS= read -r wp || [ -n "$wp" ]; do
  [ -z "$wp" ] && continue
  case "$wp" in /*) worktree_path="$wp" ;; *) worktree_path="$(cd "$wp" 2>/dev/null && pwd)" ;; esac
  [ -z "$worktree_path" ] && continue

  log_i "Post-copy into: $worktree_path"
  copy_into_worktree "$worktree_path"
done <<< "$new_paths"

log_s "Done."
