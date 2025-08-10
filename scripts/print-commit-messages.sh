#!/usr/bin/env bash

# --------------------------------------------------------------------------------
# print-commit-messages.sh — print commit messages for the current branch
# - Prints each commit subject on its own line
# - By default, shows commits unique to the current branch
#   Preferred comparison: upstream → local main/master → origin default/main/master;
#   otherwise exclude all other refs (no network access required by default)
# - Copies the output to the clipboard on macOS/Linux, and Windows (WSL/Git Bash)
#   if a compatible clipboard utility is available
# --------------------------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

usage() {
  cat <<'EOF'
print-commit-messages.sh
--------------------------------------------------------------------------------
Print commit messages (one per line) for the current branch, and copy to the
clipboard if supported.

USAGE
  print-commit-messages.sh [options]

OPTIONS
  -b, --base <ref>  Use this base ref to compute the merge-base (e.g. origin/main).
  -a, --all         Show full history reachable from HEAD (ignore base detection).
  -m, --include-merges  Include merge commits (excluded by default).
  -h, --help        Show this help and exit.

NOTES
  Default behavior: only commits unique to the current branch.
  Base detection order when --base is omitted:
    1) upstream tracking branch of the current branch (if configured)
    2) local main, then local master (also tries staging/develop/dev if present)
    3) origin/HEAD (remote default), origin/main, origin/master (and staging/develop/dev if present)
    4) if none found, exclude all other refs (local branches, remotes, tags)
  Clipboard support order (best-effort):
     macOS: pbcopy
     Linux: wl-copy, xclip, xsel
     Windows (WSL/Git Bash): clip.exe (interop), clip, powershell.exe Set-Clipboard
--------------------------------------------------------------------------------
EOF
}

die() { printf '%s\n' "$*" >&2; exit 1; }

# ------------------------------- helpers ------------------------------------
# Return 0 if the given fully-qualified ref exists, 1 otherwise
has_ref() {
  local refname="$1"
  git show-ref --verify --quiet "$refname"
}

# Echo the upstream tracking ref (e.g. origin/main) if configured, else empty
get_upstream_ref() {
  git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true
}

# Detect a reasonable base ref following documented priority.
# Echoes the base ref or nothing if none detected.
detect_base_ref() {
  # 1) Upstream tracking branch (if configured)
  local upstream_ref
  upstream_ref="$(get_upstream_ref)"
  if [[ -n "$upstream_ref" ]]; then
    printf '%s' "$upstream_ref"
    return 0
  fi

  # 2) Local branches (main → master → staging → develop → dev)
  local local_candidates=(
    "refs/heads/main"
    "refs/heads/master"
    "refs/heads/staging"
    "refs/heads/develop"
    "refs/heads/dev"
  )
  for ref in "${local_candidates[@]}"; do
    if has_ref "$ref"; then
      printf '%s' "${ref#refs/heads/}"
      return 0
    fi
  done

  # 3) Origin default (origin/HEAD) then common origin branches
  local origin_head_ref
  origin_head_ref="$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [[ -n "$origin_head_ref" ]]; then
    printf '%s' "$origin_head_ref"
    return 0
  fi

  local origin_candidates=(
    "refs/remotes/origin/main"
    "refs/remotes/origin/master"
    "refs/remotes/origin/staging"
    "refs/remotes/origin/develop"
    "refs/remotes/origin/dev"
  )
  for ref in "${origin_candidates[@]}"; do
    if has_ref "$ref"; then
      printf '%s' "origin/${ref#refs/remotes/origin/}"
      return 0
    fi
  done

  # 4) None detected
  return 1
}

include_merges=false
explicit_base=""
show_all=false
do_fetch=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -b|--base)
      [[ $# -lt 2 ]] && die "Error: --base requires a ref argument"
      explicit_base="$2"; shift 2;;
    -a|--all)
      show_all=true; shift;;
    -m|--include-merges)
      include_merges=true; shift;;
    --fetch)
      do_fetch=true; shift;;
    -h|--help)
      usage; exit 0;;
    --)
      shift; break;;
    -*)
      die "Unknown option: $1";;
    *)
      break;;
  esac
done

# Ensure we are inside a git repository
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Error: not inside a git repository"

# Optionally fetch to ensure remote refs are up to date (helps branch detection)
if $do_fetch; then
  git fetch --quiet --all --prune 2>/dev/null || true
fi

# Determine the comparison range or revision set
rev_args=()
extra_log_opts=()
base_hint=""

if $show_all; then
  rev_args+=("HEAD")
else
  if [[ -n "$explicit_base" ]]; then
    base_hint="$explicit_base"
  else
    base_hint="$(detect_base_ref || true)"
  fi

  if [[ -n "$base_hint" ]]; then
    # If the detected base points to the same commit as HEAD (e.g., on main/staging itself),
    # show the full history of the current branch instead of an empty set.
    base_oid="$(git rev-parse -q --verify "$base_hint" 2>/dev/null || true)"
    head_oid="$(git rev-parse -q --verify HEAD)"
    if [[ -n "$base_oid" && "$base_oid" == "$head_oid" ]]; then
      rev_args+=("HEAD")
    else
      # Show commits that are in HEAD but not in base (exclude base commits even if merged)
      # Use symmetric difference with right-only and cherry-pick equivalence
      rev_args+=("${base_hint}...HEAD")
      extra_log_opts+=("--right-only" "--cherry-pick")
    fi
  else
    # No detectable base: show only commits unique to this branch vs all other refs
    current_branch_name="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)"
    other_refs=()
    while IFS= read -r refname; do
      if [[ "$current_branch_name" != "HEAD" && -n "$current_branch_name" ]]; then
        if ! printf '%s\n' "$refname" | grep -q "^refs/heads/${current_branch_name}$"; then
          other_refs+=("$refname")
        fi
      else
        other_refs+=("$refname")
      fi
    done < <(git for-each-ref --format='%(refname)' refs/heads refs/remotes refs/tags)
    rev_args=("HEAD" "--not")
    if (( ${#other_refs[@]} > 0 )); then
      rev_args+=("${other_refs[@]}")
    else
      rev_args+=("--branches" "--remotes" "--tags")
    fi
  fi
fi

# Build the git log options
log_opts=("--format=%s")
if (( ${#extra_log_opts[@]} > 0 )); then
  log_opts+=("${extra_log_opts[@]}")
fi
if ! $include_merges; then
  log_opts+=("--no-merges")
fi

# Collect output
commit_lines="$(git log "${log_opts[@]}" "${rev_args[@]}" || true)"

# Always print to stdout
printf '%s\n' "$commit_lines"

# Attempt to copy to clipboard (best-effort)
copy_to_clipboard() {
  local data="$1"
  if command -v pbcopy >/dev/null 2>&1; then
    printf '%s\n' "$data" | pbcopy
    echo "📋 Copied to macOS clipboard" >&2
    return 0
  fi
  if command -v wl-copy >/dev/null 2>&1; then
    printf '%s\n' "$data" | wl-copy
    echo "📋 Copied to Wayland clipboard" >&2
    return 0
  fi
  if command -v xclip >/dev/null 2>&1; then
    printf '%s' "$data" | xclip -selection clipboard
    echo "📋 Copied to X11 clipboard (xclip)" >&2
    return 0
  fi
  if command -v xsel >/dev/null 2>&1; then
    printf '%s' "$data" | xsel --clipboard --input
    echo "📋 Copied to X11 clipboard (xsel)" >&2
    return 0
  fi
  # Windows via WSL interop (detect WSL explicitly)
  if grep -qi 'microsoft' /proc/version 2>/dev/null || [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
    if command -v clip.exe >/dev/null 2>&1; then
      printf '%s\n' "$data" | clip.exe
      echo "📋 Copied to Windows clipboard (WSL clip.exe)" >&2
      return 0
    fi
    if [[ -x "/mnt/c/Windows/System32/clip.exe" ]]; then
      printf '%s\n' "$data" | "/mnt/c/Windows/System32/clip.exe"
      echo "📋 Copied to Windows clipboard (WSL clip.exe path)" >&2
      return 0
    fi
    if command -v powershell.exe >/dev/null 2>&1; then
      printf '%s\n' "$data" | powershell.exe -NoProfile -Command "[Console]::In.ReadToEnd() | Set-Clipboard" >/dev/null 2>&1 || true
      echo "📋 Copied to Windows clipboard (WSL PowerShell)" >&2
      return 0
    fi
    if [[ -x "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe" ]]; then
      printf '%s\n' "$data" | "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe" -NoProfile -Command "[Console]::In.ReadToEnd() | Set-Clipboard" >/dev/null 2>&1 || true
      echo "📋 Copied to Windows clipboard (WSL WindowsPowerShell)" >&2
      return 0
    fi
    if [[ -x "/mnt/c/Program Files/PowerShell/7/pwsh.exe" ]]; then
      printf '%s\n' "$data" | "/mnt/c/Program Files/PowerShell/7/pwsh.exe" -NoProfile -Command "[Console]::In.ReadToEnd() | Set-Clipboard" >/dev/null 2>&1 || true
      echo "📋 Copied to Windows clipboard (WSL pwsh)" >&2
      return 0
    fi
  fi
  # Windows / WSL / Git Bash
  if command -v clip.exe >/dev/null 2>&1; then
    printf '%s\n' "$data" | clip.exe
    echo "📋 Copied to Windows clipboard (clip.exe)" >&2
    return 0
  fi
  if command -v clip >/dev/null 2>&1; then
    printf '%s\n' "$data" | clip
    echo "📋 Copied to Windows clipboard (clip)" >&2
    return 0
  fi
  if command -v powershell.exe >/dev/null 2>&1; then
    # Preserve Unicode via PowerShell Set-Clipboard reading from STDIN
    printf '%s\n' "$data" | powershell.exe -NoProfile -Command "[Console]::In.ReadToEnd() | Set-Clipboard" >/dev/null 2>&1 || true
    echo "📋 Copied to Windows clipboard (PowerShell)" >&2
    return 0
  fi
  echo "ℹ️  No clipboard utility found; install pbcopy/wl-copy/xclip/xsel or enable Windows clip.exe/PowerShell" >&2
}

copy_to_clipboard "$commit_lines"
