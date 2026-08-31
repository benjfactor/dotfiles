---
name: merge-pr
description: Merge a PR — verify approval, confirm CI is green (using GCP for active builds), sync with master, squash merge, then hand off to deploy-monitor. Use when the user says "merge", "merge when green", "merge it", or wants to land a PR.
---

# Merge PR

Full merge flow: check approval → confirm CI green → sync with master → squash merge → hand off to deploy-monitor.

## Step 1: Check approval status

```bash
gh pr view --json reviews,number,url,headRefName \
  --jq '{number: .number, url: .url, branch: .headRefName, approvals: [.reviews[] | select(.state == "APPROVED") | .author.login]}'
```

- **At least one approval**: proceed to Step 2.
- **No approvals**: ask the user — "No approvals yet on PR #X. Proceed anyway, or wait for review?"

## Step 2: Check CI status

Check GitHub's reported status first — it's reliable for completed builds:

```bash
gh pr view --json statusCheckRollup \
  --jq '[.statusCheckRollup[] | select(.context == "ci/cloudbuild") | {status: (.state // .conclusion), url: (.targetUrl // .detailsUrl)}]'
```

- `SUCCESS` → green, proceed to Step 3.
- `FAILURE` → stop. Report the failure and do not merge.
- `PENDING` or in-progress → GitHub lags. Extract the Cloud Build ID from the URL and use the `gcp-ci-watch` skill to monitor until a terminal status. If the build passes, continue to Step 3. If it fails, report and stop.

## Step 3: Sync branch with master

Run from the feature worktree:

```bash
git pull && git fetch && git merge origin/master
```

If this pulls in new commits from master, push and return to Step 2 to wait for the new build before merging.

## Step 4: Squash merge

Galaxy does not allow merge commits — always squash:

```bash
gh pr merge <PR_NUMBER> --squash --delete-branch --repo vendasta/galaxy
```

> **Note:** `--delete-branch` can fail with `fatal: '<branch>' is already used by worktree` when a local worktree exists for the branch. The `--repo` flag avoids most of these errors by bypassing local git context. If it still fails, delete the branch manually — the merge itself succeeds.

## Step 5: Hand off to deploy-monitor

After a successful merge, invoke the `deploy-monitor` skill with the PR URL to watch the rollout:

> "Merged PR #X. Starting deploy-monitor to watch the rollout."

Then invoke `/deploy-monitor` with the merged PR URL.
