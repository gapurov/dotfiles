# Repository Guidelines

## Project Structure & Module Organization
- `install.sh`: Bash entrypoint that symlinks dotfiles and runs steps from `install.conf.sh`.
- `install.conf.sh`: Declarative arrays: `LINKS` ("source:target") and `STEPS` (commands run from repo root).
- `git/`, `zsh/`, `config/`, `osx/`: Source configs that become symlinks (e.g., `git/gitconfig -> ~/.gitconfig`).
- `scripts/`: Utility scripts (kebab-case) and `scripts/tests/` integration tests.
- `tests/`: End-to-end installer test (`install.test.sh`).

## Build, Test, and Development Commands
- Run installer: `./install.sh` (use `--dry-run` to preview, `-v` for debug).
- Update submodules: `git submodule update --init --recursive`.
- Validate env (macOS prerequisites): `./scripts/validate-environment.sh`.
- Run tests:
  - Installer E2E: `./tests/install.test.sh`
  - Script tests: `./scripts/tests/*.test.sh`

## Coding Style & Naming Conventions
- Language: Bash (macOS). Start scripts with `#!/usr/bin/env bash` and `set -euo pipefail`.
- Indentation: 4 spaces; functions `lower_snake_case`; files `kebab-case.sh`.
- Constants: `readonly UPPER_SNAKE`; temporary vars local; prefer `[[ ... ]]` and `$(...)`.
- Logging helpers: `log/success/warn/error/info/debug` (see `install.sh`).

## Testing Guidelines
- Tests are bash scripts; keep hermetic by using temp dirs (`mktemp -d`) and cleaning up.
- Naming: `*.test.sh`. Place installer-wide tests in `tests/`, script-specific in `scripts/tests/`.
- Run locally and ensure exit code 0. Aim to cover happy path, timeouts, and error handling.

## Commit & Pull Request Guidelines
- Commit style: Conventional Commits (e.g., `feat: add tmux to install.conf.sh`, `refactor: streamline install.sh`).
- PRs should include:
  - Summary of changes and rationale.
  - Output from `./install.sh --dry-run -v` (or relevant script) and any screenshots if UI-related.
  - Linked issues and notes on risk/rollback.

## Security & Configuration Tips
- Safe by default: installer creates timestamped backups in `~/.dotfiles-backup-YYYYMMDD-HHMMSS/` before replacing files.
- Prefer dry runs and `./scripts/validate-environment.sh` before applying changes.
- `install.conf.sh` is the source of truth—edit `LINKS`/`STEPS` there. Example:
  ```bash
  LINKS=(
    "git/gitconfig:~/.gitconfig"
    "zsh/zshrc.zsh:~/.zshrc"
  )
  STEPS=("git submodule update --init --recursive" "./osx/brew.sh")
  ```
