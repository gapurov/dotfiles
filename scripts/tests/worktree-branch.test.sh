#!/usr/bin/env bash
# --------------------------------------------------------------------------------
# Integration test for scripts/worktree-branch.sh
# --------------------------------------------------------------------------------
# This test spins up a throw-away git repository in a temp directory, exercises
# key code-paths of worktree-branch.sh (worktree creation, env-file copying, and
# .configfiles negation handling) and asserts on the results.  Run manually or
# wire into CI (e.g. `./scripts/tests/worktree-branch.test.sh`).
# --------------------------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

################################################################################
# Helpers                                                                       #
################################################################################

fail() { echo "❌ $*" >&2; exit 1; }
pass() { echo "✅ $*"; }

################################################################################
# Locate the script under test                                                  #
################################################################################

SCRIPT_UNDER_TEST="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/worktree-branch.sh"
[[ -x "$SCRIPT_UNDER_TEST" ]] || fail "Script under test not found or not executable: $SCRIPT_UNDER_TEST"

################################################################################
# Temporary sandbox                                                             #
################################################################################

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

################################################################################
# Initialise bare-bones git repository                                          #
################################################################################

cd "$tmpdir"
git init -q

echo "hello" > README.md
git add README.md
git commit -q -m "init"

# Keep the test script inside the repo root so its internal paths work
cp "$SCRIPT_UNDER_TEST" ./
SCRIPT="./$(basename "$SCRIPT_UNDER_TEST")"
chmod +x "$SCRIPT"

################################################################################
# Test 1 – Default env-file copying                                             #
################################################################################

echo "FOO=bar" > .env.local
# Provide a default CLAUDE.md as the script now copies it by default
echo "Test documentation" > CLAUDE.md

$SCRIPT feature1 worktrees

assert_dir="worktrees/feature1"
[[ -d "$assert_dir"        ]] || fail "worktree not created"
[[ -f "$assert_dir/.env.local" ]] || fail ".env.local not copied"

pass "Test 1 passed (env files copied)"

# Clean up worktree to avoid interference with next test
git worktree remove -f "$assert_dir" >/dev/null 2>&1
rm -rf "$assert_dir"

################################################################################
# Test 2 – .configfiles with negation                                           #
################################################################################

mkdir -p config
printf 'ok'     > config/foo.txt
printf 'secret' > config/secret.txt

cat > .configfiles <<'EOF'
config/*
!config/secret.txt
EOF

$SCRIPT config-branch worktrees

assert_dir="worktrees/config-branch"
[[ -f "$assert_dir/config/foo.txt"    ]] || fail "Included file missing in worktree"
[[ ! -f "$assert_dir/config/secret.txt" ]] || fail "Excluded file erroneously present in worktree"

pass "Test 2 passed (.configfiles negation patterns honoured)"

################################################################################
# All good                                                                      #
################################################################################

pass "All tests passed in $tmpdir"
