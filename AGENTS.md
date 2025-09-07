# Repository Guidelines

This guide orients contributors and agents working in this macOS-focused Bash dotfiles repo. Keep changes minimal, scoped, and consistent with the conventions below.

## Project Structure & Module Organization

- `install.sh`: Entrypoint. Symlinks dotfiles and runs steps from `install.conf.sh`.
- `install.conf.sh`: Declarative source of truth.
  - `LINKS` entries are "source:target".
  - `STEPS` entries are commands run from repo root.
- `git/`, `zsh/`, `config/`, `osx/`: Source configs that become symlinks (e.g., `git/gitconfig -> ~/.gitconfig`).
- `scripts/`: Utility scripts; `scripts/tests/`: script-specific integration tests.
- `tests/`: End-to-end installer tests.

Example (edit here, not in home directory):

```bash
LINKS=(
  "git/gitconfig:~/.gitconfig"
  "zsh/zshrc.zsh:~/.zshrc"
)
STEPS=("git submodule update --init --recursive" "./osx/brew.sh")
```

## Build, Test, and Development Commands

- Run installer: `./install.sh` (use `--dry-run` to preview, `-v` for debug).
- Update submodules: `git submodule update --init --recursive`.
- Validate environment (macOS prereqs): `./scripts/validate-environment.sh`.
- E2E test: `./tests/install.test.sh`.
- Script tests: `./scripts/tests/*.test.sh`.

## RepoPrompt Tooling (Use These First)

- `get_file_tree type="code_structure"`: quick project map.
- `get_code_structure paths=["RepoPrompt/Services", "RepoPrompt/Models"]`: directory-first overview; prefer directories before individual files.
- `file_search pattern="SystemPromptService" regex=false`: locate symbols fast.
- `read_file path="…" start_line=1 limit=120`: read in small chunks.
- `manage_selection action="list|replace"`: actively curate the working set; keep under ~80k tokens.
- `apply_edits` and `file_actions`: make precise edits or create/move files.
- `update_plan`: keep short, verifiable steps with one `in_progress` item.
- `chat_send mode=plan|chat|edit`: planning discussion or second-opinion review.

## MCP Flows & Hotwords

- [DISCOVER]: Use Discover flow to curate context and craft handoff.
  `workspace_context` → `get_file_tree` → directory `get_code_structure` → `file_search` → targeted `read_file` → `manage_selection replace` → `prompt op="set"`.
- [AGENT]: Autonomous edit flow; favor RepoPrompt tools for navigation, reads, and edits.
  - Steps: start with [DISCOVER] if context is unclear; then `apply_edits`/`file_actions` with tight diffs.
- [PAIR]: Collaborative flow; discuss plan, then implement iteratively.
  - Use `chat_send mode=plan` to validate approach; then small, reversible edits.
- Complex or high-risk tasks: trigger a [SECOND OPINION] via `chat_send mode=plan` before applying broad changes.

## Coding Style & Naming Conventions

- Language: Bash. Start scripts with `#!/usr/bin/env bash` and `set -euo pipefail`.
- Indentation: 4 spaces. Functions: `lower_snake_case`. Files: `kebab-case.sh`.
- Constants: `readonly UPPER_SNAKE`; use local temps; prefer `[[ ... ]]` and `$(...)`.
- Logging: use `log`, `success`, `warn`, `error`, `info`, `debug` helpers from `install.sh`.

## Testing Guidelines

- Tests are Bash scripts; keep hermetic using `mktemp -d` and clean up.
- Naming: `*.test.sh`. Place installer-wide tests in `tests/`, script-specific in `scripts/tests/`.
- Ensure exit code 0 on success; cover happy path, timeouts, and error handling.

## Commit & Pull Request Guidelines

- Use Conventional Commits (e.g., `feat: add tmux to install.conf.sh`, `refactor: streamline install.sh`).
- PRs should include a concise summary, rationale, output from `./install.sh --dry-run -v` (or relevant script), linked issues, and risk/rollback notes.

## Security & Configuration Tips

- Safe by default: installer creates timestamped backups in `~/.dotfiles-backup-YYYYMMDD-HHMMSS/` before replacing files.
- Prefer dry runs and `./scripts/validate-environment.sh` before applying changes.
- Treat `install.conf.sh` as the source of truth; edit `LINKS`/`STEPS` there.
