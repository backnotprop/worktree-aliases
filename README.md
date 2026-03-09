# worktree-aliases

Shell functions that reduce git worktree commands to a few keystrokes. No dependencies — just source a file.

## Install

```bash
git clone https://github.com/backnotprop/worktree-aliases.git ~/.worktree-aliases
cd ~/.worktree-aliases
bash install.sh
```

Or manually add to your `.zshrc` / `.bashrc`:

```bash
source /path/to/worktree-aliases/worktree.sh
```

## Commands

| Command            | What it does                                                     |
| ------------------ | ---------------------------------------------------------------- |
| `wtdir`            | Show the current worktree directory                              |
| `wtdir <path>`     | Change the worktree directory for this session                   |
| `wt <name>`        | Create a worktree + branch off `main`                            |
| `wt <name> <base>` | Create a worktree + branch off a specific base                   |
| `wtr <branch>`     | Review a remote branch in a detached worktree (no local branch)  |
| `wtrm <name>`      | Remove a worktree and delete its branch                          |
| `wtrm <name> -k`   | Remove a worktree but keep the branch                            |
| `wtrm <name> -f`   | Remove a worktree and force-delete the branch (even if unmerged) |
| `wtcd <name>`      | Change directory into an existing worktree                       |
| `wtl`              | List all worktrees                                               |
| `wtprune`          | Prune stale worktree entries                                     |

## Examples

### Start a new feature

```bash
wt fix-login
cd ../fix-login
claude  # isolated session focused on this fix
```

### Branch off something other than main

```bash
wt experiment develop
cd ../experiment
claude  # work against develop instead of main

wt spike HEAD
cd ../spike
claude  # try a different approach from your current commit
```

### Review a teammate's PR

```bash
wtr feat/new-parser
cd ../feat-new-parser
claude  # review the code, run tests, leave comments

wtrm feat-new-parser
# Done — no orphan branch to clean up
```

### Clean up when you're done

```bash
wtrm fix-login
# Removes ../fix-login worktree AND deletes the fix-login branch

wtrm fix-login -k
# Removes the worktree but keeps the branch (e.g., PR is still open)

wtrm abandoned-feature -f
# Removes the worktree and force-deletes the branch (even if unmerged)
```

### Jump between worktrees

```bash
wtcd fix-login
# cd ../fix-login

wtcd feat-new-parser
# cd ../feat-new-parser
```

### Batch cleanup

```bash
wtl                    # See what's out there
wtrm old-feature
wtrm another-one
wtprune                # Clean up any stale entries
```

## Worktree directory

By default, worktrees are created as siblings to your repo (in the parent directory `..`). You can change this with `WT_DIR`:

```bash
# Permanently — add to your .zshrc/.bashrc before sourcing worktree.sh
export WT_DIR=~/worktrees

# Per-session
wtdir ~/worktrees
wt fix-login          # creates ~/worktrees/fix-login
wtdir                 # prints: /Users/you/worktrees
```

Default layout (no `WT_DIR` set):

```
~/projects/
├── my-app/              ← your main repo
├── fix-login/           ← wt fix-login
├── feat-new-parser/     ← wtr feat/new-parser
└── experiment/          ← wt experiment develop
```

Custom layout (`export WT_DIR=~/worktrees`):

```
~/worktrees/
├── fix-login/
├── feat-new-parser/
└── experiment/
```

## Why aliases instead of a CLI tool?

- Zero dependencies — works with any shell, any git version
- Nothing to install or update beyond sourcing a file
- Easy to read and customize — it's ~60 lines of shell
- If you outgrow these, tools like [git-worktree-wrapper](https://github.com/search?q=git+worktree+wrapper) exist

## Customization

The functions are in `worktree.sh`. Fork and edit to match your workflow. Common tweaks:

- Change the default base branch from `main` to `master` or `develop`
- Add a post-create hook (e.g., auto-run `npm install` after `wt`)
- Set `WT_DIR` to put all worktrees in a dedicated folder
