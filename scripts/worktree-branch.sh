#!/usr/bin/env bash

# --------------------------------------------------------------------------------
# worktree-branch.sh
# --------------------------------------------------------------------------------
# Create (or reuse) a git worktree for a given branch and copy local configuration
# files into that worktree so it is immediately usable.
#
# USAGE
#   worktree-branch.sh [options] [branch_name] [directory]
#
# OPTIONS
#   -f, --force          Overwrite existing directory / worktree if it already
#                        exists at the target path.
#   -n, --dry-run        Print the commands that would be run without executing
#                        them. Good for sanity-checking.
#   -b, --base <ref>     When creating a _new_ branch, use <ref> as the base
#                        instead of the current HEAD (e.g. origin/main).
#   -h, --help           Show this help and exit.
#
# ARGUMENTS
#   branch_name          Name of the branch to create/use for the worktree.
#                        If omitted, uses current-branch-name-<commit-hash>.
#   directory            Directory where the worktree will be created.
#                        Defaults to ../ (parent directory).
#
# EXAMPLES
#   worktree-branch.sh                        # use branch-name-hash format
#   worktree-branch.sh feature/login          # create ../feature/login worktree
#   worktree-branch.sh -b origin/main bug/fix # base branch off origin/main
#   worktree-branch.sh -n docs/update         # dry-run preview
# --------------------------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

################################################################################
# Helper functions                                                               #
################################################################################

usage() {
  sed -n '2,45p' "$0" | sed -e 's/^# *//'
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
    printf '[dry-run] cp -R "%s" "%s/"\n' "$src" "$dest"
  else
    cp -R "$src" "$dest/"
  fi
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

worktree_path="${target_dir}${branch_name}"

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
    echo "Error: path '${worktree_path}' already exists. Use --force to overwrite." >&2
    exit 1
  fi
fi

# If worktree already registered (but maybe path was deleted)
if git worktree list --porcelain | grep -q "^worktree ${worktree_path}$"; then
  if ${force}; then
    echo "⚠️  Removing existing worktree registration (force)"
    run git worktree remove --force "${worktree_path}"
  else
    echo "Error: a git worktree is already registered at '${worktree_path}'. Use --force to remove." >&2
    exit 1
  fi
fi

################################################################################
# Create the worktree                                                           #
################################################################################

echo "🌱 Creating worktree for branch '${branch_name}'"

if git show-ref --verify --quiet "refs/heads/${branch_name}"; then
  echo "   ➤ Using existing local branch"
  run git worktree add "${worktree_path}" "${branch_name}"
elif git show-ref --verify --quiet "refs/remotes/origin/${branch_name}"; then
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
        [[ -e $path ]] && copy_cmd "$path" "$target_dir"
      done
    else
      for path in ./$line; do
        [[ -f $path ]] && copy_cmd "$path" "$target_dir"
      done
    fi
  done < "$config_file"

  # Second pass: remove any files/directories that match exclusion patterns
  if (( ${#exclude_patterns[@]} )); then
    for pattern in "${exclude_patterns[@]}"; do
      if [[ $pattern == */* ]]; then
        for path in "$target_dir"/$pattern; do
          [[ -e $path ]] && run rm -rf "$path"
        done
      else
        for path in "$target_dir"/$pattern; do
          [[ -e $path ]] && run rm -f "$path"
        done
      fi
    done
  fi
}

copy_default_files() {
  local target_dir="$1"
  echo "   ➤ Using default selection (.env*, CLAUDE.md)"
  for env_file in .env*; do
    [[ -f "$env_file" ]] && copy_cmd "$env_file" "$target_dir"
  done
  [[ -f CLAUDE.md ]] && copy_cmd CLAUDE.md "$target_dir"
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
