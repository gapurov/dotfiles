# AGENTS.md — Tool Selection (TypeScript)

- Find files by file name: `fd`
- Find files with path name: `fd -p <file-path>`
- List files in a directory: `fd . <directory>`
- Find files with extension and pattern: `fd -e <extension> <pattern>`
- Find text: `rg`
- Structured code search and codemods: `ast-grep`
  - Default languages:
    - `.ts` → `ast-grep --lang ts -p '<pattern>'`
    - `.tsx` → `ast-grep --lang tsx -p '<pattern>'`
  - Common languages:
    - Python → `ast-grep --lang python -p '<pattern>'`
    - TypeScript → `ast-grep --lang ts -p '<pattern>'`
    - TSX (React) → `ast-grep --lang tsx -p '<pattern>'`
    - JavaScript → `ast-grep --lang js -p '<pattern>'`
    - Rust → `ast-grep --lang rust -p '<pattern>'`
    - Bash → `ast-grep --lang bash -p '<pattern>'`
    - JSON → `ast-grep --lang json -p '<pattern>'`
  - Select among matches: pipe to `fzf`
  - JSON: `jq`
  - YAML/XML: `yq`

If `ast-grep` is available, avoid `rg` or `grep` unless a plain-text search is explicitly requested.

- Prefer `tsx` for fast Node execution:

### Structured search and refactors with ast-grep

* Find all exported interfaces:
  `ast-grep --lang ts -p 'export interface $I { ... }'`
* Find default exports:
  `ast-grep --lang ts -p 'export default $X'`
* Find a function call with args:
  `ast-grep --lang ts -p 'axios.get($URL, $$REST)'`
* Rename an imported specifier (codemod):
  `ast-grep --lang ts -p 'import { $Old as $Alias } from "$M"' --rewrite 'import { $Old } from "$M"' -U`
* Disallow await in Promise.all items (quick fix):
  `ast-grep --lang ts -p 'await $X' --inside 'Promise.all($_)' --rewrite '$X'`
* React hook smell: empty deps array in useEffect:
  `ast-grep --lang tsx -p 'useEffect($FN, [])'`
* List matching files then pick with fzf:
  `ast-grep --lang ts -p '<pattern>' -l | fzf -m | xargs -r sed -n '1,120p'`