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
# Automatically cd's into the new worktree. Use -s to stay in the current directory.
# Usage:
#   wt fix-login          → branch "fix-login" in $WT_DIR/fix-login, based on main, cd into it
#   wt feat/new-parser    → branch "feat/new-parser" in $WT_DIR/feat-new-parser (slashes become dashes)
#   wt fix-login develop  → same, based on develop
#   wt fix-login HEAD     → same, based on current commit
#   wt -s fix-login       → create but stay in current directory
wt() {
  local stay=false
  if [ "${1:-}" = "-s" ]; then
    stay=true
    shift
  fi

  if [ -z "${1:-}" ]; then
    echo "Usage: wt [-s] <name> [base]"
    echo "  Creates a worktree at $WT_DIR/<name> with branch <name> based on [base] (default: main)"
    echo "  -s  Stay in current directory (default: cd into new worktree)"
    return 1
  fi

  local name="$1"
  local dir_name="${name//\//-}"
  local base="${2:-main}"

  git worktree add -b "$name" "$WT_DIR/$dir_name" "$base" || return 1

  if [ "$stay" = false ]; then
    cd "$WT_DIR/$dir_name"
  fi
}

# Create a detached worktree for reviewing a remote branch (no local branch created).
# Automatically cd's into the new worktree. Use -s to stay in the current directory.
# Usage:
#   wtr feat/new-parser              → checks out origin/feat/new-parser in $WT_DIR/feat-new-parser, cd into it
#   wtr feat/new-parser my-review    → same, in $WT_DIR/my-review
#   wtr -s feat/new-parser           → create but stay in current directory
wtr() {
  local stay=false
  if [ "${1:-}" = "-s" ]; then
    stay=true
    shift
  fi

  if [ -z "${1:-}" ]; then
    echo "Usage: wtr [-s] <branch> [directory-name]"
    echo "  Creates a detached worktree at $WT_DIR/<directory-name> from origin/<branch>"
    echo "  If directory-name is omitted, uses the branch name (slashes become dashes)"
    echo "  -s  Stay in current directory (default: cd into new worktree)"
    return 1
  fi

  local branch="$1"
  local dir_name="${2:-${branch//\//-}}"

  git fetch origin "$branch" || { echo "Could not fetch origin/$branch"; return 1; }
  git worktree add --detach "$WT_DIR/$dir_name" "origin/$branch" || return 1

  if [ "$stay" = false ]; then
    cd "$WT_DIR/$dir_name"
  fi
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

  case "${2:-}" in
    -k) keep_branch=true ;;
    -f) force_delete=true ;;
  esac

  # Resolve the actual branch name before removing (handles slash-to-dash mapping)
  local branch_name
  branch_name=$(git -C "$WT_DIR/$name" rev-parse --abbrev-ref HEAD 2>/dev/null)

  git worktree remove "$WT_DIR/$name" || return 1

  if [ "$keep_branch" = false ] && [ -n "$branch_name" ] && [ "$branch_name" != "HEAD" ]; then
    if [ "$force_delete" = true ]; then
      git branch -D "$branch_name" 2>/dev/null
    else
      git branch -d "$branch_name" 2>/dev/null
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
