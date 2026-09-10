---
name: regression-triage
description: When a side problem surfaces (e.g. during a deploy-monitor watch) that looks like a regression introduced by an earlier PR, attribute it to the PR that introduced it, then route to one of two outcomes — alert the owning team, or fix it. Use when a bug/panic/error is found that is NOT from the change currently being worked on and you need to find the responsible PR and act. Triggers: "find the PR that introduced this", "who broke this", "this panic isn't from my change", a deploy-monitor side-finding, or any attributed regression that needs an alert-or-fix decision.
---

# Regression Triage

Takes a **finding** (a bug/panic/error, usually surfaced by `deploy-monitor`)
and turns it into action: attribute it to the introducing PR, then either
**alert** the owning team or **fix** it — in both cases posting the finding's
context on the responsible PR.

This skill is **standalone** — `deploy-monitor` surfaces a side-finding and
*suggests* running this; it does not auto-invoke. Invoke it manually whenever you
have a regression to attribute and act on.

## Input: the finding

Gather (from the deploy-monitor context or pasted in):
- Error signature / stack frames with **file:line**
- Prod evidence: occurrence count, **onset**, affected cohort, recovered-vs-fatal
- What behaviour is affected and how bad (each occurrence = failed request? silent skip? crash?)

## Phase 1 — Attribute (do NOT act yet)

> Hard-won lesson: the first, most confident attribution is often **wrong**.
> In the worked example the skill blamed PR #1527 on a narrow-window onset, opened
> it in Arc, and built a watch — then had to fully retract it. A single skeptical
> nudge flipped the conclusion. Earn the attribution before acting on it.

1. **Establish true onset with a WIDE log window first (7–30d), not the deploy-watch window.**
   A 24h watch window makes everything look like it "started today." Query the
   error signature over weeks and find the real first occurrence. If the bug
   predates the PR you suspect, that PR didn't introduce it.
2. **Blame the EXACT faulting line, not the surrounding feature.** Use the helper:
   ```bash
   "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/skills/jf-triage-flow}"/skills/regression-triage/scripts/attribute_pr.sh <file> <line> [origin/master]
   ```
   It prints the commit, author/date, and PR(s). Treat it as an input, not the verdict.
3. **Distinguish three different roles** — be explicit about which a PR played:
   - *introduced the code path* (the feature exists because of it)
   - *is the line that faults* (the actual deref / panic / bad branch)
   - *widened the trigger* (made a latent bug reachable for more inputs)
   The "introduced the code path" PR is frequently **not** the culprit.
4. **Disprove each candidate.** For every hypothesis, find evidence that rules it
   in or out (does that function ever return nil? does the repo ever return
   `(nil, nil)`? when did the offending branch start being taken?). Don't stop at
   the first plausible blame.
5. Produce **ranked candidate PR(s) with the evidence chain** — and stop here.
   No Arc, no comment, no branch until the gate confirms.

## Phase 2 — Single review gate (catch misattribution here)

Present everything at once and get one approval (use `AskUserQuestion`):
- The attributed PR(s) + reasoning + onset evidence (so a wrong call is catchable)
- The **drafted PR comment** (see template below)
- The **owning team** + target Chat channel(s) — infer from CODEOWNERS for the
  faulting file and/or `@vendasta/<team>` mentions / Jira tag on the introducing PR
- The proposed **Jira project** + a draft bug (project inferred from the owning
  team / the introducing PR's Jira tag; confirm or override)

Ask the two routing decisions:
- **Fix it** or **alert-only**?
- **Create a Jira bug?** (Y/N, + board override)

## Phase 3 — Post the PR comment (BOTH branches)

Write the body to a file and use `gh pr comment <n> --body-file` (heredoc quoting
breaks — always use a file). Template (from the worked example, which landed well):

- **Bold lead heading** — what + where (+ "fix in #<n> (<TICKET>)" if fixing)
- **How found** — ties it to the deploy-monitor origin ("While monitoring the #X deploy I found…")
- **Root cause** — exact file:line call sites and the actual faulting line (e.g. the SDK deref)
- **Why it went unnoticed** — happy path never hits it; affected cohort; rate ("~N/day since <date>")
- **Provenance** — name the PR that introduced the code path vs the one that widened the trigger; be precise, don't over-claim
- **Fix** — link the fix PR + Jira (fix branch), OR **de-escalation** ("No action needed here — flagging for context since the code originated in this PR.") (alert branch)

## Phase 4a — Alert-only

1. (If chosen) create the Jira bug via the Atlassian MCP `createJiraIssue` — project
   from the gate, issue type **Bug**, description = finding summary + links to the
   introducing PR / the PR comment.
2. Notify the owning team via the **send-gchat-message** skill, passing the team
   handle (`@vendasta/<team>`) as the target and an alert body that links the PR
   comment. Write the body to a file and pass the file. Open with a line that ties
   the alert to the finding's origin, so the receiving team knows why it arrived.
   Let that skill resolve the team to its channel and handle auth — do not invoke
   its script directly.

## Phase 4b — Fix → hand off to the existing dev flow

Do **not** orchestrate the dev flow rigidly — kick it off and step back. It is a
chain of existing skills that evolves over time (see the flow diagram in the repo
README). Order:

1. **Create the Jira bug FIRST** (before the branch) so the ticket key drives the
   branch name. (`createJiraIssue`, project from the gate, type Bug; set sprint/assignee/status as you normally do.)
2. **Branch off latest `origin/master`**, named from the ticket — via
   `git-worktree-jira-branch` (or a plain branch if not using worktrees), e.g.
   `<TICKET>/<short-desc>`.
3. **Plan or not — your call:** run `/plan` for non-trivial fixes, or implement
   directly for a small/obvious one. Then the work gets done with **small green
   commits** (`green-commits` / `plan-implementation-commits`; run the repo's
   pre-commit / `golang-pre-commit-tests` before each).
4. **`open-pr`** (draft) → open in Arc (`open-in-arc`) for review.
5. When ready: **`pr-ready`** (marks ready, adds reviewers, posts via `notify-pr-channels`).
6. **`pr-feedback-watcher`** to watch + address feedback.
7. On approvals + green: prompt to merge → **`merge-pr`**, which hands off to
   **`deploy-monitor`** on the fix PR — closing the loop.

### Guardrails for the fix (learned the hard way)

- **Write every PR / issue / comment body to a file** and pass `--body-file`. Heredoc quoting in `gh pr create`/`comment` breaks on backticks/brackets.
- **Never `--amend` or squash a commit already pushed to the PR without asking.** Default to appending a new commit; if the user wants intermediate history preserved, don't collapse it. (In the example, an `--amend` silently dropped a commit the user wanted kept and had to be reconstructed.)
- **After `go generate`, the LSP cache is stale** — it'll report phantom "wrong arg count" on regenerated mocks. Trust `go build` / `go test`, not the LSP.
- **Adding a param to a mocked interface:** `gomock` `DoAndReturn` callbacks compile but panic at runtime until their signatures are updated by hand — `go vet` won't catch it.
- **Author-on-team PRs:** a requested reviewer may not surface via the GitHub API; rely on the `@vendasta/<team>` body mention to notify.

## Relationship to other skills

- `deploy-monitor` → surfaces the side-finding that triggers this skill.
- `send-gchat-message` → delivers the alert (Phase 4a).
- `notify-pr-channels` → used inside `pr-ready` on the fix branch (Phase 4b).
- `merge-pr` → tail of the fix branch; hands back to `deploy-monitor`.
