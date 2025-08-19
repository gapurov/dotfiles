#!/usr/bin/env bash
# gwq-addx — gwq add with post-create file copy
# Version: 1.0.0
#
# SUMMARY
#   Wrapper around `gwq add` that creates worktrees and then copies files
#   using the standalone copy-configs.sh utility. Provides the familiar
#   gwq-addx interface while leveraging the independent copy-configs tool.
#
# REQUIREMENTS
#   - bash 4.0+ (required for associative arrays)
#   - git, gwq, jq (for detecting new worktrees)
#   - copy-configs.sh (standalone copy utility)
#
# USAGE
#   gwq-addx [OPTIONS] [--] [gwq add args...]
#
# AUTHOR
#   Enhanced with Claude Code assistance for performance and reliability

set -euo pipefail

# ---------- constants ----------
readonly SCRIPT_VERSION="1.0.0"
readonly REQUIRED_DEPS=(git gwq jq)
readonly COPY_CONFIGS_SCRIPT="$(dirname "$0")/copy-configs.sh"

# ---------- global variables ----------
declare -g use_color=1 is_tty=0 verbose_mode=0 debug_mode=0 dry_run_mode=0
declare -ga GWQ_ARGS=()
declare -ga COPY_ARGS=()

# ---------- initialization ----------
[[ -t 1 ]] && is_tty=1

# ---------- logging ----------
log_i() {
    if [[ $use_color -eq 1 && $is_tty -eq 1 ]]; then
        printf '\033[36m>>\033[0m %s\n' "$*"
    else
        printf '>> %s\n' "$*"
    fi
}

log_s() {
    if [[ $use_color -eq 1 && $is_tty -eq 1 ]]; then
        printf '\033[32m✓\033[0m %s\n' "$*"
    else
        printf '✓ %s\n' "$*"
    fi
}

log_w() {
    if [[ $use_color -eq 1 && $is_tty -eq 1 ]]; then
        printf '\033[90m--\033[0m %s\n' "$*"
    else
        printf '%s %s\n' '--' "$*"
    fi
}

log_e() {
    if [[ $use_color -eq 1 && $is_tty -eq 1 ]]; then
        printf '\033[31m!!\033[0m %s\n' "$*" >&2
    else
        printf '!! %s\n' "$*" >&2
    fi
}

log_v() {
    [[ $verbose_mode -eq 1 ]] || return 0
    if [[ $use_color -eq 1 && $is_tty -eq 1 ]]; then
        printf '\033[35m**\033[0m %s\n' "$*"
    else
        printf '** %s\n' "$*"
    fi
}

log_d() {
    [[ $debug_mode -eq 1 ]] || return 0
    if [[ $use_color -eq 1 && $is_tty -eq 1 ]]; then
        printf '\033[33mDD\033[0m %s\n' "$*" >&2
    else
        printf 'DD %s\n' "$*" >&2
    fi
}

# ---------- dependency management ----------
check_dependencies() {
    local missing=()
    local dep

    for dep in "${REQUIRED_DEPS[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_e "Missing required commands: ${missing[*]}"
        exit 1
    fi

    # Check for copy-configs.sh
    if [[ ! -x "$COPY_CONFIGS_SCRIPT" ]]; then
        log_e "copy-configs.sh not found or not executable: $COPY_CONFIGS_SCRIPT"
        log_e "Please ensure copy-configs.sh is in the same directory as this script"
        exit 1
    fi

    log_d "All dependencies verified: ${REQUIRED_DEPS[*]}, copy-configs.sh"
}

check_dependencies

# ---------- help ----------
print_help() {
    cat <<'EOF'
Usage: gwq-addx [OPTIONS] [--] [gwq add args...]

Copy-related OPTIONS (passed to copy-configs.sh):
  --config, -c FILE     Path to rules file (overrides default search)
  --conflict, -C MODE   skip|overwrite|backup   (default: skip)
  --no-color            Disable ANSI colors in output
  --verbose, -v         Enable verbose output
  --debug               Enable debug output
  --dry-run, -n         Show what would be done without executing
  --help, -h            Show help

All other arguments are passed to 'gwq add'.

EXAMPLES:
  # Create worktree with new branch and copy files
  gwq-addx -b feature/auth

  # Create from existing branch
  gwq-addx main

  # With copy configuration
  gwq-addx --config ./custom.copyconfigs -b feature/api

  # Dry run to see what would be copied
  gwq-addx --dry-run -b feature/test

NOTES:
  - Uses copy-configs.sh for file copying (must be in same directory)
  - Default copies: .env*, CLAUDE.md, .cursor/, .vscode/settings.json
  - Config file: .copyconfigs (repo) or ~/.config/copy-configs/config (global)
  - Legacy config files are still supported
EOF
}

# ---------- argument parsing ----------
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "${1:-}" in
            -h|--help)
                print_help; exit 0 ;;
            # Copy-related arguments
            -c|--config|--conflict|-C|--copy-on-conflict)
                COPY_ARGS+=("$1")
                if [[ $# -ge 2 ]]; then
                    COPY_ARGS+=("$2")
                    shift 2
                else
                    log_e "Missing argument for $1"
                    exit 1
                fi
                continue ;;
            --no-color)
                use_color=0
                COPY_ARGS+=("$1")
                shift; continue ;;
            -v|--verbose)
                verbose_mode=1
                COPY_ARGS+=("$1")
                shift; continue ;;
            --debug)
                debug_mode=1; verbose_mode=1
                COPY_ARGS+=("$1")
                shift; continue ;;
            -n|--dry-run)
                dry_run_mode=1; verbose_mode=1
                COPY_ARGS+=("$1")
                shift; continue ;;
            --)
                shift
                while [[ $# -gt 0 ]]; do
                    GWQ_ARGS+=("$1"); shift
                done
                break ;;
            *)
                # All other arguments go to gwq add
                GWQ_ARGS+=("$1"); shift ;;
        esac
    done
}

parse_arguments "$@"

log_d "Parsed arguments: verbose=$verbose_mode debug=$debug_mode dry_run=$dry_run_mode"
log_d "GWQ args: ${GWQ_ARGS[*]:-<none>}"
log_d "Copy args: ${COPY_ARGS[*]:-<none>}"

# Validate gwq arguments
if [[ ${#GWQ_ARGS[@]} -eq 0 ]]; then
    log_e "No arguments provided to gwq add"
    print_help
    exit 1
fi

# ---------- worktree detection ----------
get_worktree_paths() {
    gwq list --json 2>/dev/null | jq -r '.[].path' 2>/dev/null | LC_ALL=C sort -u
}

get_new_worktrees() {
    local -A before_set=()
    local -a before_list=() after_list=() new_list=()

    # Snapshot before
    mapfile -t before_list < <(get_worktree_paths)

    local path
    for path in "${before_list[@]}"; do
        before_set["$path"]=1
    done

    # Run gwq add
    log_i "Creating worktree(s): gwq add ${GWQ_ARGS[*]}" >&2
    if [[ $dry_run_mode -eq 1 ]]; then
        log_w "DRY RUN: Would run: gwq add ${GWQ_ARGS[*]}" >&2
        # Simulate new worktrees for dry run
        printf '/tmp/dry-run-worktree-1\n'
        return 0
    else
        local gwq_output
        gwq_output="$(gwq add "${GWQ_ARGS[@]}" 2>&1)" || {
            log_e "gwq add failed: $gwq_output"
            exit 1
        }
        log_v "gwq add output: $gwq_output"
    fi

    # Snapshot after and find new paths
    mapfile -t after_list < <(get_worktree_paths)

    for path in "${after_list[@]}"; do
        if [[ -z ${before_set[$path]:-} ]]; then
            new_list+=("$path")
        fi
    done

    printf '%s\n' "${new_list[@]}"
}

# ---------- main execution ----------
new_paths="$(get_new_worktrees)"

log_d "New worktree paths: '$new_paths'"

if [[ -z $new_paths ]]; then
    log_w "No new worktree paths detected. Nothing to copy."
    exit 0
fi

# Count actual number of worktree paths
path_count=$(echo "$new_paths" | wc -l)
[[ -z $new_paths ]] && path_count=0

log_i "Copying files into $path_count new worktree(s)"

# Use copy-configs.sh to copy files
printf '%s\n' "$new_paths" | "$COPY_CONFIGS_SCRIPT" "${COPY_ARGS[@]}"

log_s "Done."
