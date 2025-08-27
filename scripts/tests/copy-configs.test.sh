#!/usr/bin/env bash
set -euo pipefail

# Hermetic tests for scripts/copy-configs/copy-configs.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COPY_SCRIPT="$REPO_ROOT/scripts/copy-configs/copy-configs.sh"

TEST_ROOT="$(mktemp -d)"
cleanup() {
  rm -rf "$TEST_ROOT" 2>/dev/null || true
}
trap cleanup EXIT

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

require_file() {
  local p="$1"; [[ -f "$p" ]] || fail "Expected file: $p"
}

require_dir() {
  local p="$1"; [[ -d "$p" ]] || fail "Expected dir: $p"
}

require_content() {
  local p="$1" expected="$2"
  [[ -f "$p" ]] || fail "Missing file for content check: $p"
  local got
  got="$(cat "$p")"
  [[ "$got" == "$expected" ]] || fail "Content mismatch at $p: got '$got' expected '$expected'"
}

test_default_patterns() {
  echo "== test_default_patterns =="
  local src="$TEST_ROOT/src1" tgt="$TEST_ROOT/tgt1"
  mkdir -p "$src/.cursor" "$src/.vscode" "$tgt"
  echo "DEV=1" >"$src/.env.dev"
  echo "cursorfile" >"$src/.cursor/x"
  echo "{}" >"$src/.vscode/settings.json"

  # Ensure no global config influences behavior
  local old_home="${HOME:-}"
  export HOME="$TEST_ROOT/home1"
  mkdir -p "$HOME"

  echo "$tgt" | "$COPY_SCRIPT" --source "$src" >/dev/null

  require_file "$tgt/.env.dev"
  require_file "$tgt/.vscode/settings.json"
  require_dir  "$tgt/.cursor"

  export HOME="$old_home"
  pass default_patterns
}

test_config_mapping() {
  echo "== test_config_mapping =="
  local src="$TEST_ROOT/src2" tgt="$TEST_ROOT/tgt2"
  mkdir -p "$src/foo" "$src/dirA/sub" "$tgt"
  echo "hello" >"$src/foo/file.txt"
  echo "subfile" >"$src/dirA/sub/a.txt"
  cat >"$src/.copyconfigs" <<'EOF'
foo/file.txt:bar/renamed.txt
dirA/:dirB/
EOF
  echo "$tgt" | "$COPY_SCRIPT" --source "$src" >/dev/null

  require_file "$tgt/bar/renamed.txt"
  require_content "$tgt/bar/renamed.txt" "hello"
  require_file "$tgt/dirB/sub/a.txt"
  require_content "$tgt/dirB/sub/a.txt" "subfile"
  pass config_mapping
}

test_conflicts() {
  echo "== test_conflicts =="
  local src="$TEST_ROOT/src3" tgt="$TEST_ROOT/tgt3"
  mkdir -p "$src" "$tgt"
  echo NEW >"$src/file.txt"

  # Skip mode: keep old
  echo OLD >"$tgt/file.txt"
  echo "$tgt" | "$COPY_SCRIPT" --source "$src" -c <(echo 'file.txt:file.txt') -C skip >/dev/null
  require_content "$tgt/file.txt" OLD

  # Overwrite mode
  echo OLD2 >"$tgt/file.txt"
  echo "$tgt" | "$COPY_SCRIPT" --source "$src" -c <(echo 'file.txt:file.txt') -C overwrite >/dev/null
  require_content "$tgt/file.txt" NEW

  # Backup mode
  echo OLD3 >"$tgt/file.txt"
  echo "$tgt" | "$COPY_SCRIPT" --source "$src" -c <(echo 'file.txt:file.txt') -C backup >/dev/null
  require_content "$tgt/file.txt" NEW
  ls -1 "$tgt" | rg '^file.txt\.bak-' >/dev/null || fail "Expected backup file in $tgt"
  pass conflicts
}

main() {
  test_default_patterns
  test_config_mapping
  test_conflicts
  echo "All copy-configs tests passed"
}

main "$@"

