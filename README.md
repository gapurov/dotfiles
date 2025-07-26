# 🏠 Dotfiles

Personal macOS configuration and setup automation. This repository contains dotfiles, system configurations, and automated installation scripts for a complete development environment setup.

## 📦 Quick Start

```bash
# Clone the repository
git clone https://github.com/gapurov/dotfiles ~/.dotfiles && cd ~/.dotfiles

# Validate your system (recommended)
./scripts/validate-environment.sh

# Preview what will be installed
./install.sh --dry-run

# Run the installation
./install.sh
```

## 🛠️ Installation Script

The enhanced `install.sh` script provides a robust, idempotent installation system with comprehensive error handling and user-friendly features.

### ✨ Features

- **🔍 Environment Validation**: Checks system compatibility before installation
- **🏗️ Idempotent Operations**: Safe to run multiple times
- **📊 Progress Tracking**: Visual progress indicators with percentage completion
- **🔄 Backup System**: Automatically backs up existing configuration files
- **🎛️ Multiple Modes**: Dry-run, verbose, and automated execution options
- **🌐 Network Validation**: Ensures connectivity to required services
- **🏗️ Architecture Support**: Intel and Apple Silicon Mac compatibility
- **⚠️ Error Recovery**: Detailed error messages with backup file locations

### 📋 Command Line Options

```bash
./install.sh [OPTIONS]

OPTIONS:
    -d, --dry-run     Show what would be done without executing
    -v, --verbose     Enable verbose output with debug information
    -s, --skip-reboot Skip reboot prompt for automation
    -h, --help        Show help message with examples

EXAMPLES:
    ./install.sh                 # Run full installation
    ./install.sh --dry-run       # Preview changes without executing
    ./install.sh --verbose       # Detailed installation with debug info
    ./install.sh --skip-reboot   # Silent installation for automation
```

### 🔍 Pre-Installation Validation

Use the environment validation script to check system readiness:

```bash
# Comprehensive system check
./scripts/validate-environment.sh

# Quiet mode (errors/warnings only)
./scripts/validate-environment.sh --quiet

# Verbose mode with detailed information
./scripts/validate-environment.sh --verbose
```

**Validation Checks:**

- ✅ Operating system compatibility (macOS)
- ✅ Required tools (curl, git, xcode-select)
- ✅ Xcode Command Line Tools installation
- ✅ Network connectivity to GitHub
- ✅ Directory write permissions
- ✅ Homebrew installation and health
- ✅ Shell environment configuration
- ✅ Dotfiles repository structure

## 📁 What Gets Installed

### 🍺 Homebrew Packages

- **Development Tools**: git, vim, tmux, node, deno, python
- **CLI Utilities**: fzf, ripgrep, bat, fd, jq, htop, tree
- **Applications**: iTerm2, Visual Studio Code, Cursor, Raycast, 1Password

### 🏪 Mac App Store Apps

- Bear (Notes)
- Things 3 (Task Management)
- Xcode (Development)
- Amphetamine (Keep Awake)
- Session (Pomodoro Timer)

### ⚙️ Configuration Files

| Source                  | Target                               | Description               |
| ----------------------- | ------------------------------------ | ------------------------- |
| `git/gitconfig`         | `~/.gitconfig`                       | Git global configuration  |
| `git/gitignore`         | `~/.gitignore`                       | Global gitignore patterns |
| `zsh/zshrc.zsh`         | `~/.zshrc`                           | Zsh shell configuration   |
| `config/karabiner.json` | `~/.config/karabiner/karabiner.json` | Keyboard remapping        |
| `javascript/npmrc`      | `~/.npmrc`                           | npm configuration         |

### 🐚 Shell Environment

- **Oh My Zsh**: Enhanced Zsh framework
- **Plugins**: tmux, macos, fzf, zoxide, git integration
- **Custom Functions**: Personal productivity scripts
- **Node Version Management**: fnm for Node.js versions

## 🔧 Installation Process

The installation follows a systematic 10-step process:

1. **Environment Validation** - System compatibility checks
2. **Homebrew Installation** - Package manager setup
3. **Homebrew Packages** - CLI tools and development packages
4. **Mac App Store Apps** - Essential applications via `mas`
5. **Custom Applications** - Additional software and utilities
6. **Configuration Symlinks** - Link dotfiles to home directory
7. **Tmux Configuration** - Terminal multiplexer setup
8. **JavaScript Packages** - Global npm/bun packages
9. **Shell Environment** - Zsh and Oh My Zsh configuration
10. **macOS Settings** - System preferences and optimizations

## 🛡️ Safety Features

### 🔄 Idempotent Design

- Checks if tools are already installed before attempting installation
- Won't overwrite correctly configured symlinks
- Prevents duplicate entries in shell profiles

### 💾 Backup System

```bash
# Backups are created at:
~/.dotfiles-backup-YYYYMMDD-HHMMSS/

# Contains original files that were replaced
# Backup location is shown if installation fails
```

### 🎯 Smart Symlinks

- Validates source files exist before linking
- Creates necessary directories automatically
- Backs up existing files before replacement
- Won't break existing valid symlinks

## 📊 Example Output

### Dry Run Mode

```bash
$ ./install.sh --dry-run

==> Dotfiles Installation Script v2.0.0
⚠ DRY RUN MODE - No changes will be made
==> Progress: [1/10] (10%) - Validating environment
✓ Environment validation complete
✓ Homebrew already installed at /opt/homebrew/bin/brew
==> Progress: [2/10] (20%) - Installing Homebrew packages
==> DRY RUN: Would run /Users/user/.dotfiles/osx/brew.sh (Installing Brew packages)
==> Progress: [3/10] (30%) - Installing Mac App Store apps
==> DRY RUN: Would run /Users/user/.dotfiles/osx/mas.sh (Installing App Store apps)
...
✓ Installation completed successfully!
```

### Verbose Mode

```bash
$ ./install.sh --verbose

==> Dotfiles Installation Script v2.0.0
==> Progress: [1/10] (10%) - Validating environment
DEBUG: Starting OS validation
DEBUG: Starting prerequisites validation
DEBUG: Starting network validation
DEBUG: Starting permissions validation
✓ Environment validation complete
...
```

## 🚨 Troubleshooting

### Common Issues

**Missing Xcode Command Line Tools**

```bash
xcode-select --install
```

**Network Connectivity Issues**

```bash
# Test GitHub connectivity
curl -s https://github.com

# Check DNS resolution
nslookup github.com
```

**Permission Errors**

```bash
# Check directory permissions
ls -la ~ ~/.config

# Fix permissions if needed
chmod 755 ~ ~/.config
```

**Homebrew Issues**

```bash
# Run Homebrew doctor
brew doctor

# Update Homebrew
brew update && brew upgrade
```

### Recovery

If installation fails:

1. **Check Error Messages**: Look for specific error details
2. **Review Backups**: Restore from `~/.dotfiles-backup-*` if needed
3. **Validate Environment**: Run `./scripts/validate-environment.sh`
4. **Partial Retry**: Use `--dry-run` to see what needs to be done
5. **Clean Restart**: Remove problematic installations and retry

## 🔧 Customization

### Adding New Packages

**Homebrew packages** - Edit `osx/brew.sh`:

```bash
brew install your-package
```

**Mac App Store apps** - Edit `osx/mas.sh`:

```bash
mas install APP_ID  # Find ID with: mas search "App Name"
```

**Symlinks** - Modify `install.sh` SYMLINKS array:

```bash
SYMLINKS["source/file"]="target/location"
```

### Configuration

All configuration is centralized at the top of `install.sh`:

```bash
readonly DOTFILES_DIR="$HOME/.dotfiles"
readonly BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
```

## 📚 Scripts Overview

### Core Scripts

- `install.sh` - Main installation orchestrator
- `scripts/validate-environment.sh` - System validation utility

### Configuration Scripts

- `osx/brew.sh` - Homebrew package installation
- `osx/mas.sh` - Mac App Store applications
- `osx/macos.sh` - macOS system preferences
- `config/tmux/tmux.sh` - Tmux configuration setup
- `javascript/install-packages.sh` - Node.js global packages

### Maintenance Scripts

- `scripts/autopush-obsidian.sh` - Automated Obsidian sync
- `scripts/clear_js_dev_packages.sh` - Clean development packages

## 🎯 Best Practices

1. **Always validate first**: Run `./scripts/validate-environment.sh`
2. **Preview changes**: Use `--dry-run` before actual installation
3. **Keep backups**: Don't delete backup directories immediately
4. **Regular updates**: Pull latest changes before running
5. **Customize carefully**: Test changes in a safe environment

## ⚠️ Disclaimer

**Use at your own risk**: Review all scripts before execution. This setup is tailored for specific workflows and may require customization for your needs.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
