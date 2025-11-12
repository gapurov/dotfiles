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

## Tool Selection

When you need to call tools from the shell, use this rubric:

- Find files by file name: `fd`
- Find files with path name: `fd -p <file-path>`
- List files in a directory: `fd . <directory>`
- Find files with extension and pattern: `fd -e <extension> <pattern>`
- Find text: `rg` (ripgrep)
- Structured code search: `ast-grep`
  - Default to TypeScript:
    - `.ts` → `ast-grep --lang ts -p '<pattern>'`
    - `.tsx` (React) → `ast-grep --lang tsx -p '<pattern>'`
  - Common languages:
    - Bash → `ast-grep --lang bash -p '<pattern>'`
    - Python → `ast-grep --lang python -p '<pattern>'`
    - TypeScript → `ast-grep --lang ts -p '<pattern>'`
    - TSX (React) → `ast-grep --lang tsx -p '<pattern>'`
    - JavaScript → `ast-grep --lang js -p '<pattern>'`
    - Rust → `ast-grep --lang rust -p '<pattern>'`
    - JSON → `ast-grep --lang json -p '<pattern>'`
  - For other languages, set `--lang` appropriately.
- Select among matches: pipe to `fzf`
- JSON: `jq`
- YAML/XML: `yq`

If `ast-grep` is available, avoid `rg` or `grep` unless a plain-text search is explicitly requested.

---

## Bash / Shell

Default to Bash. For `.sh` files or scripts with a `bash` shebang, assume Bash; for pure POSIX `sh`, adjust flags accordingly.

- Lint (static analysis): `shellcheck`

  - Single file (follow sourced files): `shellcheck -x path/to/script.sh`
  - Many by extension: `fd -e sh -e bash -t f | xargs -r shellcheck -x`
  - Many by shebang: `rg -l '^\s*#!.*\b(bash|sh)\b' | fzf -m | xargs -r shellcheck -x`
  - Severity: `-S warning` or `-S style`
  - Exclude rules sparingly: `-e SC1091,SC2086` (prefer file-local disables: `# shellcheck disable=SC2086`)

- Format: `shfmt`

  - Check (diff only): `shfmt -d -i 2 -ci -sr .`
  - Write changes: `shfmt -w -i 2 -ci -sr .`
  - Bash dialect when needed: `shfmt -ln=bash -w -i 2 -ci -sr .`

- Test: `bats` (Bats-core)
  - Run all tests: `bats -r test/`
  - Pick a test via fzf: `fd -e bats test | fzf | xargs -r bats`
  - Minimal test template:
    ```bash
    # test/my_script.bats
    @test "prints help" {
      run ./my_script.sh -h
      [ "$status" -eq 0 ]
      [[ "$output" == *"Usage:"* ]]
    }
    ```

### CI one-liners

- Lint: `fd -e sh -e bash -t f | xargs -r shellcheck -S warning -x`
- Format check: `shfmt -d -i 2 -ci -sr .`
- Tests: `bats -r test/`
