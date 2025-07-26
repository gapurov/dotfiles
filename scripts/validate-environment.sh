#!/usr/bin/env bash

# Standalone environment validation script for dotfiles installation
# This script can be run independently to check if your system is ready for installation

set -euo pipefail

# Colors
readonly BLUE='\033[1m\033[34m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

# Logging functions
log() { echo -e "${BLUE}==> $1${NC}"; }
success() { echo -e "${GREEN}✓ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
error() { echo -e "${RED}✗ $1${NC}" >&2; }
info() { echo -e "ℹ $1"; }

# Platform detection
readonly OS_TYPE="$(uname -s)"
readonly ARCH_TYPE="$(uname -m)"

# Homebrew path detection
if [[ "$ARCH_TYPE" == "arm64" ]]; then
    readonly BREW_PREFIX="/opt/homebrew"
else
    readonly BREW_PREFIX="/usr/local"
fi

# Validation functions
validate_os() {
    log "Checking operating system..."
    if [[ "$OS_TYPE" == "Darwin" ]]; then
        success "macOS detected ($OS_TYPE)"
        info "Architecture: $ARCH_TYPE"
        info "Homebrew path: $BREW_PREFIX"
        return 0
    else
        error "This script is designed for macOS only. Detected: $OS_TYPE"
        return 1
    fi
}

validate_prerequisites() {
    log "Checking required tools..."
    local required_commands=("curl" "git" "xcode-select")
    local missing_commands=()
    local found_commands=()

    for cmd in "${required_commands[@]}"; do
        if command -v "$cmd" &>/dev/null; then
            found_commands+=("$cmd")
        else
            missing_commands+=("$cmd")
        fi
    done

    # Report found commands
    for cmd in "${found_commands[@]}"; do
        success "$cmd found at $(command -v "$cmd")"
    done

    # Report missing commands
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        error "Missing required commands: ${missing_commands[*]}"
        info "Please install Xcode Command Line Tools: xcode-select --install"
        return 1
    fi

    return 0
}

validate_xcode_tools() {
    log "Checking Xcode Command Line Tools..."
    if xcode-select -p &>/dev/null; then
        local xcode_path
        xcode_path="$(xcode-select -p)"
        success "Xcode Command Line Tools installed at: $xcode_path"
    else
        error "Xcode Command Line Tools not found"
        info "Install with: xcode-select --install"
        return 1
    fi
}

validate_network() {
    log "Checking network connectivity..."
    local test_urls=(
        "https://github.com"
        "https://raw.githubusercontent.com"
        "https://api.github.com"
    )

    for url in "${test_urls[@]}"; do
        if curl -s --connect-timeout 5 "$url" &>/dev/null; then
            success "Connection to $url: OK"
        else
            error "Cannot reach $url"
            return 1
        fi
    done
}

validate_permissions() {
    log "Checking directory permissions..."
    local test_dirs=("$HOME" "$HOME/.config")

    for dir in "${test_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir" 2>/dev/null || {
                error "Cannot create directory: $dir"
                return 1
            }
        fi

        if [[ -w "$dir" ]]; then
            success "Write access to $dir: OK"
        else
            error "No write permission to $dir"
            return 1
        fi
    done
}

check_homebrew() {
    log "Checking Homebrew installation..."
    if command -v brew &>/dev/null; then
        local brew_path
        brew_path="$(command -v brew)"
        success "Homebrew found at: $brew_path"

        # Check if it's in the expected location for the architecture
        if [[ "$brew_path" =~ ^$BREW_PREFIX ]]; then
            success "Homebrew location correct for $ARCH_TYPE architecture"
        else
            warn "Homebrew location ($brew_path) may not be optimal for $ARCH_TYPE"
            info "Expected location: $BREW_PREFIX/bin/brew"
        fi

        # Check Homebrew health
        info "Running brew doctor..."
        if brew doctor &>/dev/null; then
            success "Homebrew health check passed"
        else
            warn "Homebrew doctor found issues (may not be critical)"
        fi
    else
        warn "Homebrew not found - will be installed during setup"
        info "Will install to: $BREW_PREFIX"
    fi
}

check_shell() {
    log "Checking shell environment..."
    success "Current shell: $SHELL"

    if [[ -f "$HOME/.zshrc" ]]; then
        info "Existing .zshrc found - will be backed up"
    else
        info "No existing .zshrc found"
    fi

    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        success "Oh My Zsh already installed"
    else
        info "Oh My Zsh will be installed"
    fi
}

check_dotfiles() {
    log "Checking dotfiles repository..."
    local dotfiles_dir="$HOME/.dotfiles"

    if [[ -d "$dotfiles_dir" ]]; then
        success "Dotfiles directory found: $dotfiles_dir"

        if [[ -d "$dotfiles_dir/.git" ]]; then
            success "Git repository detected"

            # Check if we can get git status
            if git -C "$dotfiles_dir" status &>/dev/null; then
                local branch
                branch="$(git -C "$dotfiles_dir" branch --show-current)"
                info "Current branch: $branch"
            fi
        else
            warn "Not a git repository"
        fi

        # Check for key files
        local key_files=(
            "install.sh"
            "osx/brew.sh"
            "config/tmux/tmux.sh"
            "javascript/install-packages.sh"
        )

        for file in "${key_files[@]}"; do
            if [[ -f "$dotfiles_dir/$file" ]]; then
                success "Found: $file"
            else
                error "Missing: $file"
            fi
        done
    else
        error "Dotfiles directory not found: $dotfiles_dir"
        info "Please clone your dotfiles repository to $dotfiles_dir"
        return 1
    fi
}

show_summary() {
    echo
    log "Environment Validation Summary"
    echo "================================"
    info "OS: $OS_TYPE ($ARCH_TYPE)"
    info "Homebrew prefix: $BREW_PREFIX"
    info "Shell: $SHELL"
    info "Dotfiles: $HOME/.dotfiles"
    echo
}

show_help() {
    cat << 'EOF'
Environment Validation Script

This script checks if your system is ready for dotfiles installation.

USAGE:
    ./scripts/validate-environment.sh [OPTIONS]

OPTIONS:
    -q, --quiet       Only show errors and warnings
    -v, --verbose     Show detailed information
    -h, --help        Show this help message

CHECKS PERFORMED:
    ✓ Operating system compatibility
    ✓ Required tools (curl, git, xcode-select)
    ✓ Xcode Command Line Tools
    ✓ Network connectivity
    ✓ Directory permissions
    ✓ Homebrew installation
    ✓ Shell environment
    ✓ Dotfiles repository structure

EOF
}

main() {
    local quiet=false
    local verbose=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -q|--quiet)
                quiet=true
                shift
                ;;
            -v|--verbose)
                verbose=true
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

    [[ "$quiet" == false ]] && log "Starting environment validation..."

    local failed_checks=0

    # Run all validation checks
    validate_os || ((failed_checks++))
    validate_prerequisites || ((failed_checks++))
    validate_xcode_tools || ((failed_checks++))
    validate_network || ((failed_checks++))
    validate_permissions || ((failed_checks++))
    check_homebrew
    check_shell
    check_dotfiles || ((failed_checks++))

    [[ "$quiet" == false ]] && show_summary

    if [[ $failed_checks -eq 0 ]]; then
        success "All validation checks passed! 🎉"
        info "Your system is ready for dotfiles installation."
        [[ "$quiet" == false ]] && info "Run: ./install.sh --dry-run to preview the installation"
        exit 0
    else
        error "$failed_checks validation check(s) failed"
        info "Please resolve the issues above before running the installation."
        exit 1
    fi
}

main "$@"
