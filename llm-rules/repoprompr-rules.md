# RepoPrompt Guidelines

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
