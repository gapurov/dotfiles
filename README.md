# Dotfiles

Personal macOS configuration and setup automation. This repository contains dotfiles, system configurations, and automated installation scripts for a complete development environment setup.

## Quick Start

### One-Line Remote Installation

```bash
# Automatic installation (recommended)
curl -fsSL https://raw.githubusercontent.com/gapurov/dotfiles/master/remote-install.sh | bash

# Preview installation without making changes
curl -fsSL https://raw.githubusercontent.com/gapurov/dotfiles/master/remote-install.sh | bash -s -- --dry-run

# Install with verbose output
curl -fsSL https://raw.githubusercontent.com/gapurov/dotfiles/master/remote-install.sh | bash -s -- --verbose
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

Option B — if already cloned without submodules:

```bash
cd ~/.dotfiles

# Sync and initialize submodules
git submodule sync --recursive
git submodule update --init --recursive --jobs 8

# Optional: shallow-fetch submodules for speed
# git submodule update --init --recursive --jobs 8 --depth 1

# Optional: move submodules to latest remote tracking branch
# git submodule update --remote --recursive --jobs 8

# Run the installer
chmod +x install.sh
./install.sh --dry-run
./install.sh
```

### Execution Order

- Links are processed first, in the exact order they appear in `LINKS`.
- After all links are processed, steps are executed in the exact order they appear in `STEPS`.
- Comments (`# ...`) and empty entries are ignored in both arrays.
- Link targets: missing parent directories are created; existing correct symlinks are left as-is; existing files/dirs are backed up before replacement.
- Steps run from the repository root; if a timeout utility is available (`timeout`/`gtimeout`), each step is limited to 5 minutes.

## Installation Script

The `install.sh` script is a small, declarative runner. It reads `install.conf.sh` and then:

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

Declare your setup in a single file. Two arrays are supported: `LINKS` and `STEPS`.

```bash
# install.conf.sh

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
