#!/usr/bin/env bash

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# Configuration
readonly SCRIPT_VERSION="2.1.0"
readonly DOTFILES_DIR="$HOME/.dotfiles"
readonly OH_MY_ZSH_DIR="$HOME/.oh-my-zsh"
readonly BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

# Platform detection
readonly OS_TYPE="$(uname -s)"
readonly ARCH_TYPE="$(uname -m)"

# Homebrew path detection
if [[ "$ARCH_TYPE" == "arm64" ]]; then
    readonly BREW_PREFIX="/opt/homebrew"
else
    readonly BREW_PREFIX="/usr/local"
fi

# Colors for output
readonly BLUE='\033[1m\033[34m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

# Flags
DRY_RUN=false
VERBOSE=false
SKIP_REBOOT=false

# Logging functions (use printf for portability)
log() { printf "%b==> %s%b\n" "$BLUE" "$1" "$NC"; }
success() { printf "%b✓ %s%b\n" "$GREEN" "$1" "$NC"; }
warn() { printf "%b⚠ %s%b\n" "$YELLOW" "$1" "$NC"; }
error() { printf "%b✗ %s%b\n" "$RED" "$1" "$NC" >&2; }
debug() { [[ "$VERBOSE" == true ]] && printf "%s\n" "DEBUG: $1" >&2; }

# Progress tracking
declare -a INSTALL_STEPS=(
    "validate_environment"
    "update_submodules"
    "install_homebrew"
    "install_brew_packages"
    "install_mas_apps"
    "install_custom_apps"
    "setup_symlinks"
    "configure_tmux"
    "install_js_packages"
    "setup_shell"
    "configure_macos"
)
CURRENT_STEP=0
TOTAL_STEPS=${#INSTALL_STEPS[@]}

show_progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local percent=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    log "Progress: [$CURRENT_STEP/$TOTAL_STEPS] ($percent%) - $1"
}

# Validation functions
validate_os() {
    if [[ "$OS_TYPE" == "Darwin" ]]; then
        return 0
    else
        error "This script is designed for macOS only. Detected: $OS_TYPE"
        return 1
    fi
}

validate_prerequisites() {
    local required_commands=("curl" "git" "xcode-select")
    local missing_commands=()

    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_commands+=("$cmd")
        fi
    done

    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        error "Missing required commands: ${missing_commands[*]}"
        log "Please install Xcode Command Line Tools: xcode-select --install"
        return 1
    fi
}

validate_xcode_clt() {
    if ! xcode-select -p &>/dev/null; then
        error "Xcode Command Line Tools not detected."
        log "Install with: xcode-select --install"
        return 1
    fi
}

validate_network() {
    if ! curl -s --connect-timeout 5 https://github.com &>/dev/null; then
        error "No internet connection or GitHub is unreachable"
        return 1
    fi
}

validate_permissions() {
    local test_dirs=("$HOME" "$HOME/.config")
    for dir in "${test_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir" 2>/dev/null || {
                error "Cannot create directory: $dir"
                return 1
            }
        fi
        if [[ ! -w "$dir" ]]; then
            error "No write permission to $dir"
            return 1
        fi
    done
}

# Utility functions
command_exists() {
    command -v "$1" &>/dev/null
}

backup_file() {
    local file="$1"
    [[ -e "$file" ]] || return 0

    local rel_path
    if [[ "$file" == "$HOME"/* ]]; then
        rel_path="${file#"$HOME/"}"
    else
        rel_path="$(basename "$file")"
    fi

    local dest_dir="$BACKUP_DIR/$(dirname "$rel_path")"
    mkdir -p "$dest_dir"
    cp -a "$file" "$dest_dir/" 2>/dev/null || cp "$file" "$dest_dir/" 2>/dev/null || true
    debug "Backed up $file to $dest_dir"
}

# Enhanced symlink function
safe_symlink() {
    local source="$1"
    local target="$2"
    local backup_existing="${3:-true}"

    # Validate inputs
    [[ -n "$source" && -n "$target" ]] || {
        error "safe_symlink: source and target must be provided"
        return 1
    }

    [[ -e "$source" ]] || {
        error "Source does not exist: $source"
        return 1
    }

    if [[ "$DRY_RUN" == true ]]; then
        log "DRY RUN: Would symlink $source -> $target"
        return 0
    fi

    # Create target directory
    mkdir -p "$(dirname "$target")" || {
        error "Failed to create directory: $(dirname "$target")"
        return 1
    }

    # Handle existing files/links
    if [[ -L "$target" ]]; then
        local current_target
        current_target="$(readlink "$target")"
        if [[ "$current_target" == "$source" ]]; then
            debug "Symlink already correct: $target -> $source"
            return 0
        fi
        rm -f "$target"
    elif [[ -e "$target" ]]; then
        [[ "$backup_existing" == true ]] && backup_file "$target"
        rm -f "$target"
    fi

    # Create symlink
    ln -sf "$source" "$target" || {
        error "Failed to create symlink: $source -> $target"
        return 1
    }

    debug "Created symlink: $target -> $source"
}

# Installation functions
install_homebrew() {
    if command_exists brew; then
        success "Homebrew already installed at $(command -v brew)"
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log "DRY RUN: Would install Homebrew"
        return 0
    fi

    log "Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Setup environment
    local brew_env="eval \"\$($BREW_PREFIX/bin/brew shellenv)\""
    if ! grep -qF "$brew_env" "$HOME/.zprofile" 2>/dev/null; then
        echo "$brew_env" >> "$HOME/.zprofile"
    fi
    eval "$($BREW_PREFIX/bin/brew shellenv)"
}

install_oh_my_zsh() {
    if [[ -d "$OH_MY_ZSH_DIR" ]]; then
        success "Oh My Zsh already installed"
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log "DRY RUN: Would install Oh My Zsh"
        return 0
    fi

    log "Installing Oh My Zsh"
    RUNZSH=no sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

# Enhanced script runner
run_script() {
    local script="$1"
    local description="$2"
    local optional="${3:-false}"

    if [[ ! -f "$script" ]]; then
        if [[ "$optional" == true ]]; then
            warn "Optional script not found: $script"
            return 0
        else
            error "Required script not found: $script"
            return 1
        fi
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log "DRY RUN: Would run $script ($description)"
        return 0
    fi

    log "$description"
    if [[ "$VERBOSE" == true ]]; then
        bash -x "$script"
    else
        bash "$script"
    fi || {
        error "Failed to run $script"
        return 1
    }
}

# Configuration data (Bash 3-compatible; avoid associative arrays)
declare -a SYMLINKS_PAIRS=(
    "$DOTFILES_DIR/git/gitconfig:$HOME/.gitconfig"
    "$DOTFILES_DIR/git/gitignore:$HOME/.gitignore"
    "$DOTFILES_DIR/zsh/zshrc.zsh:$HOME/.zshrc"
    "$DOTFILES_DIR/config/karabiner.json:$HOME/.config/karabiner/karabiner.json"
    "$DOTFILES_DIR/config/claude/agents:$HOME/.claude/agents"
)

# Only add npmrc if it's not empty
if [[ -s "$DOTFILES_DIR/javascript/npmrc" ]]; then
    SYMLINKS_PAIRS+=("$DOTFILES_DIR/javascript/npmrc:$HOME/.npmrc")
fi



# Main installation functions
validate_environment() {
    show_progress "Validating environment"
    local failed_checks=0

    debug "Starting OS validation"
    validate_os || ((failed_checks++))

    debug "Starting prerequisites validation"
    validate_prerequisites || ((failed_checks++))

    debug "Validating Xcode Command Line Tools"
    validate_xcode_clt || ((failed_checks++))

    debug "Starting network validation"
    validate_network || ((failed_checks++))

    debug "Starting permissions validation"
    validate_permissions || ((failed_checks++))

    if [[ $failed_checks -eq 0 ]]; then
        success "Environment validation complete"
        return 0
    else
        error "Environment validation failed ($failed_checks check(s) failed)"
        return 1
    fi
}

update_submodules() {
    show_progress "Updating git submodules"
    
    if [[ "$DRY_RUN" == true ]]; then
        log "DRY RUN: Would update git submodules"
        return 0
    fi

    if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
        warn "Not a git repository, skipping submodule update"
        return 0
    fi

    log "Initializing and updating git submodules"
    cd "$DOTFILES_DIR" || {
        error "Failed to change to dotfiles directory: $DOTFILES_DIR"
        return 1
    }

    if ! git submodule update --init --recursive; then
        error "Failed to update git submodules"
        return 1
    fi

    success "Git submodules updated successfully"
}

install_brew_packages() {
    show_progress "Installing Homebrew packages"
    run_script "$DOTFILES_DIR/osx/brew.sh" "Installing Brew packages"
}

install_mas_apps() {
    show_progress "Installing Mac App Store apps"
    run_script "$DOTFILES_DIR/osx/mas.sh" "Installing App Store apps" true
}

install_custom_apps() {
    show_progress "Installing custom applications"
    run_script "$DOTFILES_DIR/osx/custom-installations.sh" "Installing custom scripts & apps" true
}

setup_symlinks() {
    show_progress "Creating configuration symlinks"
    local pair source target
    for pair in "${SYMLINKS_PAIRS[@]}"; do
        source="${pair%:*}"
        target="${pair#*:}"
        safe_symlink "$source" "$target"
    done
}

configure_tmux() {
    show_progress "Configuring tmux"
    run_script "$DOTFILES_DIR/config/tmux/tmux.sh" "Configuring tmux"
}

install_js_packages() {
    show_progress "Installing JavaScript packages"
    run_script "$DOTFILES_DIR/javascript/install-packages.sh" "Installing global JS packages"
}

setup_shell() {
    show_progress "Setting up shell environment"
    install_oh_my_zsh
}

configure_macos() {
    show_progress "Configuring macOS"
    run_script "$DOTFILES_DIR/osx/macos.sh" "Configuring macOS settings"

    # Run optional scripts
    local optional_scripts=(
        "$DOTFILES_DIR/osx/workarounds.sh:Applying workarounds"
        "$DOTFILES_DIR/osx/symlinks.sh:Creating additional symlinks"
        "$DOTFILES_DIR/osx/name.sh:Setting computer name"
    )

    for entry in "${optional_scripts[@]}"; do
        local script="${entry%:*}"
        local description="${entry#*:}"
        run_script "$script" "$description" true
    done
}

# Help and usage
show_help() {
    cat << 'EOF'
Dotfiles Installation Script

USAGE:
    ./install.sh [OPTIONS]

OPTIONS:
    -d, --dry-run     Show what would be done without executing
    -v, --verbose     Enable verbose output
    -s, --skip-reboot Skip reboot prompt
    -h, --help        Show this help message

EXAMPLES:
    ./install.sh                 # Run full installation
    ./install.sh --dry-run       # Preview changes
    ./install.sh -v              # Verbose installation

EOF
}

# Main function
main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -s|--skip-reboot)
                SKIP_REBOOT=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    log "Dotfiles Installation Script v$SCRIPT_VERSION"
    [[ "$DRY_RUN" == true ]] && warn "DRY RUN MODE - No changes will be made"

    # Execute installation steps
    for step_func in "${INSTALL_STEPS[@]}"; do
        if declare -f "$step_func" >/dev/null; then
            if ! "$step_func"; then
                error "Installation step failed: $step_func"
                exit 1
            fi
        else
            error "Unknown installation step: $step_func"
            exit 1
        fi
    done

    success "Installation completed successfully!"

    # Optional reboot
    if [[ "$SKIP_REBOOT" == false && "$DRY_RUN" == false ]]; then
        read -p "Reboot now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "Rebooting..."
            sudo shutdown -r now
        fi
    fi
}

# Trap for cleanup on exit
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        error "Installation failed with exit code $exit_code"
        if [[ -d "$BACKUP_DIR" ]]; then
            log "Backups available in: $BACKUP_DIR"
        fi
    fi
}

# Run main function
# Only run main if script is executed directly, not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    trap cleanup EXIT
    main "$@"
fi
