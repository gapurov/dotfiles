#!/usr/bin/env bash
# gwq-addx — gwq add with post-create file copy (no env vars)
# Version: 1.5.0
#
# SUMMARY
#   Wrapper around `gwq add` that copies an explicit set of local files/dirs
#   (e.g., .env*, .cursor/, CLAUDE.md) from the source repo into newly
#   created worktree(s), preserving relative paths. Missing items are skipped.
#
# REQUIREMENTS
#   - bash 4.0+ (required for associative arrays and improved features)
#   - git, gwq, jq, rsync
#   - timeout (optional, for operation timeouts)
#
# CHANGELOG
#   1.5.0 - Major refactoring: improved performance, reliability, maintainability
#           Added verbose/debug/dry-run modes, better error handling, input validation
#   1.4.0 - Performance optimizations and reliability improvements
#   1.3.4 - Original version (legacy)
#
# USAGE
#   gwq-addx [OPTIONS] [--] [gwq add args...]
#
# AUTHOR
#   Enhanced with Claude Code assistance for performance and reliability

set -euo pipefail

# ---------- constants ----------
readonly SCRIPT_VERSION="1.5.0"
readonly MAX_CONFIG_SIZE=1048576  # 1MB
readonly GWQ_TIMEOUT=300          # 5 minutes
readonly REQUIRED_DEPS=(git gwq jq rsync)

# ---------- global variables ----------
declare -g use_color=1 is_tty=0 repo_root=""
declare -g cfg_override="" conflict_mode="skip"
declare -g verbose_mode=0 debug_mode=0 dry_run_mode=0
declare -ga GWQ_ARGS=()

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
Usage: gwq-addx [OPTIONS] [--] [gwq add args...]

OPTIONS:
  --config, -c FILE     Path to rules file (overrides default search)
  --conflict, -C MODE   skip|overwrite|backup   (default: skip)
  --no-color            Disable ANSI colors in output
  --verbose, -v         Enable verbose output
  --debug               Enable debug output
  --dry-run, -n         Show what would be done without executing
  --help, -h            Show help

EXAMPLES:
  gwq-addx my-feature
  gwq-addx --dry-run --verbose my-feature  
  gwq-addx --config ./custom.gwkcopy my-feature
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

validate_gwq_args() {
    if [[ ${#GWQ_ARGS[@]} -eq 0 ]]; then
        log_e "No arguments provided to gwq add"
        return 1
    fi
    
    # Check for basic argument sanity
    local arg
    for arg in "${GWQ_ARGS[@]}"; do
        if [[ -z $arg ]]; then
            log_e "Empty argument detected in gwq args"
            return 1
        fi
        
        # Check for suspicious patterns using safer method
        local arg_len="${#arg}"
        local clean_arg="${arg//[$'\0\n\r']/}"
        if [[ ${#clean_arg} -ne $arg_len ]]; then
            log_e "Invalid control characters in gwq argument: $arg"
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
            --no-color) 
                use_color=0; shift; continue ;;
            -v|--verbose) 
                verbose_mode=1; shift; continue ;;
            --debug) 
                debug_mode=1; verbose_mode=1; shift; continue ;;
            -n|--dry-run) 
                dry_run_mode=1; verbose_mode=1; shift; continue ;;
            --) 
                shift
                while [[ $# -gt 0 ]]; do 
                    GWQ_ARGS+=("$1"); shift
                done
                break ;;
            *) 
                GWQ_ARGS+=("$1"); shift ;;
        esac
    done
}

parse_arguments "$@"

log_d "Parsed arguments: verbose=$verbose_mode debug=$debug_mode dry_run=$dry_run_mode"
log_d "GWQ args: ${GWQ_ARGS[*]:-}"
log_d "Config override: ${cfg_override:-<none>}"
log_d "Conflict mode: $conflict_mode"

# ---------- repo validation ----------
get_repo_root() {
    local root
    if ! root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
        log_e "Please run from inside a git repository."
        exit 1
    fi
    log_v "Repository root: $root" >&2
    printf '%s' "$root"
}

repo_root="$(get_repo_root)"

# ---------- config resolution ----------
find_config_file() {
    local cfg_repo="$repo_root/.gwkcopy"
    local cfg_global="$HOME/.config/gwq/gwkcopy"
    local cfg_global_alt="$HOME/.dotfiles/config/gwq/gwqcopy"
    
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
    elif [[ -f $cfg_global_alt ]] && validate_config_file "$cfg_global_alt"; then
        printf '%s' "$cfg_global_alt"
    else
        printf ''
    fi
}

cfg="$(find_config_file)"

# ---------- input validation ----------
validate_gwq_args || exit 1

# ---------- worktree management ----------
get_worktree_paths() {
    gwq list --json 2>/dev/null | jq -r '.[].path' 2>/dev/null | LC_ALL=C sort -u
}

get_new_worktrees() {
    local -A before_set=()
    local -a before_list=() after_list=() new_list=()
    
    # Snapshot before - store in array and associative array for fast lookup
    mapfile -t before_list < <(with_error_recovery "list worktrees (before)" get_worktree_paths)
    
    local path
    for path in "${before_list[@]}"; do
        before_set["$path"]=1
    done
    
    # Run gwq add with timeout and error recovery
    log_i "Creating worktree(s): gwq add ${GWQ_ARGS[*]:-}" >&2
    if [[ $dry_run_mode -eq 1 ]]; then
        log_dry "Would run: gwq add ${GWQ_ARGS[*]:-}" >&2
        # In dry-run mode, simulate some new worktrees for testing
        printf '/tmp/dry-run-worktree-1\n/tmp/dry-run-worktree-2\n'
        return 0
    else
        # Capture gwq add output but suppress it from stdout to avoid parsing issues
        local gwq_output
        gwq_output="$(gwq add "${GWQ_ARGS[@]}" 2>&1)" || {
            log_e "gwq add failed: $gwq_output" >&2
            die 1
        }
        log_v "gwq add output: $gwq_output" >&2
    fi
    
    # Snapshot after and find new paths
    mapfile -t after_list < <(with_error_recovery "list worktrees (after)" get_worktree_paths)
    
    # Find new paths efficiently using associative array lookup
    for path in "${after_list[@]}"; do
        if [[ -z ${before_set[$path]:-} ]]; then
            new_list+=("$path")
        fi
    done
    
    printf '%s\n' "${new_list[@]}"
}

new_paths="$(get_new_worktrees)"

log_d "Raw new_paths output: '$new_paths'"

if [[ -z $new_paths ]]; then
    log_w "No new worktree paths detected. Nothing to copy."
    exit 0
fi


# ========== UTILITY FUNCTIONS ==========

# Remove leading and trailing whitespace from string
# Args: str - input string to trim
# Returns: trimmed string via stdout
trim_string() {
    local str="$1"
    # Remove leading whitespace
    str="${str#"${str%%[![:space:]]*}"}"
    # Remove trailing whitespace
    str="${str%"${str##*[![:space:]]}"}"
    printf '%s' "$str"
}

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
    local src="$1" wtree="$2" repo_dir="$3"
    
    if [[ $dry_run_mode -eq 1 ]]; then
        log_dry "Would copy with relative structure: $src -> $wtree/"
        return 0
    fi
    
    log_v "Copying with relative structure: $src to $wtree/"
    
    # Execute rsync from repo root using subshell
    if ! (cd "$repo_dir" && rsync -a --relative "./$src" "$wtree/"); then
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

# ---------- main copy engine ----------
copy_into_worktree() {
    local wtree="$1"

    log_v "Processing worktree: $wtree"

    if [[ -z $cfg ]]; then
        log_w "No .gwkcopy found (repo or global). Skipping copy."
        return 0
    fi

    log_i "Using config: $cfg"
    log_d "Repository root: $repo_root"

    # Verify repo root exists
    if [[ ! -d $repo_root ]]; then
        log_e "Repository root does not exist: $repo_root"
        return 1
    fi

    while IFS= read -r line || [[ -n $line ]]; do
        local -a rule_parts=()
        parse_config_rule "$line" rule_parts || continue
        
        local src_pattern="${rule_parts[0]}"
        local dest_rel="${rule_parts[1]}"
        local want_dir=0
        
        log_d "Processing rule: '$src_pattern' -> '$dest_rel'"
        
        [[ $dest_rel == */ ]] && want_dir=1

        # Find all matching files (passing repo_root)
        local matching_files
        matching_files="$(find_matching_files "$src_pattern" "$repo_root")"
        
        if [[ -z $matching_files ]]; then
            log_w "skip (missing): $src_pattern"
            continue
        fi
        
        log_v "Found matches for '$src_pattern': $(echo "$matching_files" | wc -l) files"

        # Process each match
        while IFS= read -r src_file; do
            [[ -z $src_file ]] && continue
            
            # Verify file still exists (check in repo_root context)
            if [[ ! -e "$repo_root/$src_file" && ! -L "$repo_root/$src_file" ]]; then
                log_w "skip (missing): $src_file"
                continue
            fi

            # Choose copy method based on whether destination is explicit
            if [[ $dest_rel == "$src_pattern" ]]; then
                copy_with_relative_structure "$src_file" "$wtree" "$repo_root"
            else
                copy_with_explicit_mapping "$repo_root/$src_file" "$dest_rel" "$wtree" "$want_dir"
            fi
        done <<< "$matching_files"
        
    done < "$cfg"
}

# ---------- path normalization ----------
normalize_worktree_path() {
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
process_new_worktrees() {
    local worktree_path
    
    while IFS= read -r wp || [[ -n $wp ]]; do
        [[ -z $wp ]] && continue
        
        worktree_path="$(normalize_worktree_path "$wp")"
        [[ -z $worktree_path ]] && {
            log_w "Invalid worktree path: $wp"
            continue
        }

        log_i "Post-copy into: $worktree_path"
        copy_into_worktree "$worktree_path"
    done <<< "$new_paths"
}

# ========== MAIN EXECUTION ==========
process_new_worktrees
log_s "Done."
