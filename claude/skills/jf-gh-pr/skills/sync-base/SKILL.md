---
name: sync-base
description: Bring the current branch up to date with its base branch via fetch + merge (no rebase), then auto-push if a new merge commit was created. The base is auto-detected from the open PR's baseRefName via `gh pr view`; falls back to `origin/master` then `origin/main` if no PR exists. Use when the user says "sync with base", "sync with master", "sync with main", "merge base in", "pull base", "merge master in", "merge main in", "catch up to base", "catch up to master", "catch up to main", "merge origin/master", "merge origin/main", or any similar phrasing asking to update the working branch with its upstream base. Runs from the active feature worktree, not from the base branch itself.
---

# Sync with base branch

Bring the current feature branch up to date with its base via `git pull` + `git fetch` + `git merge origin/<base>`, then push the merge if green.

## Why merge, not rebase

Preserves history, avoids rewriting commits that are already on the remote feature branch, and keeps PR review threads anchored to stable commit SHAs. Use a rebase workflow only when explicitly asked.

## Steps

### 1. Confirm the worktree is clean

Uncommitted **tracked** changes risk a dirty merge. Untracked files (e.g. `.context/`, `.local-bin/`, local emulator artifacts) are *not* a problem — they aren't in git's tree and a merge can't touch them.

```bash
DIRTY=$(git status --porcelain | grep -v '^??' || true)
if [ -n "$DIRTY" ]; then
  echo "Worktree has uncommitted tracked changes — commit or stash first:"
  echo "$DIRTY"
  exit 1
fi
```

If `$DIRTY` is non-empty → stop, show the user the offending files, do not proceed. Untracked-only state is fine; continue.

### 2. Detect the base branch

Prefer the open PR's `baseRefName`. Fall back to `origin/master`, then `origin/main`.

```bash
BASE=$(gh pr view --json baseRefName --jq '.baseRefName' 2>/dev/null)
if [ -z "$BASE" ]; then
  if git show-ref --quiet refs/remotes/origin/master; then
    BASE=master
  elif git show-ref --quiet refs/remotes/origin/main; then
    BASE=main
  else
    echo "Could not determine base branch — no open PR and no origin/master or origin/main."
    exit 1
  fi
fi
echo "Base: $BASE"
```

### 3. Refuse if already on the base branch

This skill is for feature branches.

```bash
CURRENT=$(git branch --show-current)
if [ "$CURRENT" = "$BASE" ]; then
  echo "Already on base ($BASE) — nothing to sync."
  exit 0
fi
```

### 4. Run the sequence

```bash
git pull
git fetch
git merge "origin/$BASE" --no-edit
```

### 5. On merge conflict

Stop. List conflicted files via `git status --short` and tell the user to resolve them, run targeted tests, commit, and rerun the skill (or push manually).

### 6. On clean merge

- **"Already up to date"** → nothing happened; report and exit. No push needed.
- **New merge commit created** → run a build sanity check on the package set the merge touched. For Go projects, `go build ./...` plus `go test` on the packages with diffs is the right baseline. If tests fail, report and **do not push** — the user resolves before pushing.
- If build + tests green → **auto-push** to the branch's upstream:

```bash
git push
```

### 7. Final report

**Keep it to one line by default.** The user already sees git/build/test output above — the final line is glance-status, not a recap. No tables, no markdown headers, no "Step X" labels in the happy path.

**Default phrasing** (pick the one that matches the outcome):

- `Already up to date with origin/<base>.`
- `Merged origin/<base> (<short-sha>, N files) and pushed.`
- `Merged origin/<base> (<short-sha>, N files) — build green — push skipped (<reason>).`

**Verbose details only when:**

- There's a **merge conflict** → list the conflicted files inline and tell the user to resolve.
  - Example: `Conflict in foo.go, bar.go. Resolve, run targeted tests, commit, and rerun /sync-base.`
- **Build or tests failed** → show the failing package + the relevant lines from the output. Do not push.
- **PR mergeable state is unusual** — only call it out if it's `CONFLICTING`, `BLOCKED` for a reason other than draft, or `UNKNOWN` and not settling. A clean `MERGEABLE` doesn't need to be mentioned on every run.

When the user explicitly asks for a fuller breakdown ("show me what changed", "give me the full report", etc.), then a structured / tabular response is fine.

## Notes

- Always run from the worktree of the feature branch, not from the base.
- Prefer `git -C <worktree-path> <subcommand>` over `cd <path> && <subcommand>` (matches the global Bash Tool Rules in `~/.claude/CLAUDE.md`).
- Do not pass `--force` or `--no-verify` to push under any circumstance.
- If `gh` isn't authenticated, the base-detection fallback still works (just uses `origin/master`/`origin/main`).
