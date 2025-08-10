#!/usr/bin/env bash
# --------------------------------------------------------------------------------
# Integration test for scripts/print-commit-messages.sh
# --------------------------------------------------------------------------------
# This test spins up a throw-away git repository in a temp directory, makes a few
# commits across branches, and asserts the script outputs the expected messages.
# --------------------------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

fail() { echo "❌ $*" >&2; exit 1; }
pass() { echo "✅ $*"; }

SCRIPT_UNDER_TEST="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/print-commit-messages.sh"
[[ -x "$SCRIPT_UNDER_TEST" ]] || fail "Script not found or not executable: $SCRIPT_UNDER_TEST"

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

cd "$tmpdir"
git init -q
git config user.name "Test User"
git config user.email "test@example.com"

# base commit on main
echo base > file.txt
git add file.txt
git commit -q -m "base commit"

# simulate remote main so origin/main exists
git branch -M main
git checkout -q -b temp-remote
git checkout -q main
git update-ref refs/remotes/origin/main HEAD

# feature branch with two commits
git checkout -q -b feature/topic
echo one >> file.txt
git add file.txt
git commit -q -m "feat: first change"
echo two >> file.txt
git add file.txt
git commit -q -m "fix: second change"

# Copy the script into repo root for relative execution and run
cp "$SCRIPT_UNDER_TEST" ./
SCRIPT="./$(basename "$SCRIPT_UNDER_TEST")"
chmod +x "$SCRIPT"

output="$($SCRIPT)"

# Expect two lines, with messages in reverse chronological order
expected_first="fix: second change"
expected_second="feat: first change"

first_line="$(printf '%s\n' "$output" | sed -n '1p')"
second_line="$(printf '%s\n' "$output" | sed -n '2p')"

[[ "$first_line" == "$expected_first" ]] || fail "Unexpected first line: '$first_line'"
[[ "$second_line" == "$expected_second" ]] || fail "Unexpected second line: '$second_line'"

pass "Script outputs expected commit messages for current branch"
