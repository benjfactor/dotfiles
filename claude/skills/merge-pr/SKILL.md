---
name: merge-pr
description: Merge a PR — verify approval, confirm CI is green (using GCP for active builds), sync with master, squash merge, and report the merge sha. Delivery is a separate step (the `deliver` skill). Use when the user says "merge", "merge when green", "merge it", or wants to land a PR. "Ship it" means merge-pr then deliver.
---

# Merge PR

Merge only: check approval → confirm CI green → sync with master → squash merge → report the sha.

Safe to run in a subagent: nothing here needs a permission prompt beyond `gh pr merge`. Delivery is not part of this skill; hand the sha back to the main session, which runs `deliver`.

## Step 1: Check approval status

```bash
gh pr view <PR_NUMBER> --repo <owner>/<repo> --json reviews,reviewDecision,number,url,headRefName \
  --jq '{number, url, branch: .headRefName, decision: .reviewDecision, approvals: [.reviews[] | select(.state == "APPROVED") | .author.login]}'
```

- **Approved** (or at least one approval): proceed to Step 2.
- **No approvals**: ask the user — "No approvals yet on PR #X. Proceed anyway, or wait for review?"
- **A change request newer than the last approval, or an unreplied review thread**: stop and report it. Don't merge over it.

## Step 2: Check CI status

Check GitHub's reported status first — it's reliable for completed builds:

```bash
gh pr checks <PR_NUMBER> --repo <owner>/<repo>
```

- The Cloud Build check (`ci/cloudbuild` or `<service>-branch`) passed → green, proceed to Step 3.
- Failed → stop. Report the failure and do not merge.
- Pending → GitHub lags. Extract the Cloud Build ID from the URL and use the `gcp-ci-watch` skill until a terminal status. Pass → Step 3; fail → report and stop.

## Step 3: Sync branch with master

From the feature worktree (merge, never rebase):

```bash
git -C <worktree> fetch origin && git -C <worktree> merge origin/master
```

If this brings in new commits, build and run the touched tests, push with an explicit refspec (`git -C <worktree> push origin <branch>`; never a bare `git push`, never force), and return to Step 2 for the new build.

## Step 4: Squash merge

All Vendasta repos squash (galaxy refuses merge commits):

```bash
gh pr merge <PR_NUMBER> --squash --delete-branch --repo <owner>/<repo>
```

> `--delete-branch` can fail with `fatal: '<branch>' is already used by worktree` when a local worktree exists. `--repo` avoids most of these. If it still fails, the merge itself succeeded; delete the branch later with `worktree-cleanup`.

In galaxy, retarget stacked child PRs to master **before** merging a parent with `--delete-branch`, or GitHub closes them.

## Step 5: Report

Report the merge commit sha on master and whether the post-merge build started (build ID if visible). Then stop:

> "Merged #X as <sha>. Run `deliver` to ship it."

If the user asked to "ship it", the main session continues with the `deliver` skill. Don't deliver from here.
