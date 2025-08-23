#!/usr/bin/env bash

set -euo pipefail

# Configuration
readonly SCRIPT_VERSION="3.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_FILE="$SCRIPT_DIR/install.conf.sh"
readonly BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

# Colors
readonly BLUE='\033[1m\033[34m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly RED='\033[0;31m'
readonly GRAY='\033[0;90m'
readonly NC='\033[0m'

# Global flags
DRY_RUN=false
VERBOSE=false

# Global variables
LINKS_PROCESSED=0
STEPS_PROCESSED=0
ERRORS_COUNT=0

# External utilities
readonly TIMEOUT_BIN="$(command -v timeout || command -v gtimeout || echo "")"

# Logging functions
log() { printf "%b==> %s%b\n" "$BLUE" "$1" "$NC"; }
success() { printf "%b✓ %s%b\n" "$GREEN" "$1" "$NC"; }
warn() { printf "%b⚠ %s%b\n" "$YELLOW" "$1" "$NC"; }
error() { printf "%b✗ %s%b\n" "$RED" "$1" "$NC" >&2; ERRORS_COUNT=$((ERRORS_COUNT + 1)); }
info() { printf "%b  %s%b\n" "$GRAY" "$1" "$NC"; }
debug() { [[ "$VERBOSE" == true ]] && printf "%b[DEBUG] %s%b\n" "$GRAY" "$1" "$NC" >&2; }

show_help() {
    cat << 'EOF'
Dotfiles Installation Script

USAGE:
    ./install.sh [OPTIONS]

OPTIONS:
    -d, --dry-run         Show what would be done without executing
    -v, --verbose         Enable verbose output with debug information
    -h, --help           Show this help message

EXAMPLES:
    ./install.sh                    # Run full installation
    ./install.sh --dry-run          # Preview changes without executing
    ./install.sh --verbose          # Detailed installation with debug info
    ./install.sh --dry-run -v       # Preview with verbose output

DESCRIPTION:
    This script reads configuration from install.conf.sh and performs:
    1. Creates symbolic links for dotfiles
    2. Executes installation steps in order
    3. Creates backups of existing files when necessary
    4. Provides idempotent operation (safe to run multiple times)

EOF
}

validate_environment() {
    debug "Validating environment..."

    # Check if config file exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        error "Configuration file not found: $CONFIG_FILE"
        return 1
    fi

    # Check if we're in the right directory
    if [[ ! -d "$SCRIPT_DIR/.git" ]]; then
        warn "Not in a git repository. Some features may not work correctly."
    fi

    debug "Environment validation complete"
}

load_configuration() {
    debug "Loading configuration from: $CONFIG_FILE"

    # Source the configuration file to load LINKS and STEPS arrays
    # shellcheck source=install.conf.sh
    source "$CONFIG_FILE"

    # Validate that required arrays exist (Bash 3.2 compatible)
    if [[ -z ${LINKS+x} ]]; then
        error "LINKS array not found in configuration file"
        return 1
    fi

    if [[ -z ${STEPS+x} ]]; then
        warn "No STEPS defined in configuration; proceeding with links only"
        STEPS=()
    fi

    debug "Configuration loaded: ${#LINKS[@]} links, ${#STEPS[@]} steps"
}

# Resolve a path to an absolute path, optionally relative to a base directory
resolve_absolute_path() {
    local input_path="$1"
    local base_dir="${2:-}"

    if command -v perl >/dev/null 2>&1; then
        perl -MCwd=abs_path -e 'use Cwd qw(abs_path); my($base,$p)=@ARGV; chdir $base if $base; print abs_path($p);' "$base_dir" "$input_path"
        return 0
    fi
    if [[ -n "$base_dir" ]]; then
        (cd "$base_dir" 2>/dev/null && printf "%s" "$PWD/$input_path")
    else
        printf "%s" "$input_path"
    fi
    return 0
}

# Determine whether a symlink points to the expected absolute path target
symlink_points_to() {
    local link_path="$1"
    local expected_abs="$2"
    local link_dir target resolved
    link_dir="$(dirname "$link_path")"
    target="$(readlink "$link_path")" || return 1
    resolved="$(resolve_absolute_path "$target" "$link_dir")" || return 1
    [[ "$resolved" == "$expected_abs" ]]
}

backup_file() {
    local file_path="$1"

    if [[ -e "$file_path" ]]; then
        # Create backup directory if it doesn't exist
        if [[ ! -d "$BACKUP_DIR" ]]; then
            if [[ "$DRY_RUN" == false ]]; then
                mkdir -p "$BACKUP_DIR"
                debug "Created backup directory: $BACKUP_DIR"
            fi
        fi

        # Preserve original path structure inside backup directory
        local relative_path="${file_path#/}"
        local backup_path="$BACKUP_DIR/$relative_path"

        if [[ "$DRY_RUN" == false ]]; then
            mkdir -p "$(dirname "$backup_path")"
            cp -a "$file_path" "$backup_path"
            info "Backed up: $file_path -> $backup_path"
        else
            info "Would backup: $file_path -> $backup_path"
        fi
        return 0
    fi
    return 1
}

create_symlink() {
    local source_rel="$1"
    local target_path="$2"

    # Convert relative source to absolute path
    local source_abs="$SCRIPT_DIR/$source_rel"
    local source_real
    source_real="$(resolve_absolute_path "$source_abs")"
    local target_abs
    target_abs="${target_path/#\~/$HOME}"

    debug "Processing symlink: $source_rel -> $target_path"

    # Check if source exists
    if [[ ! -e "$source_abs" ]]; then
        warn "Source file doesn't exist: $source_abs"
        return 1
    fi

    # Create target directory if needed
    local target_dir
    target_dir="$(dirname "$target_abs")"
    if [[ ! -d "$target_dir" ]]; then
        if [[ "$DRY_RUN" == false ]]; then
            mkdir -p "$target_dir"
            debug "Created directory: $target_dir"
        else
            info "Would create directory: $target_dir"
        fi
    fi

    # Handle existing target
    if [[ -L "$target_abs" ]]; then
        # It's a symlink - check if it points to the right place (resolve relative targets)
        if symlink_points_to "$target_abs" "$source_real"; then
            debug "Symlink already exists and is correct: $target_abs"
            return 0
        else
            # Backup the incorrect symlink
            backup_file "$target_abs"
            if [[ "$DRY_RUN" == false ]]; then
                rm "$target_abs"
                debug "Removed incorrect symlink: $target_abs"
            else
                info "Would remove incorrect symlink: $target_abs"
            fi
        fi
    elif [[ -e "$target_abs" ]]; then
        # It's a regular file/directory - back it up
        backup_file "$target_abs"
        if [[ "$DRY_RUN" == false ]]; then
            rm -rf "$target_abs"
            debug "Removed existing file: $target_abs"
        else
            info "Would remove existing file: $target_abs"
        fi
    fi

    # Create the symlink
    if [[ "$DRY_RUN" == false ]]; then
        ln -s "$source_abs" "$target_abs"
        success "Created symlink: $source_rel -> $target_path"
    else
        info "Would create symlink: $source_rel -> $target_path"
    fi

    return 0
}

process_symlinks() {
    log "Processing symbolic links..."

    for link_spec in "${LINKS[@]}"; do
        if [[ -z "$link_spec" ]]; then
            continue
        fi

        # Skip comments
        if [[ "$link_spec" =~ ^[[:space:]]*# ]]; then
            debug "Skipping comment: $link_spec"
            continue
        fi

        # Validate that a colon exists in the spec
        if [[ "$link_spec" != *:* ]]; then
            error "Invalid link specification (no colon found): $link_spec"
            continue
        fi

        # Split on the first colon
        local source="${link_spec%%:*}"
        local target="${link_spec#*:}"

        if create_symlink "$source" "$target"; then
            LINKS_PROCESSED=$((LINKS_PROCESSED + 1))
        fi
    done

    if [[ $LINKS_PROCESSED -gt 0 ]]; then
        success "Processed $LINKS_PROCESSED symbolic links"
    else
        warn "No symbolic links were processed"
    fi
}

execute_step() {
    local step_command="$1"

    debug "Executing step: $step_command"

    if [[ "$DRY_RUN" == false ]]; then
        # Change to script directory for execution
        cd "$SCRIPT_DIR"

        # Use timeout to prevent hanging steps when available
        local exit_code=0
        if [[ -n "$TIMEOUT_BIN" ]]; then
            if "$TIMEOUT_BIN" 300 bash -c "$step_command"; then
                success "Completed step: $step_command"
                STEPS_PROCESSED=$((STEPS_PROCESSED + 1))
                return 0
            else
                exit_code=$?
                if [[ $exit_code -eq 124 ]]; then
                    error "Step timed out (5 minutes): $step_command"
                else
                    error "Step failed (exit code: $exit_code): $step_command"
                fi
                return $exit_code
            fi
        else
            warn "No timeout command found; running step without timeout"
            if bash -c "$step_command"; then
                success "Completed step: $step_command"
                STEPS_PROCESSED=$((STEPS_PROCESSED + 1))
                return 0
            else
                exit_code=$?
                error "Step failed (exit code: $exit_code): $step_command"
                return $exit_code
            fi
        fi
    else
        info "Would execute: $step_command"
        STEPS_PROCESSED=$((STEPS_PROCESSED + 1))
        return 0
    fi
}

process_steps() {
    log "Processing installation steps..."

    for step in "${STEPS[@]}"; do
        if [[ -z "$step" ]]; then
            continue
        fi

        # Skip steps that start with # (comments)
        if [[ "$step" =~ ^[[:space:]]*# ]]; then
            debug "Skipping comment: $step"
            continue
        fi

        execute_step "$step"
    done

    if [[ $STEPS_PROCESSED -gt 0 ]]; then
        success "Processed $STEPS_PROCESSED installation steps"
    else
        warn "No installation steps were processed"
    fi
}

show_summary() {
    log "Installation Summary"
    printf "  Symbolic links: %d\n" "$LINKS_PROCESSED"
    printf "  Installation steps: %d\n" "$STEPS_PROCESSED"
    printf "  Errors: %d\n" "$ERRORS_COUNT"

    if [[ -d "$BACKUP_DIR" ]]; then
        info "Backups saved to: $BACKUP_DIR"
    fi

    if [[ "$DRY_RUN" == true ]]; then
        info "This was a dry run - no changes were made"
    fi
}

# Ensure summary is printed on any exit path
trap 'show_summary' EXIT

main() {
    log "Dotfiles Installation Script (v$SCRIPT_VERSION)"

    if [[ "$DRY_RUN" == true ]]; then
        warn "DRY RUN MODE - No changes will be made"
    fi

    validate_environment || exit 1
    load_configuration || exit 1

    process_symlinks
    process_steps

    if [[ $ERRORS_COUNT -gt 0 ]]; then
        error "Installation completed with $ERRORS_COUNT errors"
        exit 1
    else
        success "Installation completed successfully!"
        exit 0
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "${1:-}" in
        -d|--dry-run)
            DRY_RUN=true
            shift ;;
        -v|--verbose)
            VERBOSE=true
            shift ;;
        -h|--help)
            show_help
            exit 0 ;;
        *)
            error "Unknown option: $1"
            show_help
            exit 1 ;;
    esac
done

# Run main function
main "$@"
