---
name: coordinator
description: Playbook for running the main session as coordinator over background subagents — what stays in the main thread, how work is handed off and back, where shared state lives, and how long watches survive sleep and restarts. Load it when a session juggles several PRs, deliveries or watches, after a context compaction or session restart, or before scheduling any recurring tick.
---

# Coordinator

CLAUDE.md's "Coordinator role" says what to delegate. This is how the pieces connect.

## What stays in the main session

- **Anything that needs the user's approval prompt:** Mission Control deliveries (`deliver` skill), and anything else behind an `ask` rule. A background subagent can't reliably surface the prompt.
- **Judgement calls and decisions for the user:** what ships alongside, whether a finding is a regression, when to ask.
- **Schedules:** `CronCreate`, `CronDelete`, `PushNotification`. Subagents can't schedule themselves.
- **Relaying:** subagent reports come back here. Pass on only what changed or needs a decision.

## Handoffs

- **Into a subagent:** a full brief. It sees nothing of this conversation: repo, worktree path, branch, sha, PR, what's been ruled out, the exact rules (no force push, explicit refspec, never push to master, don't mark ready or post unless told), and the reply format with a length cap. Set `model` per CLAUDE.md.
- **Out of a subagent:** its final report is the only link. Ask for the facts the next step needs (merge sha, PR URL, build ID, verdict), then continue from them.
- **Chain example ("ship it"):** a subagent runs `merge-pr` and reports the sha. The main session runs `deliver` (approval prompt), then spawns a `deploy-monitor` subagent with the brief. A cron wakes the main session for later ticks, and the main session resumes or replaces the watcher.

## Say it only after you call it

Never write "started", "running" or "launched" unless the Agent, SendMessage or Cron call is in the same turn. If a tick fires and you only narrate, the work silently doesn't happen. Call first, then report.

## Resuming vs fresh subagents

- Resume (`SendMessage` to the agent ID) while its context is under about 120k tokens; it keeps baselines and helper scripts.
- Past that, spawn a fresh one with a compact brief: the window, baselines and known noise to ignore.
- A finished agent can be resumed. Its notification may fire more than once; act once.

## Long watches

- Crons are session-only. They die when Claude exits, and recurring ones expire after 7 days. Ticks that land while the Mac sleeps kill the subagent mid-run ("computer went to sleep"). For a multi-day watch, tell the user once (`caffeinate -dimsu` in a spare terminal) and, on wake, run one catch-up tick for the whole gap instead of replaying every missed one.
- Pick off-minutes (`:13`, `:43`), and don't start a second tick while one is still running.
- A Monitor-based watcher (`pr-feedback-watcher`) expires after 30 minutes and can't re-arm itself. Pair it with a cron that re-arms it with the same baseline and state file, and stops when the PR merges or closes.
- Each tick's prompt carries the baselines, known noise ("relayed already, don't re-relay") and the end date. Update the cron prompt when the image or baselines change.
- Relay only crossings: a regression (with `PushNotification` if the user may be away and it's real), or a newly confirmed signal. Otherwise stay quiet. Don't push the same issue twice.
- At the end date: final summary, then `CronDelete`.

## Keep the records current (unprompted)

Every time a PR merges, a delivery lands, a watch gives a verdict, a PR closes or the user makes a decision, update the records in the same turn as reporting it. Don't wait to be asked.

- **Jira, for the PR's ticket** (the `[A-Z]+-[0-9]+` in the branch or title; for a subtask, also the parent):
  - Merged and delivered to demo: move it to **Code Review-Testing** (transition "In Review"), and comment with the PR (bare URL), merge sha, delivery ID and env, anything else that shipped with it, known limits, and what's next.
  - Prod watch GOOD: move it to **Done** with a one-line verdict comment, unless other PRs in the ticket's scope are still open. Then comment on what's left instead.
  - Rolled back or found broken: comment with the evidence, and move it back to In Progress.
  - Atlassian MCP: cloudId `77fcf126-19b9-4276-9a8f-9d9fa1efe60f` (vendasta.jira.com; the `vendasta.atlassian.net` hostname doesn't resolve). Get transition IDs with `getTransitionsForJiraIssue`, never by guessing. Comments speak for Benj: no em-dashes, and GitHub links raw.
  - Don't touch epics, and don't move tickets whose PRs aren't merged.
- **Project status board** (the Artifact database, e.g. the KAT-1625 Console): update the step's status, detail and needs fields, and add a history event. Read versions first and batch the writes.
- **When a subagent did the work,** its report is the trigger. The main session writes the records; subagents don't.

## Where state lives

Not in any one agent's context, which compacts, restarts and sleeps:

- **PR body:** Why, What, Verify, and the rollout signals for the watch.
- **Project status board** (an Artifact database, if the project has one): steps, streams and events. Update after merges, deliveries, verdicts, closed PRs and decisions without being asked.
- **Memory:** durable lessons and preferences, not task state.
- **Jira:** ticket status and close-out comments.

After a restart or compaction: list crons (`CronList`), check open PR states, read the status board, and reconcile before acting on any "next step" from a summary.

## Correcting yourself

When a later finding contradicts something already told to the user or written to the board, say so plainly in the next message and fix the board entry.
