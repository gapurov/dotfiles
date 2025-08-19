#!/usr/bin/env bash
# copy-configs — Universal configuration file copying utility
# Version: 0.0.1
#
# SUMMARY
#   Copies an explicit set of local files/dirs (e.g., .env*, .cursor/, CLAUDE.md)
#   from the source directory into specified target directories, preserving relative paths.
#   Missing items are skipped. Works with any directory structure.
#
# REQUIREMENTS
#   - bash 4.0+ (required for associative arrays and improved features)
#   - git, rsync
#   - timeout (optional, for operation timeouts)
#
# USAGE
#   echo "path/to/target" | copy-configs [OPTIONS]
#   copy-configs [OPTIONS] < target_paths.txt
#   copy-configs [OPTIONS] --target path/to/target
#
# AUTHOR
#   Enhanced with Claude Code assistance for performance and reliability

set -euo pipefail

# ---------- constants ----------
readonly SCRIPT_VERSION="0.0.1"
readonly MAX_CONFIG_SIZE=1048576  # 1MB
readonly REQUIRED_DEPS=(git rsync)

# Default files to copy when no config exists
readonly DEFAULT_COPY_PATTERNS=(
    ".env*"
    "CLAUDE.md"
    ".cursor/"
    ".vscode/settings.json"
)

# ---------- global variables ----------
declare -g use_color=1 is_tty=0 source_root=""
declare -g cfg_override="" conflict_mode="skip"
declare -g verbose_mode=0 debug_mode=0 dry_run_mode=0
declare -g target_override=""
declare -ga TARGET_PATHS=()

# ---------- initialization ----------
# Cache TTY detection for performance
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

log_dry() {
    [[ $dry_run_mode -eq 1 ]] || return 0
    if [[ $use_color -eq 1 && $is_tty -eq 1 ]]; then
        printf '\033[96mDRY\033[0m %s\n' "$*"
    else
        printf 'DRY %s\n' "$*"
    fi
}

# ---------- error handling ----------
declare -g script_exit_code=0
declare -g cleanup_performed=0

# Better cleanup that preserves exit codes
cleanup() {
    local exit_code=$?

    # Avoid double cleanup
    [[ $cleanup_performed -eq 1 ]] && return
    cleanup_performed=1

    # Use stored exit code if available, otherwise use current
    if [[ $script_exit_code -ne 0 ]]; then
        exit_code=$script_exit_code
    fi

    # Only log errors for actual failures (not normal exits)
    if [[ $exit_code -ne 0 ]]; then
        log_e "Script failed with exit code $exit_code"
    fi

    exit $exit_code
}

# Set exit code and exit
die() {
    local code=${1:-1}
    script_exit_code=$code
    exit $code
}

# Error recovery for critical operations
with_error_recovery() {
    local operation="$1"
    shift

    if ! "$@"; then
        log_e "Failed: $operation"
        die 1
    fi
}

# Execute command with timeout
with_timeout() {
    local timeout_sec="$1" operation="$2"
    shift 2

    if command -v timeout >/dev/null 2>&1; then
        if ! timeout "$timeout_sec" "$@"; then
            log_e "Operation timed out after ${timeout_sec}s: $operation"
            die 1
        fi
    else
        # Fallback for systems without timeout command
        if ! "$@"; then
            log_e "Failed: $operation"
            die 1
        fi
    fi
}

# Atomic file operations
atomic_copy() {
    local src="$1" dest="$2"
    local temp_dest="${dest}.tmp.$$"

    # Copy to temporary file first
    if rsync -a "$src" "$temp_dest"; then
        # Atomic move to final destination
        if mv "$temp_dest" "$dest"; then
            return 0
        else
            rm -f "$temp_dest" 2>/dev/null || true
            return 1
        fi
    else
        rm -f "$temp_dest" 2>/dev/null || true
        return 1
    fi
}

trap cleanup EXIT ERR

# ---------- dependency management ----------
# Check that all required dependencies are available
# Globals: REQUIRED_DEPS (readonly array)
# Returns: exits with code 1 if dependencies missing
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
        die 1
    fi

    log_d "All dependencies verified: ${REQUIRED_DEPS[*]}" >&2
}

check_dependencies

# ---------- help ----------
print_help() {
    cat <<'EOF'
Usage: copy-configs [OPTIONS] [--target PATH]
       echo "path/to/target" | copy-configs [OPTIONS]
       copy-configs [OPTIONS] < target_paths.txt

OPTIONS:
  --config, -c FILE     Path to rules file (overrides default search)
  --conflict, -C MODE   skip|overwrite|backup   (default: skip)
  --target, -t PATH     Explicit target path (can be used multiple times)
  --no-color            Disable ANSI colors in output
  --verbose, -v         Enable verbose output
  --debug               Enable debug output
  --dry-run, -n         Show what would be done without executing
  --help, -h            Show help

EXAMPLES:
  # Via pipe
  echo "/path/to/target" | copy-configs
  echo "/path/to/target" | copy-configs --verbose

  # Via file
  copy-configs < target_paths.txt

  # Via command line argument
  copy-configs --target /path/to/target
  copy-configs -t /path/to/dir1 -t /path/to/dir2

  # Default behavior (copies .env*, CLAUDE.md, .cursor/, .vscode/settings.json)
  copy-configs --target /path/to/target  # No config file needed
EOF
}

# ---------- input validation ----------
validate_conflict_mode() {
    local mode="$1"
    case "$mode" in
        skip|overwrite|backup) return 0 ;;
        *) log_e "Invalid --conflict '$mode' (use: skip|overwrite|backup)"; return 1 ;;
    esac
}

# Validate configuration file exists, is readable, and reasonable size
# Args: config_file - path to configuration file
# Globals: MAX_CONFIG_SIZE (readonly)
# Returns: 0 if valid, 1 if invalid
validate_config_file() {
    local config_file="$1"

    if [[ ! -f $config_file ]]; then
        log_e "Config file does not exist: $config_file"
        return 1
    fi

    if [[ ! -r $config_file ]]; then
        log_e "Config file is not readable: $config_file"
        return 1
    fi

    # Prevent processing of extremely large files
    local file_size
    file_size="$(wc -c < "$config_file" 2>/dev/null || echo 0)"
    if [[ $file_size -gt $MAX_CONFIG_SIZE ]]; then
        log_e "Config file too large (>$(( MAX_CONFIG_SIZE / 1024 ))KB): $config_file"
        return 1
    fi

    log_d "Config file validated: $config_file (${file_size} bytes)" >&2
    return 0
}

validate_path_safety() {
    local path="$1"

    # Check for path traversal attempts
    case "$path" in
        */../*|../*|*/..|..)
            log_e "Path traversal detected in: $path"
            return 1 ;;
        /*)
            log_e "Absolute paths not allowed in config: $path"
            return 1 ;;
        ~/*)
            log_e "Home directory paths not allowed in config: $path"
            return 1 ;;
    esac

    # Check for null bytes and dangerous characters (but allow glob patterns)
    local clean_path="${path//[$'\0\n\r']/}"
    if [[ ${#clean_path} -ne ${#path} ]]; then
        log_e "Invalid control characters in path: $path"
        return 1
    fi

    return 0
}

validate_target_paths() {
    if [[ ${#TARGET_PATHS[@]} -eq 0 ]]; then
        log_e "No target paths provided (via pipe, file, or --target)"
        return 1
    fi

    # Check for basic path sanity
    local path
    for path in "${TARGET_PATHS[@]}"; do
        if [[ -z $path ]]; then
            log_e "Empty path detected in target paths"
            return 1
        fi

        # Check for suspicious patterns using safer method
        local path_len="${#path}"
        local clean_path="${path//[$'\0\n\r']/}"
        if [[ ${#clean_path} -ne $path_len ]]; then
            log_e "Invalid control characters in target path: $path"
            return 1
        fi
    done

    return 0
}

# ---------- parse args ----------
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "${1:-}" in
            -h|--help)
                print_help; exit 0 ;;
            -c|--config)
                [[ $# -ge 2 ]] || { log_e "Missing argument for $1"; exit 1; }
                cfg_override="$2"; shift 2; continue ;;
            -C|--conflict|--copy-on-conflict)
                [[ $# -ge 2 ]] || { log_e "Missing argument for $1"; exit 1; }
                validate_conflict_mode "$2" || exit 1
                conflict_mode="$2"
                shift 2; continue ;;
            -t|--target)
                [[ $# -ge 2 ]] || { log_e "Missing argument for $1"; exit 1; }
                TARGET_PATHS+=("$2"); shift 2; continue ;;
            --no-color)
                use_color=0; shift; continue ;;
            -v|--verbose)
                verbose_mode=1; shift; continue ;;
            --debug)
                debug_mode=1; verbose_mode=1; shift; continue ;;
            -n|--dry-run)
                dry_run_mode=1; verbose_mode=1; shift; continue ;;
            *)
                log_e "Unknown argument: $1"
                print_help
                exit 1 ;;
        esac
    done
}

parse_arguments "$@"

log_d "Parsed arguments: verbose=$verbose_mode debug=$debug_mode dry_run=$dry_run_mode"
log_d "Target paths from args: ${TARGET_PATHS[*]:-<none>}"
log_d "Config override: ${cfg_override:-<none>}"
log_d "Conflict mode: $conflict_mode"

# ---------- repo validation ----------
get_source_root() {
    local root
    if ! root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
        log_e "Please run from inside a git repository."
        exit 1
    fi
    log_v "Source root: $root" >&2
    printf '%s' "$root"
}

source_root="$(get_source_root)"

# ---------- config resolution ----------
find_config_file() {
    local cfg_repo="$source_root/.copyconfigs"
    local cfg_global="$HOME/.config/copy-configs/config"
    # config support for gwq
    local cfg_gwq_repo="$source_root/.copyconfigs"
    local cfg_gwq_global="$HOME/.config/gwq/copyconfigs"

    if [[ -n $cfg_override ]]; then
        if validate_config_file "$cfg_override"; then
            printf '%s' "$cfg_override"
        else
            exit 1
        fi
    elif [[ -f $cfg_repo ]] && validate_config_file "$cfg_repo"; then
        printf '%s' "$cfg_repo"
    elif [[ -f $cfg_global ]] && validate_config_file "$cfg_global"; then
        printf '%s' "$cfg_global"
    elif [[ -f $cfg_gwq_repo ]] && validate_config_file "$cfg_gwq_repo"; then
        printf '%s' "$cfg_gwq_repo"
    elif [[ -f $cfg_gwq_global ]] && validate_config_file "$cfg_gwq_global"; then
        printf '%s' "$cfg_gwq_global"
    else
        printf ''
    fi
}

cfg="$(find_config_file)"

# ---------- utility functions ----------
# Remove leading and trailing whitespace from string
trim_string() {
    local str="$1"
    # Remove leading whitespace
    str="${str#"${str%%[![:space:]]*}"}"
    # Remove trailing whitespace
    str="${str%"${str##*[![:space:]]}"}"
    printf '%s' "$str"
}

# ---------- input collection ----------
# Read target paths from stdin if no --target args provided
read_stdin_paths() {
    if [[ ${#TARGET_PATHS[@]} -eq 0 ]] && [[ ! -t 0 ]]; then
        log_v "Reading target paths from stdin"
        while IFS= read -r line || [[ -n $line ]]; do
            line="$(trim_string "$line")"
            [[ -n $line ]] && TARGET_PATHS+=("$line")
        done
    fi
}

read_stdin_paths

# ---------- input validation ----------
validate_target_paths || exit 1

log_i "Processing ${#TARGET_PATHS[@]} target path(s)"
log_d "Target paths: ${TARGET_PATHS[*]}"


# ========== CONFIGURATION PARSING ==========

# Parse a single config rule line into source and destination
# Args: raw - raw line from config file
#       rule_array_ref - name of array variable to store result
# Returns: 0 if valid rule parsed, 1 if invalid/empty
# Side effects: validates path safety, populates result array via nameref
parse_config_rule() {
    local raw="$1" rule_array_ref="$2"
    local -a parsed_rule=()

    # Strip CR and comments
    raw="${raw%%$'\r'}"
    raw="${raw%%#*}"

    # Trim whitespace efficiently
    raw="$(trim_string "$raw")"

    [[ -z $raw ]] && return 1

    if [[ $raw == *:* ]]; then
        parsed_rule=("${raw%%:*}" "${raw#*:}")
    else
        parsed_rule=("$raw" "$raw")
    fi

    # Validate path safety for both source and destination
    if ! validate_path_safety "${parsed_rule[0]}" || ! validate_path_safety "${parsed_rule[1]}"; then
        return 1
    fi

    # Use nameref to return array
    local -n result_ref="$rule_array_ref"
    result_ref=("${parsed_rule[@]}")
    return 0
}

# ========== FILE OPERATIONS ==========
ensure_parent_dir() {
    local target="$1"
    local parent_dir

    if [[ -d $target ]]; then
        parent_dir="$target"
    else
        parent_dir="$(dirname "$target")"
    fi

    [[ -d $parent_dir ]] || mkdir -p "$parent_dir" 2>/dev/null || true
}

handle_file_conflict() {
    local dest="$1" wtree="$2"
    local relative_dest="${dest#$wtree/}"

    case "$conflict_mode" in
        skip)
            log_w "keep (exists): $relative_dest"
            return 1 ;;
        backup)
            local backup="${dest}.bak-$(date +%Y%m%d-%H%M%S)"
            local relative_backup="${backup#$wtree/}"
            log_i "backup: $relative_dest -> $relative_backup"
            mv "$dest" "$backup" ;;
        overwrite)
            return 0 ;;
    esac
}

copy_file_to_dest() {
    local src="$1" dest="$2" want_dir="$3" wtree="$4"

    # Ensure dest ends with / if it should be a directory
    if [[ $want_dir -eq 1 && $dest != */ ]]; then
        dest="${dest}/"
    fi

    # Handle conflicts
    if [[ -e $dest || -L $dest ]]; then
        handle_file_conflict "$dest" "$wtree" || return 0
    fi

    ensure_parent_dir "$dest"

    # Use atomic copy for reliability
    if ! atomic_copy "$src" "$dest"; then
        log_e "Failed to copy $src to $dest"
        return 1
    fi
}

is_glob_pattern() {
    case "$1" in
        *\**|*\?*|*\[*\]*) return 0 ;;
        *) return 1 ;;
    esac
}

# ---------- file matching ----------
find_matching_files() {
    local pattern="$1" repo_dir="$2"
    local -a matches=()

    # Use subshell to contain glob settings and directory change
    (
        cd "$repo_dir" || exit 1
        shopt -s nullglob dotglob

        if is_glob_pattern "$pattern"; then
            # shellcheck disable=SC2206
            matches=( $pattern )
        else
            if [[ -e $pattern || -L $pattern ]]; then
                matches=( "$pattern" )
            fi
        fi

        printf '%s\n' "${matches[@]}"
    )
}

# ---------- copy operations ----------
copy_with_relative_structure() {
    local src="$1" target="$2" source_dir="$3"

    if [[ $dry_run_mode -eq 1 ]]; then
        log_dry "Would copy with relative structure: $src -> $target/"
        return 0
    fi

    log_v "Copying with relative structure: $src to $target/"

    # Execute rsync from source root using subshell
    if ! (cd "$source_dir" && rsync -a --relative "./$src" "$target/"); then
        log_e "Failed to copy $src with relative structure"
        return 1
    fi

    log_s "copied: $src"
}

copy_with_explicit_mapping() {
    local src="$1" dest_rel="$2" wtree="$3" want_dir="$4"
    local dest_abs="$wtree/$dest_rel"

    if [[ $dry_run_mode -eq 1 ]]; then
        local pretty_dest="${dest_abs#$wtree/}"
        log_dry "Would copy with explicit mapping: $src -> $pretty_dest"
        return 0
    fi

    log_v "Copying with explicit mapping: $src to $dest_rel"

    if copy_file_to_dest "$src" "$dest_abs" "$want_dir" "$wtree"; then
        local pretty_dest="${dest_abs#$wtree/}"
        log_s "copied: $src -> $pretty_dest"
    fi
}

# ---------- default patterns copy ----------
copy_with_default_patterns() {
    local target="$1"

    log_v "Copying default patterns to: $target"

    local pattern
    for pattern in "${DEFAULT_COPY_PATTERNS[@]}"; do
        log_d "Processing default pattern: '$pattern'"

        # Find all matching files
        local matching_files
        matching_files="$(find_matching_files "$pattern" "$source_root")"

        if [[ -z $matching_files ]]; then
            log_v "skip (missing): $pattern"
            continue
        fi

        log_v "Found matches for '$pattern': $(echo "$matching_files" | wc -l) files"

        # Process each match using relative structure
        while IFS= read -r src_file; do
            [[ -z $src_file ]] && continue

            # Verify file still exists
            if [[ ! -e "$source_root/$src_file" && ! -L "$source_root/$src_file" ]]; then
                log_w "skip (missing): $src_file"
                continue
            fi

                copy_with_relative_structure "$src_file" "$target" "$source_root"
        done <<< "$matching_files"
    done
}

# ---------- main copy engine ----------
copy_into_target() {
    local target="$1"

    log_v "Processing target: $target"

    # Verify source root exists
    if [[ ! -d $source_root ]]; then
        log_e "Source root does not exist: $source_root"
        return 1
    fi

    if [[ -z $cfg ]]; then
        log_i "No config file found, using default patterns: ${DEFAULT_COPY_PATTERNS[*]}"
        copy_with_default_patterns "$target"
        return 0
    fi

    log_i "Using config: $cfg"
    log_d "Source root: $source_root"

    while IFS= read -r line || [[ -n $line ]]; do
        local -a rule_parts=()
        parse_config_rule "$line" rule_parts || continue

        local src_pattern="${rule_parts[0]}"
        local dest_rel="${rule_parts[1]}"
        local want_dir=0

        log_d "Processing rule: '$src_pattern' -> '$dest_rel'"

        [[ $dest_rel == */ ]] && want_dir=1

        # Find all matching files (passing source_root)
        local matching_files
        matching_files="$(find_matching_files "$src_pattern" "$source_root")"

        if [[ -z $matching_files ]]; then
            log_w "skip (missing): $src_pattern"
            continue
        fi

        log_v "Found matches for '$src_pattern': $(echo "$matching_files" | wc -l) files"

        # Process each match
        while IFS= read -r src_file; do
            [[ -z $src_file ]] && continue

            # Verify file still exists (check in source_root context)
            if [[ ! -e "$source_root/$src_file" && ! -L "$source_root/$src_file" ]]; then
                log_w "skip (missing): $src_file"
                continue
            fi

            # Choose copy method based on whether destination is explicit
            if [[ $dest_rel == "$src_pattern" ]]; then
                copy_with_relative_structure "$src_file" "$target" "$source_root"
            else
                copy_with_explicit_mapping "$source_root/$src_file" "$dest_rel" "$target" "$want_dir"
            fi
        done <<< "$matching_files"

    done < "$cfg"
}

# ---------- path normalization ----------
normalize_target_path() {
    local path="$1"

    case "$path" in
        /*)
            printf '%s' "$path" ;;
        *)
            # Use subshell to avoid changing caller's directory
            if local abs_path; abs_path="$(cd "$path" 2>/dev/null && pwd)"; then
                printf '%s' "$abs_path"
            else
                printf ''
            fi ;;
    esac
}

# ---------- main processing loop ----------
process_targets() {
    local target_path

    for tp in "${TARGET_PATHS[@]}"; do
        [[ -z $tp ]] && continue

        target_path="$(normalize_target_path "$tp")"
        if [[ -z $target_path ]]; then
            log_w "Invalid target path: $tp"
            continue
        fi

        if [[ ! -d $target_path ]]; then
            log_w "Target directory does not exist: $target_path"
            continue
        fi

        log_i "Copying files into: $target_path"
        copy_into_target "$target_path"
    done
}

# ========== MAIN EXECUTION ==========
process_targets
log_s "Done."
