# AST‑Grep (Structural Search & Codemods)

- What it is: `ast-grep` is a CLI for structural code search, lint, and safe rewrites using Tree‑sitter ASTs. Think “grep for ASTs,” driven by pattern‑based rules and YAML configs. Command: `sg` (aka `ast-grep`). If `sg` conflicts on your system, use `ast-grep`.

### Core Concepts

- Pattern code: write valid code snippets with meta variables to match structure, not text. Examples: `$VAR` (single node), `$$$ARGS` (zero or more nodes), `$_` (non‑capturing), `$$OP` (unnamed nodes like operators).
- Rules: YAML files combine a `rule` (find), optional `constraints` (filter), `transform` (derive strings), and `fix` (rewrite). Rewriters apply sub‑rules to lists for advanced codemods.
- Safety: interactive diffs with `-i`; apply all with `-U`. Fixes are textual templates; indentation is preserved relative to context.

### Workflow & Safety

- Preview first; never write on the first pass.
  - Ad‑hoc search: `sg run -p 'pattern' src/` (no `-r`) to confirm matches.
  - Rules scan: `sg scan` to preview findings before enabling any fixes.
- Use interactive review to confirm each hunk precisely: add `-i` (`sg run ... -i`, `sg scan -i`).
- Context lines: `-C <N>` shows N lines around matches for safer inspection.
- Only after review, apply changes: use `-U` to apply all confirmed edits.

### Quick Search

- Find console uses in TS:

  `sg run -p "console.log($ARG)" -l ts src/ -C 1`

- Print JSON matches:

  `sg run -p 'fetch($URL)' --json pretty -l ts src/`

### Ad‑Hoc Codemod

- Replace `oldFn(...)` with `newFn(...)` interactively:

  `sg run -p 'oldFn($$$ARGS)' -r 'newFn($$$ARGS)' -l ts -i src/`

- Apply without prompts once reviewed:

  `sg run -p 'oldFn($$$ARGS)' -r 'newFn($$$ARGS)' -l ts -U src/`

### Constraints (Meta Variables + Filters)

- Use constraint matches: combine meta variables ("meta/vars") with filters to tighten scope and avoid false positives.
- Common constraints: `kind`, `has`, `inside`, `not`, `any`, `all`, and metavariable‑level `regex`/`pattern`.
- Example: only match `console.log` when the message is a string literal; suggest a fix.

```yaml
id: prefer-logger-string-only
language: TypeScript
rule:
  pattern: console.log($MSG)
constraints:
  all:
    - metavariable: $MSG
      kind: string
message: Use logger.info for string messages
severity: warning
fix: logger.info($MSG)
```

### Tips for Reliable Patterns

- Patterns must be valid code for the target language; when in doubt, use object‑style rules (`kind`, `has`, `inside`, etc.).
- Meta variables are ALL‑CAPS/underscore/digits; do not embed in other tokens (e.g., `use$HOOK` won’t work). Use `constraints.regex` instead.
- Use `$_` for non‑capturing wildcards and `$$$` for lists of nodes.
- Use `--globs` to scope files; combine with `.gitignore` for noise‑free scans.
- For complex rewrites, prefer YAML `fix` + `transform`/`rewriters` over a long `--rewrite` string.

References: ast‑grep docs (Quick Start, CLI, Pattern Syntax, Lint/Rewrite/Transform/Rewriters, Project Config).
