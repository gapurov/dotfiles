#!/usr/bin/env bash

# --------------------------------------------------------------------------------
# worktree-branch.sh — create/reuse a git worktree and copy local config files
# See usage: run with -h or --help
# --------------------------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

################################################################################
# Helper functions                                                               #
################################################################################

usage() {
  cat <<'EOF'
worktree-branch.sh
--------------------------------------------------------------------------------
Create (or reuse) a git worktree for a given branch and copy local configuration
files into that worktree so it is immediately usable.

USAGE
  worktree-branch.sh [options] [branch_name] [directory]

OPTIONS
  -f, --force          Overwrite existing directory / worktree if it already
                       exists at the target path.
  -n, --dry-run        Print the commands that would be run without executing
                       them. Good for sanity-checking.
  -b, --base <ref>     Base ref used ONLY when creating a new branch. If the
                       target branch exists locally or on the remote, this is
                       ignored. Defaults to current HEAD when omitted.
  -h, --help           Show this help and exit.

ARGUMENTS
  branch_name          Name of the branch to create/use for the worktree.
                       If omitted, uses current-branch-name-<commit-hash>.
  directory            Directory where the worktree will be created.
                       Defaults to ../ (parent directory).

EXAMPLES
  worktree-branch.sh                        # use branch-name-hash format
  worktree-branch.sh feature/login          # create ../feature/login worktree
  worktree-branch.sh -b origin/main bug/fix # base branch off origin/main
  worktree-branch.sh -n docs/update         # dry-run preview
--------------------------------------------------------------------------------
EOF
}


run() {
  if ${dry_run}; then
    printf '[dry-run]' >&2
    for arg in "$@"; do printf ' %q' "$arg" >&2; done
    printf '\n' >&2
  else
    "$@"
  fi
}


copy_cmd() {
  local src="$1" dest="$2"
  if ${dry_run}; then
    printf '[dry-run] mkdir -p "%s" && cp -R "%s" "%s/%s"\n' "${dest}/$(dirname "$src")" "$src" "$dest" "$src"
  else
    mkdir -p "$dest/$(dirname "$src")"
    cp -R "$src" "$dest/$src"
  fi
}

# Exit with an error message
die() {
  printf '%s\n' "$*" >&2
  exit 1
}



################################################################################
# Option parsing                                                                #
################################################################################

force=false
dry_run=false
base_ref=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--force)
      force=true
      shift;;
    -n|--dry-run)
      dry_run=true
      shift;;
    -b|--base)
      [[ $# -lt 2 ]] && { echo "Error: --base requires an argument" >&2; exit 1; }
      base_ref="$2"
      shift 2;;
    -h|--help)
      usage; exit 0;;
    --)
      shift; break;;
    -*)
      echo "Unknown option: $1" >&2
      usage; exit 1;;
    *)
      break;;
  esac
done

# Ensure we're inside a git repository early
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  die "Error: not inside a git repository"
fi

# If no branch name provided, use current git branch name + commit hash
if [[ $# -lt 1 ]]; then
  # Determine current branch (fall back to folder name when detached HEAD)
  current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
  if [[ "${current_branch}" == "HEAD" || -z "${current_branch}" ]]; then
    current_branch="$(basename "$(pwd)")"
  fi

  # Get short commit hash
  commit_hash="$(git rev-parse --short HEAD)"
  branch_name="${current_branch}-${commit_hash}"
  echo "📝 No branch name provided, using: ${branch_name}"
else
  branch_name="$1"; shift
fi

# Determine target directory (defaults to ../)
target_dir="${1:-../}"

# Ensure target dir ends with a / for predictable concatenation
[[ "${target_dir}" != */ ]] && target_dir="${target_dir}/"

# Build target path and normalize to absolute (without requiring dirs to exist)
worktree_path_raw="${target_dir}${branch_name}"
if [[ "${worktree_path_raw}" == /* ]]; then
  worktree_path="${worktree_path_raw%/}"
else
  worktree_path="$(pwd)/${worktree_path_raw%/}"
fi

echo "📂 Target worktree path: ${worktree_path}"

################################################################################
# Pre-flight checks                                                             #
################################################################################

for bin in git; do
  command -v "$bin" >/dev/null 2>&1 || {
    echo "Error: '$bin' is required but not installed or not in PATH" >&2
    exit 1
  }
done

# Clean up any stale worktree references first
run git worktree prune

# If directory already exists
if [[ -e "${worktree_path}" ]]; then
  if ${force}; then
    echo "⚠️  Removing existing path ${worktree_path} (force)"
    run rm -rf "${worktree_path}"
  else
    die "Error: path '${worktree_path}' already exists. Use --force to overwrite."
  fi
fi

# If worktree already registered (but maybe path was deleted)
if git worktree list --porcelain | grep -F -x -q "worktree ${worktree_path}"; then
  if ${force}; then
    echo "⚠️  Removing existing worktree registration (force)"
    run git worktree remove --force "${worktree_path}"
  else
    die "Error: a git worktree is already registered at '${worktree_path}'. Use --force to remove."
  fi
fi

################################################################################
# Create the worktree                                                           #
################################################################################

echo "🌱 Creating worktree for branch '${branch_name}'"

if git show-ref --verify --quiet "refs/heads/${branch_name}"; then
  if [[ -n "${base_ref}" ]]; then
    echo "⚠️  --base=${base_ref} specified but branch '${branch_name}' exists locally; --base will be ignored."
  fi
  echo "   ➤ Using existing local branch"
  run git worktree add "${worktree_path}" "${branch_name}"
elif git show-ref --verify --quiet "refs/remotes/origin/${branch_name}"; then
  if [[ -n "${base_ref}" ]]; then
    echo "⚠️  --base=${base_ref} specified but branch 'origin/${branch_name}' exists; --base will be ignored."
  fi
  echo "   ➤ Creating local tracking branch from origin/${branch_name}"
  run git worktree add "${worktree_path}" -b "${branch_name}" "origin/${branch_name}"
else
  echo "   ➤ Creating new branch from ${base_ref:-HEAD}"
  if [[ -n "${base_ref}" ]]; then
    run git worktree add "${worktree_path}" -b "${branch_name}" "${base_ref}"
  else
    run git worktree add "${worktree_path}" -b "${branch_name}"
  fi
fi

echo "✅ Worktree created at: ${worktree_path}"

################################################################################
# Copy configuration files                                                      #
################################################################################

echo "📄 Copying configuration files…"

copy_files_from_configfiles() {
  local config_file="$1" target_dir="$2"
  echo "   ➤ Parsing patterns from $config_file"

  # Copy the .configfiles itself so the worktree knows its own inclusion rules
  copy_cmd "$config_file" "$target_dir"

  # Enable extended globbing and safe patterns
  local shopt_extglob_state shopt_nullglob_state shopt_dotglob_state
  shopt_extglob_state="$(shopt -p extglob || true)"
  shopt_nullglob_state="$(shopt -p nullglob || true)"
  shopt_dotglob_state="$(shopt -p dotglob || true)"
  shopt -s extglob nullglob dotglob

  # Array to collect exclusion (negation) patterns beginning with '!'
  local -a exclude_patterns=()

  # First pass: read patterns and copy inclusions immediately; track exclusions
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip blanks and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    # Trim leading/trailing whitespace (pure bash)
    line="${line##+([[:space:]])}"
    line="${line%%+([[:space:]])}"

    # Negation pattern? collect then continue
    if [[ $line == '!'* ]]; then
      exclude_patterns+=("${line:1}")
      continue
    fi

    # Copy matching paths for this inclusion pattern
    if [[ $line == */* ]]; then
      for path in $line; do
        if [[ -e $path ]]; then
        copy_cmd "$path" "$target_dir"
      fi
      done
    else
      for path in ./$line; do
        if [[ -f $path ]]; then
        copy_cmd "$path" "$target_dir"
      fi
      done
    fi
  done < "$config_file"

  # Second pass: remove any files/directories that match exclusion patterns
  if (( ${#exclude_patterns[@]} )); then
    for pattern in "${exclude_patterns[@]}"; do
      if [[ $pattern == */* ]]; then
        for path in "$target_dir"/$pattern; do
          if [[ -e $path ]]; then
          run rm -rf "$path"
        fi
        done
      else
        for path in "$target_dir"/$pattern; do
          if [[ -e $path ]]; then
          run rm -f "$path"
        fi
        done
      fi
    done
  fi
  # Restore original shopt states
  eval "${shopt_extglob_state}"
  eval "${shopt_nullglob_state}"
  eval "${shopt_dotglob_state}"
}

copy_default_files() {
  local target_dir="$1"
  echo "   ➤ Using default selection (.env*, CLAUDE.md, .cursor/)"
  for env_file in .env*; do
    if [[ -f "$env_file" ]]; then
    copy_cmd "$env_file" "$target_dir"
  fi
  done
  if [[ -f CLAUDE.md ]]; then
    copy_cmd CLAUDE.md "$target_dir"
  fi
  if [[ -d .cursor ]]; then
    copy_cmd .cursor "$target_dir"
  fi
}

if [[ -f .configfiles ]]; then
  copy_files_from_configfiles .configfiles "$worktree_path"
else
  copy_default_files "$worktree_path"
fi

echo "🎉 Done!"
echo "   cd \"${worktree_path}\""
echo "   # To remove later:"
echo "   git worktree remove \"${worktree_path}\""
