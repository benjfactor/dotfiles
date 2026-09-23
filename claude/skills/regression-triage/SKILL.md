---
name: regression-triage
description: When a side problem surfaces (e.g. during a deploy-monitor watch) that looks like a regression introduced by an earlier PR, attribute it to the PR that introduced it, then route to one of three outcomes — fix it, alert the owning team, or record it as a known defect (GitHub issue). Findings that don't trace to a PR still go through the gate. Use when a bug/panic/error is found that is NOT from the change currently being worked on and you need to find the responsible PR and act. Triggers: "find the PR that introduced this", "who broke this", "this panic isn't from my change", a deploy-monitor side-finding, or any regression that needs a fix/alert/record decision.
---

# Regression Triage

Takes a **finding** (a bug/panic/error, usually surfaced by `deploy-monitor`)
and turns it into action: attribute it to the introducing PR, then **fix** it,
**alert** the owning team, or **record** it as a known defect — posting the
finding's context on the responsible PR when there is one.

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
   ~/.claude/skills/regression-triage/scripts/attribute_pr.sh <file> <line> [origin/master]
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

**No introducing PR?** If onset predates every candidate, or the cause is outside
the code (provider behaviour change, infra/config drift, data), say so with the
evidence and go to the gate anyway. Skip the PR comment (Phase 3); the owning
team comes from CODEOWNERS / the owning service instead.

## Phase 2 — Single review gate (catch misattribution here)

**Where to ask:** if you're talking with the user directly, use `AskUserQuestion`.
If you were delegated by another agent, send the gate to that agent (e.g.
`SendMessage` to `main`) and wait for its answer; it relays to the user or decides.

Present everything at once and get one approval:
- The attributed PR(s) + reasoning + onset evidence (so a wrong call is catchable),
  or the no-PR evidence
- The **drafted PR comment** (see template below), when there's an introducing PR
- The **owning team** + target Chat channel(s) — infer from CODEOWNERS for the
  faulting file and/or `@vendasta/<team>` mentions / Jira tag on the introducing PR
- The proposed **tracker**: a Jira bug (project inferred from the owning team /
  the introducing PR's Jira tag) or a GitHub issue on the owning repo, with a draft

Ask the routing decision:
- **Fix it** (Phase 4b) — always a Jira bug, since its key names the branch
- **Alert the owning team** (Phase 4a) — tracker: Jira bug or GitHub issue
- **Record only** (Phase 4c) — a GitHub issue as a known defect, no alert, for a later prioritisation pass

**Every Jira bug / GitHub issue this skill creates opens with a provenance line**
(italic, first line of the description/body), so triaged items trace back to the
release being monitored when they were found:
`_Found and triaged while monitoring the release of <PR URL> (<TICKET>)._`
Add "Not introduced by that release." when attribution showed that.

## Phase 3 — Post the PR comment (all routes, when there's an introducing PR)

Write the body to a file and use `gh pr comment <n> --body-file` (heredoc quoting
breaks — always use a file). Template (from the worked example, which landed well):

- **Bold lead heading** — what + where (+ "fix in #<n> (<TICKET>)" if fixing)
- **How found** — ties it to the deploy-monitor origin ("While monitoring the #X deploy I found…")
- **Root cause** — exact file:line call sites and the actual faulting line (e.g. the SDK deref)
- **Why it went unnoticed** — happy path never hits it; affected cohort; rate ("~N/day since <date>")
- **Provenance** — name the PR that introduced the code path vs the one that widened the trigger; be precise, don't over-claim
- **Fix** — link the fix PR + Jira (fix route), OR **de-escalation** ("No action needed here — flagging for context since the code originated in this PR.") plus the Jira bug / GitHub issue link (alert and record routes)

## Phase 4a — Alert the owning team

1. Record it in the tracker chosen at the gate: a Jira bug via the Atlassian MCP
   `createJiraIssue` (project from the gate, type **Bug**, description = finding
   summary + links to the introducing PR / the PR comment), or a GitHub issue as
   in Phase 4c.
2. Notify the owning team via the **send-gchat-message** skill, resolving the team
   to its channel and linking the PR comment. Use a prefix that ties it to the
   finding's origin:
   ```bash
   ~/.claude/skills/send-gchat-message/scripts/send_gchat.py \
     --targets "@vendasta/<team>" --message-file /tmp/alert.md
   ```

## Phase 4b — Fix → hand off to the existing dev flow

Do **not** orchestrate the dev flow rigidly — kick it off and step back. It is a
chain of existing skills that evolves over time, so this skill doesn't restate it.

1. **Create the Jira bug FIRST** (before the branch) so the ticket key drives the
   branch name. (`createJiraIssue`, project from the gate, type Bug; set sprint/assignee/status as you normally do.)
2. **Follow the "Skill flow" in `~/.claude/skills/README.md`** from the worktree
   step onward, with the ticket from step 1.

## Phase 4c — Record only (known defect)

For a real defect nobody is fixing now, so it's findable at the next prioritisation
pass. No Jira bug, no team alert.

1. **Search first** on the owning repo:
   `gh issue list -R <owner/repo> --search "<error signature>" --state all`.
   If a matching issue exists, comment on it with the new evidence instead of
   opening a duplicate (reopen only if the user agrees).
2. Otherwise `gh issue create -R <owner/repo> --body-file <file>`. Body: the
   signature with file:line, onset and rate, affected cohort and impact, the
   introducing PR if any, and how it was found ("while monitoring #X"). Only use
   labels the repo already has.
3. Link the issue from the PR comment (Phase 3) when there is one.

### Guardrails for the fix (learned the hard way)

- **Write every PR / issue / comment body to a file** and pass `--body-file`. Heredoc quoting in `gh pr create`/`comment` breaks on backticks/brackets.
- **Never `--amend` or squash a commit already pushed to the PR without asking.** Default to appending a new commit; if the user wants intermediate history preserved, don't collapse it. (In the example, an `--amend` silently dropped a commit the user wanted kept and had to be reconstructed.)
- **After `go generate`, the LSP cache is stale** — it'll report phantom "wrong arg count" on regenerated mocks. Trust `go build` / `go test`, not the LSP.
- **Adding a param to a mocked interface:** `gomock` `DoAndReturn` callbacks compile but panic at runtime until their signatures are updated by hand — `go vet` won't catch it.
- **Author-on-team PRs:** a requested reviewer may not surface via the GitHub API; rely on the `@vendasta/<team>` body mention to notify.

## Relationship to other skills

- `deploy-monitor` → surfaces the side-finding that triggers this skill.
- `send-gchat-message` → delivers the alert (Phase 4a).
- The README "Skill flow" → owns everything on the fix route after the Jira bug (Phase 4b).
