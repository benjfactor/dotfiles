---
name: merge-pr
description: Merge a PR — verify approval, confirm CI is green (escalating to the CI provider's own status while a build is still running), sync with the base branch, squash merge, then hand off to deployment monitoring. Use when the user says "merge", "merge when green", "merge it", or wants to land a PR.
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

Read GitHub's status check rollup first — it's reliable for completed builds.
**Every reported check must be green.** A repo with one authoritative check can
narrow the read to it, but do not assume a check name.

```bash
gh pr view --json statusCheckRollup --jq '
[ .statusCheckRollup[]
  | { name:   (.context // .name),
      status: (.state // .conclusion // .status // "UNKNOWN"),
      url:    (.targetUrl // .detailsUrl) } ]
| { overall:
      ( if   length == 0 then "NONE"
        elif any(.[]; .status | IN("FAILURE","ERROR","CANCELLED","TIMED_OUT","ACTION_REQUIRED","STARTUP_FAILURE","STALE")) then "FAILURE"
        elif all(.[]; .status | IN("SUCCESS","NEUTRAL","SKIPPED")) then "SUCCESS"
        else "PENDING" end ),
    notPassing: [ .[] | select(.status | IN("SUCCESS","NEUTRAL","SKIPPED") | not) ] }'
```

- `SUCCESS` → green, proceed to Step 3.
- `FAILURE` → stop. Report which checks in `notPassing` failed, with their URLs, and do not merge.
- `PENDING` → the rollup lags while a build is still running. Escalate to the CI
  provider's own status and wait for a terminal result; the `gcp-ci-watch` skill
  covers one such provider. If it passes, continue to Step 3. If it fails, report and stop.
- `NONE` → the repo reports no checks at all. Say so and ask whether to merge without CI.

An unrecognised state counts as pending, so a state this skill has not seen
before never reads as green by accident.

## Step 3: Sync branch with master

Run from the feature worktree:

```bash
git pull && git fetch && git merge origin/master
```

If this pulls in new commits from master, push and return to Step 2 to wait for the new build before merging.

## Step 4: Squash merge

Squash by default — many repos disallow merge commits, and a squashed history
is what the commit conventions assume:

```bash
gh pr merge <PR_NUMBER> --squash --delete-branch
```

> **Note:** `--delete-branch` can fail with `fatal: '<branch>' is already used by worktree` when a local worktree exists for the branch. Passing `--repo <owner>/<name>` bypasses local git context and avoids most of these — derive it from `gh repo view --json nameWithOwner` rather than hardcoding one. If it still fails, delete the branch manually — the merge itself succeeds.

## Step 5: Hand off to deploy-monitor

After a successful merge, hand the PR URL to whatever watches deployments in
this environment, so the rollout is observed rather than assumed:

> "Merged PR #X. Starting deployment monitoring to watch the rollout."

If nothing is available to watch the rollout, say so rather than reporting the
merge as fully done.
