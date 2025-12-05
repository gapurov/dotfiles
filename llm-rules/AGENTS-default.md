- MUST: We use @antfu/ni. Use `ni` to install, `nr SCRIPT_NAME` to run script, `nun` to uninstall package
- MUST: Use TypeScript interfaces over types
- MUST: Use arrow functions over function declarations
- NEVER comment unless absolutely necessary.
  - If it is a hack, such as a setTimeout or potentially confusing code, it should be prefixed with // HACK: reason for hack
- MUST: Use kebab-case for files
- MUST: Use descriptive names for variables (avoid shorthands, or 1-2 character names).
  - Example: for .map(), you can use `innerX` instead of `x`
  - Example: instead of `moved` use `didPositionChange`
- MUST: Do not type cast ("as") unless absolutely necessary
- MUST: Keep interfaces or types on the global scope.
- MUST: Remove unused code and don't repeat yourself.
- MUST: Always find, think, then implement the most _elegant_ solution.

## Tool Selection

When you need to call tools from the shell, use this rubric:

- Find files by file name: `fd`
- Find files with path name: `fd -p <file-path>`
- List files in a directory: `fd . <directory>`
- Find files with extension and pattern: `fd -e <extension> <pattern>`
- Find Text: `rg` (ripgrep)
- Find Code Structure: `ast-grep`
  - Default to TypeScript when in TS/TSX repos:
    - `.ts` → `ast-grep --lang ts -p '<pattern>'`
    - `.tsx` (React) → `ast-grep --lang tsx -p '<pattern>'`
  - Other common languages:
    - Python → `ast-grep --lang python -p '<pattern>'`
    - Bash → `ast-grep --lang bash -p '<pattern>'`
    - JavaScript → `ast-grep --lang js -p '<pattern>'`
    - Rust → `ast-grep --lang rust -p '<pattern>'`
    - JSON → `ast-grep --lang json -p '<pattern>'`
- Select among matches: pipe to `fzf`
- JSON: `jq`
- YAML/XML: `yq`

If `ast-grep` is available, avoid plain‑text searches (`rg`/`grep`) when you need syntax‑aware matching. Use `rg` only when a plain‑text search is explicitly requested.
