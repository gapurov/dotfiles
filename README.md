# Dotfiles

Personal macOS configuration and setup automation. This repository contains dotfiles, system configurations, and automated installation scripts for a complete development environment setup.

## Quick Start

### One-Line Remote Installation

```bash

curl -fsSL https://raw.githubusercontent.com/gapurov/dotfiles/master/remote-install.sh | bash
```

### Preview installation without making changes

```bash
curl -fsSL https://raw.githubusercontent.com/gapurov/dotfiles/master/remote-install.sh | bash -s -- --dry-run
```

### Manual Installation

Option A — fresh clone with submodules (recommended):

```bash
# Clone the repo and all submodules
git clone --recurse-submodules https://github.com/gapurov/dotfiles ~/.dotfiles
cd ~/.dotfiles

# Optional: faster shallow clone for main repo and submodules
# git clone --recurse-submodules --depth 1 --shallow-submodules \
#   https://github.com/gapurov/dotfiles ~/.dotfiles

# Run the installer
chmod +x install.sh
./install.sh --dry-run     # preview
./install.sh               # apply
./install.sh -v            # verbose
```

### Execution Order

- Initialization steps (`INIT`) are processed first for setup like sudo management
- Links are processed next, in the exact order they appear in `LINKS`
- Finally, installation steps (`STEPS`) are executed in order
- Comments (`# ...`) and empty entries are ignored in all arrays
- Link targets: missing parent directories are created; existing correct symlinks are left as-is; existing files/dirs are backed up before replacement
- Steps run from the repository root; if a timeout utility is available (`timeout`/`gtimeout`), each step is limited to 5 minutes

## Installation Script

The `install.sh` script is a small, declarative runner. It reads `install.conf.sh` and then:

- Runs initialization steps defined in `INIT` (for setup like sudo management)
- Creates symlinks defined in `LINKS`
- Executes commands defined in `STEPS`
- Makes timestamped backups of any files it replaces
- Prints a summary on exit

### Command Line

```bash
./install.sh [OPTIONS]

OPTIONS:
    -d, --dry-run       Show what would be done without executing
    -v, --verbose       Enable verbose output with debug information
    -h, --help          Show help message

EXAMPLES:
    ./install.sh                 # Run full installation
    ./install.sh --dry-run       # Preview without changes
    ./install.sh -v              # Verbose output
    ./install.sh --dry-run -v    # Preview with verbose output
```

## Configuration: install.conf.sh

Declare your setup in a single file. Three arrays are supported: `INIT`, `LINKS`, and `STEPS`.

```bash
# install.conf.sh

# Initialization steps (run first, can set environment variables)
# - Executed in current shell to preserve environment changes
# - Perfect for sudo management, environment setup
# - Lines starting with # are comments and are ignored
INIT=(
  "./scripts/sudo-helper.sh init"
  # Add other initialization tasks here
)

# Create symlinks: "source:target" (first colon splits the pair)
# - `~` is supported in targets
# - Missing target directories are created
# - Lines starting with # are comments and are ignored
LINKS=(
  "git/gitconfig:~/.gitconfig"
  "git/gitignore:~/.gitignore"
  "zsh/zshrc.zsh:~/.zshrc"
  "config/karabiner/karabiner.json:~/.config/karabiner/karabiner.json"
)

# Run commands from the repo root, in order
# - Lines starting with # are comments and are ignored
# - Use `|| true` on non-critical steps
STEPS=(
  "git submodule update --init --recursive"
  "./osx/brew.sh"
  "./config/tmux/tmux.sh"
  # "./osx/macos.sh || true"
)
```

## Idempotency and Safety

- Symlinks: existing correct links are left untouched
- Backups: any replaced file is copied to `~/.dotfiles-backup-YYYYMMDD-HHMMSS/` preserving its full path
- Directories: target directories are created automatically
- Dry runs: preview everything with `--dry-run`
- Summary: a single summary is always printed on exit
- Exit codes: nonzero on failure; safe to re-run after fixing issues

That's it. Keep `install.conf.sh` as the source of truth and re-run `./install.sh` anytime.
