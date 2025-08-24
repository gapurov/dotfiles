#!/bin/bash
# Tools checker for macOS dotfiles installation
# Simplified macOS/Homebrew-only version

set -euo pipefail

# Configuration
readonly SCRIPT_VERSION="3.0.0"
VERBOSE=${VERBOSE:-false}
AUTO_INSTALL=${AUTO_INSTALL:-false}
NON_INTERACTIVE=${NON_INTERACTIVE:-false}
INSTALL_PACKAGES=${INSTALL_PACKAGES:-false}

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly GRAY='\033[0;90m'
readonly NC='\033[0m' # No Color

# Logging functions
log() { printf "%b==> %s%b\n" "$BLUE" "$1" "$NC"; }
success() { printf "%b✓ %s%b\n" "$GREEN" "$1" "$NC"; }
warn() { printf "%b⚠ %s%b\n" "$YELLOW" "$1" "$NC"; }
error() { printf "%b✗ %s%b\n" "$RED" "$1" "$NC" >&2; }
info() { printf "%b  %s%b\n" "$GRAY" "$1" "$NC"; }
debug() { [[ "$VERBOSE" == true ]] && printf "%b[DEBUG] %s%b\n" "$GRAY" "$1" "$NC" >&2 || true; }

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install Homebrew if not present
install_homebrew() {
    log "Homebrew not found. Installing..."
    if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
        # Add Homebrew to PATH for this session
        eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)"
        success "Homebrew installed successfully"
        return 0
    else
        error "Failed to install Homebrew"
        return 1
    fi
}

# Function to install tools using Homebrew
install_tool() {
    local tool="$1"

    debug "Installing $tool using Homebrew"

    if brew install "$tool"; then
        return 0
    else
        error "Failed to install $tool via Homebrew"
        return 1
    fi
}


# Function to install packages using brew.sh
install_packages() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local brew_script="$script_dir/brew.sh"

    if [[ ! -f "$brew_script" ]]; then
        error "brew.sh script not found at: $brew_script"
        return 1
    fi

    if ! command_exists "brew"; then
        error "Homebrew is required but not installed"
        return 1
    fi

    log "Installing packages via brew.sh..."
    info "This will install comprehensive development tools and applications"

    if [[ "$NON_INTERACTIVE" != true ]] && [[ "$AUTO_INSTALL" != true ]]; then
        printf "%bProceed with package installation? [y/N]: %b" "$YELLOW" "$NC"
        read -r response
        case "$response" in
            [yY][eE][sS]|[yY])
                ;;
            *)
                info "Skipping package installation"
                return 0
                ;;
        esac
    fi

    if bash "$brew_script"; then
        success "Package installation completed successfully"
    else
        error "Package installation failed"
        return 1
    fi
}

# Function to ask user for installation permission
ask_install() {
    local tool="$1"

    if [[ "$NON_INTERACTIVE" == true ]] || [[ "$AUTO_INSTALL" == true ]]; then
        return 0
    fi

    printf "%bInstall %s? [y/N]: %b" "$YELLOW" "$tool" "$NC"
    read -r response
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to show usage
show_help() {
    cat << 'EOF'
Tools Checker for macOS Dotfiles

USAGE:
    ./check-tools.sh [OPTIONS]

OPTIONS:
    --auto-install        Automatically install missing tools without prompting
    --install-packages    Install comprehensive development packages via brew.sh
    --non-interactive     Don't prompt for user input (useful for CI/CD)
    --verbose            Enable verbose output
    --help               Show this help message

ENVIRONMENT VARIABLES:
    AUTO_INSTALL=true     Same as --auto-install
    INSTALL_PACKAGES=true Same as --install-packages
    NON_INTERACTIVE=true  Same as --non-interactive
    VERBOSE=true          Same as --verbose

EXAMPLES:
    ./check-tools.sh                    # Check tools and prompt for installation
    ./check-tools.sh --auto-install     # Check and auto-install missing tools
    ./check-tools.sh --install-packages # Check tools + install brew.sh packages
    ./check-tools.sh --auto-install --install-packages # Full automated setup

NOTES:
    macOS-only script that ensures these tools are installed:
    - brew, git, curl, bash, jq, mas, zsh

    Homebrew will be auto-installed if missing.
    Use --install-packages for comprehensive development environment setup.

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --auto-install)
            AUTO_INSTALL=true
            shift
            ;;
        --non-interactive)
            NON_INTERACTIVE=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --install-packages)
            INSTALL_PACKAGES=true
            shift
            ;;
        --help)
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

# Main execution starts here
log "Tools Checker v$SCRIPT_VERSION (macOS)"

# Verify we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    error "This script is designed for macOS only"
    exit 1
fi

success "Running on macOS"

# Define tools for dotfiles installation
TOOLS="brew git curl bash jq mas zsh"

# Track results
missing_tools=()
failed_installs=()

# Function to check and install tools (essential + optional development)
check_and_install_tools() {
    log "Checking required tools for dotfiles installation..."

    # Ensure Homebrew availability first
    local brew_available=false
    if command_exists "brew"; then
        success "brew is installed"
        brew_available=true
    else
        warn "brew is missing"
        if ask_install "brew"; then
            if install_homebrew && command_exists "brew"; then
                success "brew installed successfully"
                brew_available=true
                # Don't add to missing_tools since it was installed successfully
            else
                error "Failed to install brew"
                missing_tools+=("brew")
                failed_installs+=("brew")
            fi
        else
            info "Skipping installation of brew"
            missing_tools+=("brew")
        fi
    fi

    # Determine tools to check
    local tools_to_check
    tools_to_check="${*:-$TOOLS}"

    # Check remaining tools (excluding brew)
    for tool in $tools_to_check; do
        if [[ "$tool" == "brew" ]]; then
            continue
        fi

        if command_exists "$tool"; then
            success "$tool is installed"
            continue
        fi

        warn "$tool is missing"
        missing_tools+=("$tool")

        if [[ "$brew_available" != true ]]; then
            warn "Homebrew required to install $tool but not available"
            failed_installs+=("$tool")
            continue
        fi

        if ask_install "$tool"; then
            info "Installing $tool..."
            if install_tool "$tool" && command_exists "$tool"; then
                success "$tool installed successfully"
            else
                error "$tool installation failed or command not found after install"
                failed_installs+=("$tool")
            fi
        else
            info "Skipping installation of $tool"
        fi
    done
}

# Check tools once
check_and_install_tools $TOOLS

# Install packages if requested
if [[ "$INSTALL_PACKAGES" == true ]]; then
    echo ""
    install_packages
fi

# Final report
echo ""
log "Installation Summary"

# Count tools
total_tools=0
installed_tools=0

for tool in $TOOLS; do
    total_tools=$((total_tools + 1))
    if command_exists "$tool"; then
        installed_tools=$((installed_tools + 1))
    fi
done

success "$installed_tools/$total_tools tools are installed"

# Report missing essential tools
if [[ ${#missing_tools[@]} -gt 0 ]]; then
    error "Missing tools: ${missing_tools[*]}"
    info "These tools are required for dotfiles installation"
fi

# Report failed installations
if [[ ${#failed_installs[@]} -gt 0 ]]; then
    error "Failed to install: ${failed_installs[*]}"
    info "Check the error messages above and try manual installation"
fi

# Show next steps
if [[ ${#missing_tools[@]} -gt 0 ]]; then
    echo ""
    log "Next Steps"
    info "Run this script again with --auto-install to install missing tools automatically"
    info "Or install tools manually using the instructions provided above"
elif [[ "$INSTALL_PACKAGES" != true ]]; then
    echo ""
    log "Optional: Install Additional Packages"
    info "Run with --install-packages to install comprehensive development tools via brew.sh"
    info "Example: ./check-tools.sh --install-packages"
fi

# Exit with appropriate code
if [[ ${#missing_essential[@]} -gt 0 ]]; then
    exit 1
else
    exit 0
fi
