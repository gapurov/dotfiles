#!/usr/bin/env bash

set -euo pipefail

# Remote installation script for dotfiles
# Usage: curl -fsSL https://raw.githubusercontent.com/gapurov/dotfiles/master/remote-install.sh | bash
# With args: curl -fsSL https://raw.githubusercontent.com/gapurov/dotfiles/master/remote-install.sh | bash -s -- --dry-run

readonly REPO_URL="${DOTFILES_REPO:-https://github.com/gapurov/dotfiles.git}"
readonly DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
# Branch is determined dynamically (env > local repo > remote default > master)
BRANCH=""

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Verbose flag (mirrors install options but not consumed)
VERBOSE=false

# Logging functions
log() { printf "%b==> %s%b\n" "$BLUE" "$1" "$NC"; }
success() { printf "%b✓ %s%b\n" "$GREEN" "$1" "$NC"; }
warn() { printf "%b⚠ %s%b\n" "$YELLOW" "$1" "$NC" >&2; }
error() { printf "%b✗ %s%b\n" "$RED" "$1" "$NC" >&2; }
info() { printf "%b  %s%b\n" "\033[0;90m" "$1" "$NC"; }
debug() { [[ "$VERBOSE" == true ]] && printf "%b[DEBUG] %s%b\n" "\033[0;90m" "$1" "$NC" >&2 || true; }

# Trap to surface line/command on failure for easier diagnostics
trap 'rc=$?; [[ $rc -ne 0 ]] && error "Installation failed (exit $rc) at line $LINENO"; exit $rc' ERR

# Check if a command exists
have() { command -v "$1" >/dev/null 2>&1; }

# Compute parallel jobs for git/submodules
cpu_jobs() {
    if [[ -n "${DOTFILES_JOBS:-}" ]]; then
        echo "$DOTFILES_JOBS"
        return 0
    fi
    local n
    if have sysctl; then
        n=$(sysctl -n hw.ncpu 2>/dev/null || true)
    fi
    if [[ -z "$n" ]]; then
        n=$(getconf _NPROCESSORS_ONLN 2>/dev/null || true)
    fi
    [[ -z "$n" ]] && n=4
    echo "$n"
}

# Initialize and update git submodules with sane defaults and speed
update_submodules() {
    if [[ "${DOTFILES_SUBMODULES_SKIP:-0}" -eq 1 ]]; then
        debug "Skipping submodules (DOTFILES_SUBMODULES_SKIP=1)"
        return 0
    fi

    if [[ ! -d .git ]]; then
        warn "Not a git repository; skipping submodules"
        return 0
    fi

    local jobs
    jobs="$(cpu_jobs)"
    debug "Submodule jobs: $jobs"

    log "Syncing and updating submodules..."
    git submodule sync --recursive >/dev/null 2>&1 || true

    local -a depth_args=()
    if [[ "${DOTFILES_SUBMODULES_SHALLOW:-0}" -eq 1 ]]; then
        depth_args=("--depth" "1")
    fi

    # Always ensure pinned commits are present
    if git -c fetch.parallel="$jobs" -c submodule.fetchJobs="$jobs" \
        submodule update --init --recursive --jobs "$jobs" "${depth_args[@]}"; then
        success "Submodules are initialized"
    else
        error "Failed to initialize submodules"
        return 1
    fi

    # Optionally move submodules to latest remote tracking refs
    if [[ "${DOTFILES_SUBMODULES_REMOTE:-0}" -eq 1 ]]; then
        info "Updating submodules to latest remote (no superproject commit)"
        if git -c fetch.parallel="$jobs" -c submodule.fetchJobs="$jobs" \
            submodule update --remote --recursive --jobs "$jobs" "${depth_args[@]}"; then
            success "Submodules updated to remote HEAD"
        else
            warn "Remote submodule update failed; pinned versions remain"
        fi
    fi

    return 0
}

# Refuse to run as root unless explicitly allowed
require_not_root() {
    if [[ ${ALLOW_ROOT:-0} -ne 1 ]] && [[ ${EUID:-$(id -u)} -eq 0 ]]; then
        error "Do not run as root/sudo. Re-run as your user."
        warn "To override intentionally, set ALLOW_ROOT=1."
        exit 1
    fi
}

# Determine which branch to use (env > local repo > remote default > master)
determine_branch() {
    if [[ -n "${DOTFILES_BRANCH:-}" ]]; then
        echo "$DOTFILES_BRANCH"
        return 0
    fi

    if [[ -d "$DOTFILES_DIR/.git" ]] && have git; then
        local current
        current=$(git -C "$DOTFILES_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
        if [[ -n "$current" && "$current" != "HEAD" ]]; then
            echo "$current"
            return 0
        fi
    fi

    if have git; then
        local remote_default
        remote_default=$(git ls-remote --symref "$REPO_URL" HEAD 2>/dev/null | awk '/^ref:/ {print $2}' | sed 's@refs/heads/@@' || true)
        if [[ -n "$remote_default" ]]; then
            echo "$remote_default"
            return 0
        fi
    fi

    echo "master"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."

    if ! have git; then
        error "Git is required but not installed"
        error "Please install Git and try again"
        exit 1
    fi

    if ! have bash; then
        error "Bash is required but not found"
        exit 1
    fi

    success "Prerequisites check passed"
}

# Clone or update the dotfiles repository
setup_repository() {
    # resolve branch to use
    BRANCH="$(determine_branch)"
    debug "Using branch: $BRANCH"

    # ensure destination dir parent is writable
    local parent
    parent="$(dirname "$DOTFILES_DIR")"
    if [[ ! -d "$parent" ]]; then
        error "Parent directory does not exist: $parent"
        exit 1
    fi
    if [[ ! -w "$parent" ]]; then
        error "Parent directory not writable: $parent"
        exit 1
    fi
    if [[ -d "$DOTFILES_DIR" ]]; then
        log "Dotfiles directory exists at $DOTFILES_DIR"

        if [[ -d "$DOTFILES_DIR/.git" ]]; then
            log "Updating existing repository..."
            cd "$DOTFILES_DIR"

            # Warn if origin remote differs from expected
            if have git; then
                local origin_url
                origin_url=$(git remote get-url origin 2>/dev/null || echo "")
                if [[ -n "$origin_url" && "$origin_url" != "$REPO_URL" ]]; then
                    warn "Origin URL differs: $origin_url (expected $REPO_URL)"
                fi
            fi

            # Check if we're on the right branch and pull updates
            current_branch=$(git branch --show-current 2>/dev/null || echo "")
            if [[ "$current_branch" != "$BRANCH" ]]; then
                warn "Repository is on branch '$current_branch', switching to '$BRANCH'"
                git checkout "$BRANCH" >/dev/null 2>&1 || {
                    warn "Could not switch to branch '$BRANCH', continuing with current branch"
                }
            fi

            # Pull latest changes
            if git fetch --tags --prune >/dev/null 2>&1 && git pull --ff-only origin "$BRANCH" >/dev/null 2>&1; then
                success "Repository updated successfully"
            else
                warn "Could not update repository, continuing with local version"
            fi
        else
            error "Directory $DOTFILES_DIR exists but is not a git repository"
            local backup_dir="$DOTFILES_DIR.bak.$(date +%Y%m%d-%H%M%S)"
            warn "Moving it aside to: $backup_dir"
            mv "$DOTFILES_DIR" "$backup_dir"
            log "Cloning dotfiles repository..."
            local tmp_dir
            tmp_dir="${DOTFILES_DIR}.tmp.$(date +%s)"
            local -a clone_args=("--branch" "$BRANCH" "--recurse-submodules")
            # Shallow options for main repo and submodules
            if [[ "${DOTFILES_SHALLOW:-0}" -eq 1 ]]; then
                clone_args+=("--depth" "1" "--no-single-branch")
            fi
            if [[ "${DOTFILES_SUBMODULES_SHALLOW:-0}" -eq 1 ]]; then
                clone_args+=("--shallow-submodules")
            fi
            if git clone "${clone_args[@]}" "$REPO_URL" "$tmp_dir"; then
                mv "$tmp_dir" "$DOTFILES_DIR"
                success "Repository cloned successfully"
            else
                rm -rf "$tmp_dir" 2>/dev/null || true
                error "Failed to clone repository"
                exit 1
            fi
        fi
    else
        log "Cloning dotfiles repository..."
        local tmp_dir
        tmp_dir="${DOTFILES_DIR}.tmp.$(date +%s)"
        local -a clone_args=("--branch" "$BRANCH" "--recurse-submodules")
        # Shallow options for main repo and submodules
        if [[ "${DOTFILES_SHALLOW:-0}" -eq 1 ]]; then
            clone_args+=("--depth" "1" "--no-single-branch")
        fi
        if [[ "${DOTFILES_SUBMODULES_SHALLOW:-0}" -eq 1 ]]; then
            clone_args+=("--shallow-submodules")
        fi
        if git clone "${clone_args[@]}" "$REPO_URL" "$tmp_dir"; then
            mv "$tmp_dir" "$DOTFILES_DIR"
            success "Repository cloned successfully"
        else
            rm -rf "$tmp_dir" 2>/dev/null || true
            error "Failed to clone repository"
            exit 1
        fi
    fi

    # Ensure we're in the dotfiles directory
    cd "$DOTFILES_DIR"

    # Initialize and update submodules before running installer
    update_submodules || {
        error "Failed to initialize/update submodules"
        exit 1
    }

    # Make install.sh executable
    if [[ -f "install.sh" ]]; then
        chmod +x install.sh
    else
        error "install.sh not found in repository"
        exit 1
    fi
}

# Run the installation
run_installation() {
    log "Running dotfiles installation..."

    # Pass all arguments to install.sh
    if [[ $# -eq 0 ]]; then
        ./install.sh
    else
        ./install.sh "$@"
    fi
}

# Show help message
show_help() {
    cat << 'EOF'
Remote Dotfiles Installation Script

This script automatically downloads and installs dotfiles from the repository.

USAGE:
    curl -fsSL https://raw.githubusercontent.com/gapurov/dotfiles/master/remote-install.sh | bash
    curl -fsSL https://raw.githubusercontent.com/gapurov/dotfiles/master/remote-install.sh | bash -s -- [OPTIONS]

OPTIONS:
    All options are passed through to the install.sh script:

    -d, --dry-run         Show what would be done without executing
    -v, --verbose         Enable verbose output with debug information
    --links-only          Process only symlinks (skip steps)
    --steps-only          Process only steps (skip symlinks)
    -h, --help           Show this help message

EXAMPLES:
    # Basic installation
    curl -fsSL https://raw.githubusercontent.com/gapurov/dotfiles/master/remote-install.sh | bash

    # Preview installation without making changes
    curl -fsSL https://raw.githubusercontent.com/gapurov/dotfiles/master/remote-install.sh | bash -s -- --dry-run

    # Install with verbose output
    curl -fsSL https://raw.githubusercontent.com/gapurov/dotfiles/master/remote-install.sh | bash -s -- --verbose

    # Install only symlinks
    curl -fsSL https://raw.githubusercontent.com/gapurov/dotfiles/master/remote-install.sh | bash -s -- --links-only

    # Faster clone with shallow submodules
    DOTFILES_SHALLOW=1 DOTFILES_SUBMODULES_SHALLOW=1 \
      curl -fsSL https://raw.githubusercontent.com/gapurov/dotfiles/master/remote-install.sh | bash

    # Update submodules to their remote tracking branches
    DOTFILES_SUBMODULES_REMOTE=1 \
      curl -fsSL https://raw.githubusercontent.com/gapurov/dotfiles/master/remote-install.sh | bash

ENVIRONMENT VARIABLES:
    DOTFILES_REPO               Alternate repo URL (default: gapurov/dotfiles)
    DOTFILES_DIR                Alternate install directory (default: ~/.dotfiles)
    DOTFILES_BRANCH             Branch to clone (default: remote default or master)
    DOTFILES_SHALLOW=1          Use shallow clone for main repo
    DOTFILES_SUBMODULES_SHALLOW=1  Use shallow clones for submodules
    DOTFILES_SUBMODULES_REMOTE=1   Update submodules to latest remote (not pinned)
    DOTFILES_SUBMODULES_SKIP=1     Skip submodule init/update entirely
    DOTFILES_JOBS=N             Parallel jobs for submodule fetch/update
    ALLOW_ROOT=1                Allow running as root (not recommended)

DESCRIPTION:
    This script will:
    1. Check for required dependencies (git, bash)
    2. Clone or update the dotfiles repository to ~/.dotfiles
    3. Initialize and update git submodules (recursive, fast, optional shallow)
    4. Execute the install.sh script with any provided arguments
    5. Handle errors and provide clear feedback

EOF
}

# Main function
main() {
    # Enable verbose logging in wrapper if -v/--verbose provided
    for arg in "$@"; do
        if [[ "$arg" == "-v" || "$arg" == "--verbose" ]]; then
            VERBOSE=true
            break
        fi
    done

    require_not_root
    # Handle help argument
    for arg in "$@"; do
        if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
            show_help
            exit 0
        fi
    done

    log "Starting remote dotfiles installation..."

    check_prerequisites
    setup_repository
    # Optionally validate environment if script exists
    if [[ -x "./scripts/validate-environment.sh" ]]; then
        info "Validating environment..."
        ./scripts/validate-environment.sh || warn "Environment validation reported issues"
    fi
    run_installation "$@"

    success "Dotfiles installation completed!"
    log "Repository is available at: $DOTFILES_DIR"
}

# Run main function with all arguments
main "$@"
