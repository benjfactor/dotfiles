---
name: deliver
description: Deliver a merged backend change to demo then prod through the Mission Control MCP, and hand the watch to deploy-monitor. Checks the cluster against Mission Control's "live", lists everything else that ships with it, previews, confirms (the user approves every delivery), then starts a watch built from the PR's signals. Run in the MAIN session, not a subagent. Use after merge-pr, or when the user says "deliver", "deploy to demo/prod", "ship it", "push it to prod".
---

# Deliver

Vendasta-specific: Mission Control, Argo Rollouts on GKE, Datadog, Cloud Logging. Swap this skill out for another company's deploy flow; `merge-pr` stays as is.

**Run this in the main session.** `create_delivery` has an `ask` permission rule, so the user approves every delivery. That prompt reaches them reliably only from the main session; a background subagent can stall or be auto-denied. Delegate only the watch (Step 6).

Applies to Go microservices with a `microservice.yaml` (email, conversation, ...). Frontends (galaxy) ship through vstatic; skip this skill for them unless the user asks.

## Step 1: Find the deployment

1. Wait for the post-merge master build to finish (`gcp-ci-watch` if it's still running).
2. `mcp__mission-control__list_deployments` (app, env) and pick the one whose `gitHash` is the merge sha and `branchName` is master.

## Step 2: Check what is really live

Mission Control's "live" is the last MC delivery, not the cluster. A local `mscli app deliver` applies manifests directly and leaves no MC record, so the preview's rollback guard can miss it (this rolled back someone else's fix once).

```bash
kubectl --context connectgateway_repcore-prod_us-central1_vendasta-central -n <app>-<env> get rollout \
  -o jsonpath='{range .items[*]}{.metadata.name} {.spec.template.spec.containers[0].image}{"\n"}{end}'
kubectl --context connectgateway_repcore-prod_us-central1_vendasta-central -n <app>-<env> get rs \
  --sort-by=.metadata.creationTimestamp \
  -o jsonpath='{range .items[-2:]}{.metadata.name} {.metadata.creationTimestamp} mscli={.metadata.annotations.created-by-mscli} user={.metadata.annotations.deliveredByUserId}{"\n"}{end}'
```

- `created-by-mscli` 17.9.1 is Mission Control's server. A newer laptop version means a local deliver.
- If the cluster image is newer than MC's live build, or from a branch, stop and ask the user.
- Also check `list_deliveries` for who delivered last, and whether a branch delivery is live (the MCP refuses to replace those).

## Step 3: List what else ships

Between the live sha and the target, every master commit ships too:

```bash
git -C <repo> fetch origin && git -C <repo> log --oneline <live_sha>..<target_sha>
```

Name the other PRs to the user, with any risk they carry (for example, a model change shipping alongside). The live sha comes from the live deployment's `gitHash`.

## Step 4: Preview, then confirm

1. `create_delivery` (app, env, deployment_id, message "<repo>#<pr> (<TICKET>): <one line>") without `confirm`. Show the plan: target, live, rollback flag, vulnerabilities, warnings.
2. Call again with `confirm=true`. Never work around the approval prompt.
3. If it refuses (non-master, live rollback or branch, BAD build in range, lock), report it and hand the delivery to the user in the MC UI. Don't retry around it.

Never use `mscli app deliver`.

## Step 5: Demo checks before prod

- If the change has a path natural demo traffic won't hit, give the user a short functional test: accounts, action, expected log or metric. Confirm each one from logs or Temporal when they've done it.
- Ask before prod: "Demo looks good for #X (<one-line evidence>). Deliver to prod?" Only on a yes, repeat Steps 2-4 for prod.
- If demo shows a problem, stop and report it with evidence and the suggested lever. Never deliver to prod, roll back or roll forward on your own.

## Step 6: Hand off the watch

Spawn a background subagent running `deploy-monitor` (read-only). Brief it fully, because it doesn't see the conversation:

- Repo, PR, merge sha, build ID, delivery ID, env, delivery time, the image it replaced, and the other PRs that shipped.
- **Signals, from the PR description** (a "Rollout signals" or Verify section, if the PR has one): what should shift if it works, what means broken, and the rollback lever. If the PR has none, derive them from the diff and add them to the PR body so the next watcher can read them.
- Tools: kubectl context above, Cloud Logging project `repcore-prod` with 1h-or-less windows (longer queries hang), Datadog (`execute_code`).
- Windows: demo about 45 minutes, prod as agreed (default 24h). Verdict GOOD / CONCERN / NOT GOOD, early report on a regression.

For a multi-day watch, the main session owns the schedule (see the `coordinator` skill): a `CronCreate` tick that resumes the watcher or spawns a fresh one, and relays only crossings.

Record the delivery and the verdict on the project's status board, if there is one.
