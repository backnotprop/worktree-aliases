#!/usr/bin/env bash
# test.sh — integration tests for worktree aliases
# Creates an isolated sandbox, runs all commands, verifies behavior, cleans up.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SANDBOX=""
PASSED=0
FAILED=0

# --- helpers ---

setup_sandbox() {
  SANDBOX="$(mktemp -d)"
  echo "Sandbox: $SANDBOX"
  echo ""

  # Create a "remote" bare repo to simulate origin
  git init --bare "$SANDBOX/origin.git" >/dev/null 2>&1

  # Create the main working repo, cloned from origin
  git clone "$SANDBOX/origin.git" "$SANDBOX/main-repo" >/dev/null 2>&1
  cd "$SANDBOX/main-repo"

  # Initial commit on main
  git checkout -b main >/dev/null 2>&1
  echo "hello" > file.txt
  git add file.txt
  git commit -m "initial commit" >/dev/null 2>&1
  git push -u origin main >/dev/null 2>&1

  # Create a remote feature branch for wtr tests
  git checkout -b feat/new-parser >/dev/null 2>&1
  echo "parser code" > parser.txt
  git add parser.txt
  git commit -m "add parser" >/dev/null 2>&1
  git push origin feat/new-parser >/dev/null 2>&1

  # Back to main
  git checkout main >/dev/null 2>&1

  # Source the aliases — let WT_DIR default to ".." (parent directory)
  unset WT_DIR
  source "$SCRIPT_DIR/worktree.sh"
}

cleanup_sandbox() {
  if [ -n "$SANDBOX" ] && [ -d "$SANDBOX" ]; then
    rm -rf "$SANDBOX"
    echo ""
    echo "Sandbox cleaned up."
  fi
}

trap cleanup_sandbox EXIT

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $label"
    PASSED=$((PASSED + 1))
  else
    echo "  FAIL: $label"
    echo "    expected: $expected"
    echo "    actual:   $actual"
    FAILED=$((FAILED + 1))
  fi
}

assert_dir_exists() {
  local label="$1" dir="$2"
  if [ -d "$dir" ]; then
    echo "  PASS: $label"
    PASSED=$((PASSED + 1))
  else
    echo "  FAIL: $label — directory $dir does not exist"
    FAILED=$((FAILED + 1))
  fi
}

assert_dir_not_exists() {
  local label="$1" dir="$2"
  if [ ! -d "$dir" ]; then
    echo "  PASS: $label"
    PASSED=$((PASSED + 1))
  else
    echo "  FAIL: $label — directory $dir still exists"
    FAILED=$((FAILED + 1))
  fi
}

assert_branch_exists() {
  local label="$1" branch="$2"
  if git branch --list "$branch" | grep -q "$branch"; then
    echo "  PASS: $label"
    PASSED=$((PASSED + 1))
  else
    echo "  FAIL: $label — branch $branch does not exist"
    FAILED=$((FAILED + 1))
  fi
}

assert_branch_not_exists() {
  local label="$1" branch="$2"
  if ! git branch --list "$branch" | grep -q "$branch"; then
    echo "  PASS: $label"
    PASSED=$((PASSED + 1))
  else
    echo "  FAIL: $label — branch $branch still exists"
    FAILED=$((FAILED + 1))
  fi
}

# --- tests ---

test_wt_basic() {
  echo "test: wt <name> — create worktree off main and cd into it"
  cd "$SANDBOX/main-repo"

  wt my-feature

  assert_dir_exists "worktree directory created" "$SANDBOX/my-feature"
  assert_branch_exists "branch created" "my-feature"
  assert_eq "worktree has file.txt" "hello" "$(cat "$SANDBOX/my-feature/file.txt")"
  assert_eq "cd'd into worktree" "$SANDBOX/my-feature" "$(pwd)"

  # cleanup
  cd "$SANDBOX/main-repo"
  wtrm my-feature
}

test_wt_custom_base() {
  echo "test: wt <name> <base> — create worktree off custom base"
  cd "$SANDBOX/main-repo"

  # Create a develop branch with extra content
  git branch develop main >/dev/null 2>&1

  wt from-develop develop

  assert_dir_exists "worktree directory created" "$SANDBOX/from-develop"
  assert_branch_exists "branch created" "from-develop"

  # cleanup
  cd "$SANDBOX/main-repo"
  wtrm from-develop
  git branch -d develop >/dev/null 2>&1
}

test_wt_head() {
  echo "test: wt <name> HEAD — create worktree off current commit"
  cd "$SANDBOX/main-repo"

  wt from-head HEAD

  assert_dir_exists "worktree directory created" "$SANDBOX/from-head"
  assert_branch_exists "branch created" "from-head"

  # cleanup
  cd "$SANDBOX/main-repo"
  wtrm from-head
}

test_wt_slash_branch() {
  echo "test: wt feat/thing — slash branch name, dashed directory"
  cd "$SANDBOX/main-repo"

  wt feat/thing

  assert_dir_exists "worktree uses dashes" "$SANDBOX/feat-thing"
  assert_branch_exists "branch keeps slashes" "feat/thing"
  assert_eq "cd'd into worktree" "$SANDBOX/feat-thing" "$(pwd)"

  # cleanup — wtrm should resolve the slashed branch name
  cd "$SANDBOX/main-repo"
  wtrm feat-thing

  assert_branch_not_exists "slashed branch deleted" "feat/thing"
}

test_wt_stay() {
  echo "test: wt -s <name> — create worktree but stay in current directory"
  cd "$SANDBOX/main-repo"

  wt -s stay-test

  assert_dir_exists "worktree directory created" "$SANDBOX/stay-test"
  assert_branch_exists "branch created" "stay-test"
  assert_eq "stayed in main repo" "$SANDBOX/main-repo" "$(pwd)"

  # cleanup
  wtrm stay-test
}

test_wt_no_args() {
  echo "test: wt (no args) — prints usage and fails"
  cd "$SANDBOX/main-repo"

  local output exit_code=0
  output=$(wt 2>&1) || exit_code=$?
  assert_eq "exits with error" "1" "$exit_code"
  if echo "$output" | grep -q 'Usage'; then
    echo "  PASS: shows usage"
    PASSED=$((PASSED + 1))
  else
    echo "  FAIL: shows usage — output: $output"
    FAILED=$((FAILED + 1))
  fi
}

test_wtr_basic() {
  echo "test: wtr <branch> — detached worktree from remote branch and cd into it"
  cd "$SANDBOX/main-repo"

  wtr feat/new-parser

  assert_dir_exists "worktree directory created (slashes to dashes)" "$SANDBOX/feat-new-parser"
  assert_eq "has parser.txt from remote branch" "parser code" "$(cat "$SANDBOX/feat-new-parser/parser.txt")"
  assert_eq "cd'd into worktree" "$SANDBOX/feat-new-parser" "$(pwd)"

  # Verify it's detached (no local branch named feat-new-parser)
  assert_branch_not_exists "no local branch created" "feat-new-parser"

  # cleanup
  cd "$SANDBOX/main-repo"
  git worktree remove "$SANDBOX/feat-new-parser"
}

test_wtr_custom_dir() {
  echo "test: wtr <branch> <dir> — detached worktree with custom directory name"
  cd "$SANDBOX/main-repo"

  wtr feat/new-parser my-review

  assert_dir_exists "custom directory created" "$SANDBOX/my-review"
  assert_eq "has parser.txt" "parser code" "$(cat "$SANDBOX/my-review/parser.txt")"

  # cleanup
  cd "$SANDBOX/main-repo"
  git worktree remove "$SANDBOX/my-review"
}

test_wtr_stay() {
  echo "test: wtr -s <branch> — detached worktree but stay in current directory"
  cd "$SANDBOX/main-repo"

  wtr -s feat/new-parser stay-review

  assert_dir_exists "worktree created" "$SANDBOX/stay-review"
  assert_eq "stayed in main repo" "$SANDBOX/main-repo" "$(pwd)"

  # cleanup
  git worktree remove "$SANDBOX/stay-review"
}

test_wtr_bad_branch() {
  echo "test: wtr <nonexistent> — fails with error message"
  cd "$SANDBOX/main-repo"

  local output
  output=$(wtr nonexistent/branch 2>&1) || true
  assert_eq "shows fetch error" "true" "$(echo "$output" | grep -q 'Could not fetch' && echo true || echo false)"
  assert_dir_not_exists "no worktree created" "$SANDBOX/nonexistent-branch"
}

test_wtr_no_args() {
  echo "test: wtr (no args) — prints usage and fails"
  cd "$SANDBOX/main-repo"

  local output exit_code=0
  output=$(wtr 2>&1) || exit_code=$?
  assert_eq "exits with error" "1" "$exit_code"
  if echo "$output" | grep -q 'Usage'; then
    echo "  PASS: shows usage"
    PASSED=$((PASSED + 1))
  else
    echo "  FAIL: shows usage — output: $output"
    FAILED=$((FAILED + 1))
  fi
}

test_wtrm_deletes_branch() {
  echo "test: wtrm <name> — removes worktree and deletes branch"
  cd "$SANDBOX/main-repo"

  wt to-remove
  cd "$SANDBOX/main-repo"
  wtrm to-remove

  assert_dir_not_exists "worktree removed" "$SANDBOX/to-remove"
  assert_branch_not_exists "branch deleted" "to-remove"
}

test_wtrm_keep_branch() {
  echo "test: wtrm <name> -k — removes worktree but keeps branch"
  cd "$SANDBOX/main-repo"

  wt keep-branch-test
  cd "$SANDBOX/main-repo"
  wtrm keep-branch-test -k

  assert_dir_not_exists "worktree removed" "$SANDBOX/keep-branch-test"
  assert_branch_exists "branch kept" "keep-branch-test"

  # cleanup
  git branch -d keep-branch-test >/dev/null 2>&1
}

test_wtrm_force_delete() {
  echo "test: wtrm <name> -f — removes worktree and force-deletes unmerged branch"
  cd "$SANDBOX/main-repo"

  wt unmerged-work
  # wt already cd'd into the worktree

  # Add a commit that isn't merged to main so -d would refuse
  echo "unmerged change" > unmerged.txt
  git add unmerged.txt
  git commit -m "unmerged work" >/dev/null 2>&1

  cd "$SANDBOX/main-repo"
  wtrm unmerged-work -f

  assert_dir_not_exists "worktree removed" "$SANDBOX/unmerged-work"
  assert_branch_not_exists "unmerged branch force-deleted" "unmerged-work"
}

test_wtrm_no_args() {
  echo "test: wtrm (no args) — prints usage and fails"
  cd "$SANDBOX/main-repo"

  local output exit_code=0
  output=$(wtrm 2>&1) || exit_code=$?
  assert_eq "exits with error" "1" "$exit_code"
  if echo "$output" | grep -q 'Usage'; then
    echo "  PASS: shows usage"
    PASSED=$((PASSED + 1))
  else
    echo "  FAIL: shows usage — output: $output"
    FAILED=$((FAILED + 1))
  fi
}

test_wtcd() {
  echo "test: wtcd <name> — changes directory into worktree"
  cd "$SANDBOX/main-repo"

  wt -s cd-target

  wtcd cd-target
  assert_eq "pwd is worktree directory" "$SANDBOX/cd-target" "$(pwd)"

  # go back and cleanup
  cd "$SANDBOX/main-repo"
  wtrm cd-target
}

test_wtcd_nonexistent() {
  echo "test: wtcd <nonexistent> — fails with error"
  cd "$SANDBOX/main-repo"

  local output
  output=$(wtcd nonexistent-worktree 2>&1) || true
  assert_eq "shows error" "true" "$(echo "$output" | grep -q 'does not exist' && echo true || echo false)"
}

test_wtcd_no_args() {
  echo "test: wtcd (no args) — prints usage and fails"
  cd "$SANDBOX/main-repo"

  local output exit_code=0
  output=$(wtcd 2>&1) || exit_code=$?
  assert_eq "exits with error" "1" "$exit_code"
  if echo "$output" | grep -q 'Usage'; then
    echo "  PASS: shows usage"
    PASSED=$((PASSED + 1))
  else
    echo "  FAIL: shows usage — output: $output"
    FAILED=$((FAILED + 1))
  fi
}

test_wtl() {
  echo "test: wtl — lists worktrees"
  cd "$SANDBOX/main-repo"

  wt -s list-test

  local output
  output=$(wtl)
  assert_eq "shows main repo" "true" "$(echo "$output" | grep -q 'main-repo' && echo true || echo false)"
  assert_eq "shows list-test worktree" "true" "$(echo "$output" | grep -q 'list-test' && echo true || echo false)"

  # cleanup
  wtrm list-test
}

test_wtprune() {
  echo "test: wtprune — prunes stale entries"
  cd "$SANDBOX/main-repo"

  wt -s prune-test

  # Manually nuke the directory to simulate a stale worktree
  rm -rf "$SANDBOX/prune-test"

  local output
  output=$(wtprune 2>&1)
  assert_eq "reports pruning" "true" "$(echo "$output" | grep -q 'prune-test' && echo true || echo false)"

  # cleanup branch
  git branch -d prune-test >/dev/null 2>&1 || git branch -D prune-test >/dev/null 2>&1
}

test_wtdir_show() {
  echo "test: wtdir — shows current WT_DIR"
  cd "$SANDBOX/main-repo"

  local output
  output=$(wtdir)
  assert_eq "shows WT_DIR" ".." "$output"
}

test_wtdir_change() {
  echo "test: wtdir <path> — changes WT_DIR for the session"
  cd "$SANDBOX/main-repo"

  mkdir -p "$SANDBOX/custom-dir"

  wtdir "$SANDBOX/custom-dir"
  assert_eq "WT_DIR updated" "$SANDBOX/custom-dir" "$WT_DIR"

  # Create a worktree using the new WT_DIR
  wt -s custom-wt

  assert_dir_exists "worktree in custom dir" "$SANDBOX/custom-dir/custom-wt"
  assert_branch_exists "branch created" "custom-wt"

  # cleanup
  wtrm custom-wt
  wtdir ".."
}

test_wt_duplicate_branch() {
  echo "test: wt with existing branch name — git rejects it"
  cd "$SANDBOX/main-repo"

  wt -s dup-test
  local output
  output=$(wt dup-test 2>&1) || true
  assert_eq "git rejects duplicate" "true" "$(echo "$output" | grep -qi 'already exists\|fatal' && echo true || echo false)"

  # cleanup
  wtrm dup-test
}

# --- run ---

main() {
  setup_sandbox

  echo "Running tests..."
  echo ""

  test_wt_basic
  echo ""
  test_wt_custom_base
  echo ""
  test_wt_head
  echo ""
  test_wt_slash_branch
  echo ""
  test_wt_stay
  echo ""
  test_wt_no_args
  echo ""
  test_wtr_basic
  echo ""
  test_wtr_custom_dir
  echo ""
  test_wtr_stay
  echo ""
  test_wtr_bad_branch
  echo ""
  test_wtr_no_args
  echo ""
  test_wtrm_deletes_branch
  echo ""
  test_wtrm_keep_branch
  echo ""
  test_wtrm_force_delete
  echo ""
  test_wtrm_no_args
  echo ""
  test_wtcd
  echo ""
  test_wtcd_nonexistent
  echo ""
  test_wtcd_no_args
  echo ""
  test_wtl
  echo ""
  test_wtprune
  echo ""
  test_wtdir_show
  echo ""
  test_wtdir_change
  echo ""
  test_wt_duplicate_branch
  echo ""

  echo "========================"
  echo "Results: $PASSED passed, $FAILED failed"
  echo "========================"

  if [ "$FAILED" -gt 0 ]; then
    exit 1
  fi
}

main
