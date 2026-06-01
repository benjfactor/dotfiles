---
name: plan-commit-to-worktree
description: >
  Run immediately after ce:plan (or compound-engineering:ce-plan) finishes writing a plan file.
  When run from the default branch (main/master), creates a git worktree and branch for the plan,
  moves the plan file into the worktree, and commits it so the plan lives on the right branch from
  the start. When already on a feature branch/worktree, commits the plan in place instead. Always
  invoke this after ce:plan completes in any repo — do not wait for the user to ask.
---

# Plan Commit to Worktree

Run this automatically after every `ce:plan` / `compound-engineering:ce-plan` completes.

## Goal

Get the newly written plan file committed onto the right feature branch so `/ce:work <plan-path>`
works immediately, without the user having to manually move anything.

There are two modes:
- **Plan written from the default branch (main/master):** create a dedicated worktree + branch and
  move the plan into it (the full flow below).
- **Plan written while already on a feature branch / in a feature worktree:** the plan is already on
  the right branch — just commit it in place (the short-circuit in Step 0).

## Steps

### 0. Short-circuit: are we already on a feature branch?

Plans are typically started from `main`/`master`, which is what this skill turns into a branch. But
if the plan was written while already on a feature branch (e.g. a `docs/...` branch holding the
brainstorm), **do not create a new worktree and do not move the plan** — moving it away from the
work it belongs with is wrong and disruptive.

```bash
# Current branch
CURRENT=$(git rev-parse --abbrev-ref HEAD)
# Default branch (master or main)
DEFAULT=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
[ -z "$DEFAULT" ] && DEFAULT=$(git rev-parse --verify origin/main >/dev/null 2>&1 && echo main || echo master)
```

**If `CURRENT` is not the default branch** (we're already on a feature branch/worktree), commit the
plan in place and stop:

1. Find the new plan file (see Step 2 for how).
2. `git add {relative-plan-path}` and commit with `chore(plan): add implementation plan ...`.
3. Report: which branch the plan was committed on, and the `/ce:work {relative-plan-path}` command.

Then **stop** — skip Steps 1–8.

**If `CURRENT` is the default branch**, continue with the full flow (Steps 1–8) to spin up a worktree.

### 1. Resolve repo context

```bash
# Repo name from cwd
basename $(git rev-parse --show-toplevel)

# Default branch (master or main)
git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'
# If empty, fall back to: git rev-parse --verify origin/main >/dev/null 2>&1 && echo main || echo master
```

### 2. Find the new plan file

Find untracked files that look like plan documents. Use `--untracked-files=all` so plans inside a
brand-new directory are listed individually (plain `git status --short` shows only `?? docs/plans/`,
not the file within):

```bash
git status --short --untracked-files=all | grep '^??' | grep '\.md'
```

If multiple untracked `.md` files exist, pick the most recently modified one. If none are
found, tell the user and stop.

Note the **relative path** from the repo root (e.g. `docs/plans/2026-05-11-001-feat-foo.md`
or `plans/foo.md` — whatever `ce:plan` wrote).

### 3. Extract ticket and description from the plan frontmatter

Read the plan file. Pull:
- `title:` field → derive a short kebab-case description (strip `feat:`, `fix:`, ticket refs, leading punctuation, etc.)
- Look for a Jira ticket (`[A-Z]+-[0-9]+`) in `title:`, `origin:`, or the first few lines of body

If no ticket is found, ask the user: "What Jira ticket is this plan for?"

### 4. Build names (follow git-worktree-jira-branch conventions)

- **Worktree path** (all lowercase, sibling of current repo):
  `../{repo}-{ticket-lower}-{description}`
  e.g. `../email-kat-1498-inbound-internet-message-id`
- **Branch** (slash form, uppercase ticket): `{TICKET}/{description}`
  e.g. `KAT-1498/inbound-internet-message-id`

### 5. Create the worktree and branch

```bash
git fetch origin
git worktree add ../{worktree-name} -b {TICKET}/{description} origin/{default-branch}
```

### 6. Move the plan file into the worktree at the same relative path

```bash
# Ensure the destination directory exists
mkdir -p ../{worktree-name}/$(dirname {relative-plan-path})
mv {relative-plan-path} ../{worktree-name}/{relative-plan-path}
```

### 7. Commit the plan

```bash
git -C ../{worktree-name} add {relative-plan-path}
git -C ../{worktree-name} commit -m "chore(plan): add implementation plan for {TICKET}"
```

### 8. Report to the user

Tell the user:
- Worktree path (absolute)
- Branch name
- The exact `/ce:work` command to start implementation:
  ```
  /ce:work {relative-plan-path}
  ```
  (relative path works because they'll run it from inside the worktree)

## Edge cases

- **Worktree already exists:** Tell the user and ask whether to reuse it or pick a different name.
- **Branch already exists:** Use `git worktree add ../{worktree-name} {TICKET}/{description}` (no `-b`) to check it out.
- **Plan directory doesn't exist in worktree:** `mkdir -p` before moving (step 6 already does this).
- **Plan file already tracked/committed:** Skip — the plan is already on a branch. Tell the user which branch it's on.
- **Not in a git repo:** Tell the user and stop.
