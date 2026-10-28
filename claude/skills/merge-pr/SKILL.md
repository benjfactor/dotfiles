---
name: merge-pr
description: Merge a PR — verify approval, confirm CI is green (using GCP for active builds), sync with master, squash merge, deliver to demo through the Mission Control MCP, verify, deliver to prod on the user's yes, and watch with deploy-monitor. Use when the user says "merge", "merge when green", "merge it", "ship it", or wants to land a PR.
---

# Merge PR

Full merge flow: check approval → confirm CI green → sync with master → squash merge → deliver to demo → verify → deliver to prod (user confirms) → deploy-monitor.

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

Galaxy does not allow merge commits — always squash (same for email and conversation):

```bash
gh pr merge <PR_NUMBER> --squash --delete-branch --repo vendasta/<repo>
```

> **Note:** `--delete-branch` can fail with `fatal: '<branch>' is already used by worktree` when a local worktree exists for the branch. The `--repo` flag avoids most of these errors by bypassing local git context. If it still fails, delete the branch manually — the merge itself succeeds.

## Step 5: Deliver to demo (backend services)

Applies to Go microservices delivered through Mission Control (a repo with `microservice.yaml`, e.g. `email`, `conversation`). Skip for galaxy/frontends and for anything the user wants delivered by hand.

Use the Mission Control MCP (`mcp__mission-control__*`, registered with `--enable-writes`). `create_delivery` calls the same v2 `CreateDelivery` as the UI's Deliver button, so the delivery record, event and lock checks match a UI delivery. `mscli app deliver` does not: it applies manifests with your kubeconfig and skips Mission Control entirely, so never use it for this.

1. Wait for the post-merge master build (`<service>-any-branch-0` or the repo's trigger) to succeed; use `gcp-ci-watch` while it runs.
2. Find the deployment for the merge commit with the read tools (`list_deployments` or equivalent for the app).
3. Call `create_delivery` for **demo** without `confirm` first. It returns a preview: deployment, branch, method/zone, the live deployment, rollback, vulnerabilities, warnings. Show it to the user.
4. Call it again with `confirm=true`. The `ask` permission rule prompts the user for every delivery; never work around that prompt.
5. The tool refuses some deliveries (it only takes master/main; it refuses over a live rollback or custom-branch delivery, a BAD build in the range, or a lock). Report the refusal and hand that delivery to the user in the UI. Don't retry around it.

## Step 6: Verify demo, then deliver to prod

1. Start `/deploy-monitor` for the PR on **demo** (rollout landed, pods healthy, no new errors on the changed code path).
2. If the change has a path natural demo traffic won't hit, name the manual test that exercises it (accounts, steps, expected log or metric) and ask the user to run it, then confirm it from logs or metrics.
3. When demo is healthy, ask the user before prod: "Demo looks good for #X (<one-line evidence>). Deliver to prod?" Only on a yes, repeat Step 5's preview and confirm for **prod**.
4. If demo shows a problem, stop and report it with evidence and the suggested lever. Never deliver to prod, roll back or roll forward on your own.

## Step 7: Watch prod

After the prod delivery, keep `/deploy-monitor` running for both environments for the agreed window (default 24h), notify-only:

> "Merged PR #X, delivered to demo and prod. deploy-monitor is watching both."
