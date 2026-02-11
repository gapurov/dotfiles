# AGENTS.md

Vlad owns this. Start: say hi + 1 motivating line. Work style: telegraph; noun-phrases ok; drop grammar; min tokens.

## Agent Protocol

- Contact: Vladislav Gapurov (@ired, gapurov@gmail.com).
- “Make a note” => edit AGENTS.md (shortcut; not a blocker). Ignore CLAUDE.md.
- Commits: Conventional Commits (feat|fix|refactor|build|ci|chore|docs|style|perf|test). Keep messages short and specific
- Prefer end-to-end verify; if blocked, say what’s missing.
- Web: search early; quote exact errors; prefer 2024–2025 sources
- Oracle: run bunx @steipete/oracle --help once/session before first use.
- Style: telegraph. Drop filler/grammar. Min tokens (global AGENTS + replies).

## Critical Thinking

- Fix root cause (not band-aid).
- Unsure: read more code; if still stuck, ask w/ short options.
- Conflicts: call out; pick safer path.
- Unrecognized changes: assume other agent; keep going; focus your changes. If it causes issues, stop + ask user.
- Always find, think, then implement the most _elegant_ solution.
- Leave breadcrumb notes in thread.

## Docs

- Follow links until domain makes sense; honor Read when hints.
- Keep notes short; update docs when behavior/API changes (no ship w/o docs).
- Add read_when hints on cross-cutting docs.

## Git

- Safe by default: git status/diff/log. Push only when user asks.
- Branch changes require user consent.
- Destructive ops forbidden unless explicit (reset --hard, clean, restore, rm, …).
- Don’t delete/rename unexpected stuff; stop + ask.
- No repo-wide S/R scripts; keep edits small/reviewable.
- Avoid manual git stash; if Git auto-stashes during pull/rebase, that’s fine (hint, not hard guardrail).
- No amend unless asked.

## JS/TS/TSX

- MUST: We use @antfu/ni. Use `ni` to install, `nr SCRIPT_NAME` to run script, `nun` to uninstall package
- NEVER comment unless absolutely necessary.
  - If it is a hack, such as a setTimeout or potentially confusing code, it should be prefixed with // HACK: reason for hack
- MUST: Use kebab-case for files
- MUST: Use descriptive but concise names for variables (avoid shorthands, or 1-2 character names).
- MUST: Do not type cast ("as") unless absolutely necessary

## Oracle

- Bundle prompt+files for 2nd model . Use when stuck/buggy/review.
- Default workflow here: --engine browser with GPT‑5.2 Pro in ChatGPT. This is the “human in the loop” path: it can take ~10 minutes to ~1 hour; expect a stored session you can reattach to.
- Run bunx @steipete/oracle --help once/session (before first use).
