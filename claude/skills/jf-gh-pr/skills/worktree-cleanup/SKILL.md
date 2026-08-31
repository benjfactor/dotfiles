---
name: worktree-cleanup
description: Clean up a merged PR's worktree, local branch, and directory. Use after a PR is merged or when the user says "clean up", "remove the worktree", or "tidy up after merge".
---

# Worktree Cleanup

After a PR merges, remove the associated worktree, local branch, and directory.

## Step 1 — Determine what to clean up

Check the current working directory:

```bash
git branch --show-current   # empty if not in a git repo
git rev-parse --show-toplevel 2>/dev/null
```

**If Claude is currently inside a feature worktree** (branch is not `master`/`main`):
- Auto-select that worktree for cleanup — no need to ask.
- Confirm the PR is merged before proceeding: `gh pr view --json state --jq '.state'`

**If Claude is on `master`/`main` or not in a worktree** (e.g., working from the main repo root):
- Run `git worktree list` to show all worktrees.
- Check which have merged PRs: `gh pr list --state merged --json headRefName --jq '.[].headRefName'`
- Ask the user which worktree(s) to remove — do not auto-select.

## Step 2 — Remove the worktree

```bash
git -C /path/to/main-repo worktree remove /path/to/worktree --force
```

Worktree dirs follow the pattern `{repo}-{ticket}-{description}` next to the main repo dir.

## Step 3 — Delete the local branch

The remote branch is deleted by GitHub on merge. Clean up the local tracking branch:

```bash
git -C /path/to/main-repo branch -d <branch-name>
```

Use `-D` if `-d` refuses (squash merges aren't considered fast-forward).

## Step 4 — Confirm

```bash
ls /path/to/worktree 2>/dev/null || echo "dir removed"
git -C /path/to/main-repo branch --list <branch-name>
```

Report back confirming the worktree, branch, and directory are all gone.

## Notes

- Never clean up a worktree whose PR is still open.
- If cleaning up multiple worktrees at once (e.g. end of sprint), verify each PR state individually before removing.
