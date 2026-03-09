# worktree.sh — git worktree aliases
# Source this file in your .bashrc or .zshrc:
#   source /path/to/worktree-aliases/worktree.sh

# Where worktrees are created. Defaults to parent directory (..).
# Override in your shell config: export WT_DIR=~/worktrees
WT_DIR="${WT_DIR:-..}"

# Show or change the worktree directory.
# Usage:
#   wtdir              → prints current WT_DIR
#   wtdir ~/worktrees  → sets WT_DIR for this session
wtdir() {
  if [ -z "${1:-}" ]; then
    echo "$WT_DIR"
    return 0
  fi

  WT_DIR="$1"
  echo "Worktree directory set to: $WT_DIR"
}

# Create a worktree with a new branch off main (or a specified base).
# Usage:
#   wt fix-login          → branch "fix-login" in $WT_DIR/fix-login, based on main
#   wt fix-login develop  → branch "fix-login" in $WT_DIR/fix-login, based on develop
#   wt fix-login HEAD     → branch "fix-login" in $WT_DIR/fix-login, based on current commit
wt() {
  if [ -z "${1:-}" ]; then
    echo "Usage: wt <name> [base]"
    echo "  Creates a worktree at $WT_DIR/<name> with branch <name> based on [base] (default: main)"
    return 1
  fi

  local name="$1"
  local base="${2:-main}"

  git worktree add -b "$name" "$WT_DIR/$name" "$base"
}

# Create a detached worktree for reviewing a remote branch (no local branch created).
# Usage:
#   wtr feat/new-parser              → checks out origin/feat/new-parser in $WT_DIR/feat-new-parser
#   wtr feat/new-parser my-review    → checks out origin/feat/new-parser in $WT_DIR/my-review
wtr() {
  if [ -z "${1:-}" ]; then
    echo "Usage: wtr <branch> [directory-name]"
    echo "  Creates a detached worktree at $WT_DIR/<directory-name> from origin/<branch>"
    echo "  If directory-name is omitted, uses the branch name (slashes become dashes)"
    return 1
  fi

  local branch="$1"
  local dir_name="${2:-$(echo "$branch" | tr '/' '-')}"

  git fetch origin "$branch" || { echo "Could not fetch origin/$branch"; return 1; }
  git worktree add --detach "$WT_DIR/$dir_name" "origin/$branch"
}

# Remove a worktree and optionally delete its branch.
# Usage:
#   wtrm fix-login       → removes worktree and deletes the branch
#   wtrm fix-login -k    → removes worktree but keeps the branch
#   wtrm fix-login -f    → removes worktree and force-deletes the branch (even if unmerged)
wtrm() {
  if [ -z "${1:-}" ]; then
    echo "Usage: wtrm <name> [-k|-f]"
    echo "  Removes the worktree at $WT_DIR/<name>"
    echo "  -k  Keep the branch (default: delete branch after removal)"
    echo "  -f  Force-delete the branch even if unmerged"
    return 1
  fi

  local name="$1"
  local keep_branch=false
  local force_delete=false

  local flag="${2:-}"
  if [ "$flag" = "-k" ]; then
    keep_branch=true
  elif [ "$flag" = "-f" ]; then
    force_delete=true
  fi

  if git worktree remove "$WT_DIR/$name" && [ "$keep_branch" = false ]; then
    if [ "$force_delete" = true ]; then
      git branch -D "$name" 2>/dev/null
    else
      git branch -d "$name" 2>/dev/null
    fi
  fi
}

# List all worktrees.
wtl() {
  git worktree list
}

# Change directory into an existing worktree.
wtcd() {
  if [ -z "${1:-}" ]; then
    echo "Usage: wtcd <name>"
    echo "  Changes directory to $WT_DIR/<name>"
    return 1
  fi

  cd "$WT_DIR/$1" || { echo "Worktree $WT_DIR/$1 does not exist"; return 1; }
}

# Prune stale worktree entries.
wtprune() {
  git worktree prune -v
}
