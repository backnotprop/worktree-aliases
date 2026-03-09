#!/usr/bin/env bash
# Adds a source line to your shell config to load worktree aliases.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_LINE="source \"$SCRIPT_DIR/worktree.sh\""

detect_shell_config() {
  if [ -n "$ZSH_VERSION" ] || [ "$SHELL" = "$(which zsh)" ]; then
    echo "${HOME}/.zshrc"
  else
    echo "${HOME}/.bashrc"
  fi
}

CONFIG_FILE=$(detect_shell_config)

if grep -qF "worktree.sh" "$CONFIG_FILE" 2>/dev/null; then
  echo "Already installed in $CONFIG_FILE"
  exit 0
fi

echo "" >> "$CONFIG_FILE"
echo "# Git worktree aliases" >> "$CONFIG_FILE"
echo "$SOURCE_LINE" >> "$CONFIG_FILE"

echo "Added to $CONFIG_FILE:"
echo "  $SOURCE_LINE"
echo ""
echo "Run 'source $CONFIG_FILE' or open a new terminal to start using:"
echo "  wt <name>        Create a worktree + branch"
echo "  wtr <branch>     Review a remote branch (detached)"
echo "  wtrm <name>      Remove a worktree"
echo "  wtcd <name>      Jump into a worktree"
echo "  wtl              List worktrees"
echo "  wtprune          Prune stale entries"
