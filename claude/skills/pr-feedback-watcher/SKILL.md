---
name: pr-feedback-watcher
description: Watch a PR for reviewer feedback and respond — implement code change requests using green-commits, reply to questions, and monitor the build after each push. Use after open-pr when the user wants to stay on top of review feedback or says "watch for feedback", "respond to review comments", or "keep an eye on the PR".
---

# PR Feedback Watcher

After opening a PR, poll for new reviewer feedback. For code change requests: implement them with the `green-commits` skill. For questions or discussion: respond with a comment. Monitor the build after each push. Continue until the PR clears the **review gate** (below) or you hit something that needs the user's input.

## The review gate

A PR is *fully ready to merge* only when all three hold:

1. **CI is green** (`ci/cloudbuild` = SUCCESS).
2. **At least 2 human approvals.** Bot reviews (`github-actions`, any `*[bot]`) never count toward the two.
3. **At least one approval from a member of a "team of interest"** — typically the team that owns the code being changed.

**Teams of interest are not derived from CODEOWNERS** (it's incomplete in this monorepo). They come from:
- any team the user explicitly asks the watcher to wait for (pass `--team <slug>`), plus
- `@<org>/<team>` slugs mentioned in the PR body, plus
- teams already requested as reviewers on the PR.

Evaluate the gate with the bundled script (run from the repo):

```bash
python3 ~/.claude/skills/pr-feedback-watcher/scripts/review_gate.py <PR_NUMBER> --repo <owner>/<repo> [--team <slug>]...
```

With no `--team`, an approving member of *any* team of interest satisfies the owner check. With `--team`, only those teams count. It prints a JSON verdict: `humanApprovals`, `humanApprovers`, `teamsOfInterest`, `teamMemberApprovals` (per team, who approved), `ownerApproved`, `ci`, and `fullyReady`. Use it for the baseline and on each poll. If `membershipUncheckable` is non-empty, the org/team read failed for those teams; report it and fall back to eyeballing approver names.

Requested reviewer teams include ones GitHub auto-requested from the **base branch's** CODEOWNERS. A PR that edits CODEOWNERS still gets the old owners until it merges, so a team can show up as "of interest" without owning the new code. If a team in `teamsOfInterest` looks wrong for the change, say so instead of waiting on it silently.

## Step 1: Get baseline state

Take the baseline timestamp **before** reading state, so anything that lands while you read is still newer than it:

```bash
BASELINE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
gh pr view <PR_NUMBER> --repo <owner>/<repo> --json reviews,comments,url \
  --jq '{url, reviews: [.reviews[] | {author: .author.login, state, submittedAt, body}], comments: [.comments[] | {author: .author.login, createdAt, body}]}'
gh api --paginate repos/<owner>/<repo>/pulls/<PR_NUMBER>/comments \
  --jq '.[] | {id, in_reply_to_id, author: .user.login, path, line, created_at, body}'
```

Pass `--repo` everywhere (from `owner/repo#N` or the PR URL) so nothing depends on the current directory.

Read all three kinds of feedback: reviews, top-level comments, and **inline review comments** (the second command). `gh pr view` doesn't return inline comments, and most code feedback is there. An `APPROVED` review can carry a non-blocking inline ask. Act on anything already present (Step 3), then start the watch. Skip a thread whose latest reply is already the user's (a fix commit cited, or a question answered). Replying again would duplicate it.

## Step 2: Watch with the bundled script

Run `scripts/watch.sh` directly as the `Monitor` command. Don't use an inline `gh`+`jq` loop: the worktree-isolation guard blocks it, and the full-JSON output is noisy enough to invite ad-hoc filters that drop events.

```
Monitor({
  command: "~/.claude/skills/pr-feedback-watcher/scripts/watch.sh <PR_NUMBER> <BASELINE> --repo <owner>/<repo> --state $CLAUDE_JOB_DIR/tmp/pr-<PR_NUMBER>.seen",
  description: "review feedback on <owner>/<repo>#<PR_NUMBER>",
  timeout_ms: 1800000
})
```

Outside a background job, choose one fixed state path (e.g. `~/.cache/pr-watch/<repo>-<PR_NUMBER>.seen`) and reuse it on every re-arm. A fresh `mktemp` path each time would replay everything.

The script polls every 2 minutes and prints one line per event, and nothing when nothing changed:

- `BASELINE ...`: always the first line. It also lists any feedback newer than `<BASELINE>` that you haven't seen. This is the race guard: a review that lands between Step 1 and the first poll still shows up here. Treat each listed item as new, even if Step 1 may already have shown it.
- `REVIEW <state> @who <time> id=...: <body>`
- `COMMENT @who <time> id=...: <body>`
- `INLINE @who <time> id=<id> reply-to=<root id> <path>:<line>: <body>`: reply in-thread with `<root id>` (Step 3).
- `CI <state> <url>`: `ci/cloudbuild` changed.
- `ERROR ...`: `gh` failed. The script keeps retrying, but tell the user if errors persist.

Bodies are cut at 300 chars. Fetch the full comment when the text is truncated. Your own comments and reviews are skipped (your replies would otherwise echo back); pass `--include-self` if the user is commenting by hand to give instructions.

A monitor expires after 30 minutes. When it does, re-arm with the **same** `<BASELINE>` and `--state` file; don't redo Step 1. The state file stores reported IDs and the last CI state. The re-arm's `BASELINE` line therefore lists only what arrived while no monitor was running, plus a `CI` line if CI changed. Nothing is reported twice and nothing is missed.

## Step 3: Categorize and act on new feedback

For each new item:

**Code change requested** (`INLINE` comment or `CHANGES_REQUESTED` review). Read an `APPROVED` review's inline comments too: "non-blocking" asks are still feedback to address or answer.
- Implement the change. Use the `green-commits` skill: run lint and tests, commit in small logical increments, push.
- After pushing, proceed to Step 4 to check the build.

**Question or general comment**:
- Reply with a top-level PR comment:
  ```bash
  gh pr comment <PR_NUMBER> --body "<response>"
  ```
- To reply to a specific review thread (inline), use the event's `reply-to` ID. GitHub only accepts replies against the thread's root comment:
  ```bash
  gh api repos/<owner>/<repo>/pulls/<pr>/comments/<reply-to id>/replies \
    --method POST -f body="<response>"
  ```

**Approval received** (`APPROVED` review state):
- Re-run `review_gate.py` and act on the verdict (see Exit conditions). A single approval is no longer a stop signal — the gate needs 2 human approvals plus owning-team sign-off.

**Build failure** (see Step 4): diagnose and fix before continuing to watch for more feedback.

## Step 4: Check build status after each push

After any code push, check CI:

```bash
gh pr view <PR_NUMBER> --json statusCheckRollup \
  --jq '[.statusCheckRollup[] | select(.context == "ci/cloudbuild") | {status: (.state // .conclusion), url: (.targetUrl // .detailsUrl)}]'
```

- `SUCCESS` → green. Keep watching (Step 2). The running monitor reports CI changes too, so you don't need a second loop.
- `FAILURE` → fetch the build log and diagnose. Fix via `green-commits`, push, recheck. If you cannot resolve the failure without user input, stop and report with full context.
- `PENDING` or active → GitHub lags. Extract the Cloud Build ID from the URL and use the `gcp-ci-watch` skill to monitor until terminal. Then handle the result as above.

## Exit conditions

Re-run `review_gate.py` after each new approval and after each green build, then:

- **`fullyReady: true`** (green CI + ≥2 human approvals + an owning-team member approved) → stop. Report: "PR #X ready — N approvals incl. `<team>` member `<who>`, CI green. Run `/merge-pr` when you're ready."
- **≥2 human approvals + green CI, but no owning-team member approved** (`ownerApproved: false`, or a specific team you care about is still missing) → **stop and ask.** Show the per-team breakdown and: "Approvals + CI are met, but `<team>` hasn't signed off. Merge anyway, or keep waiting for them?" Let the user decide — don't auto-declare ready.
- **< 2 human approvals** → keep polling. One approval (even from the owning team) is not enough.
- **A build failure** that can't be resolved without user input → report details and stop.
- **The user explicitly stops the watch.**

On any exit, stop the monitor with `TaskStop` so it doesn't keep polling.

When the user starts the watch and names a team to wait for ("watch it and wait for autobots"), pass that as `--team autobots` so the gate requires *that* team specifically.

## Notes

- Never commit or push to master — all changes go to the feature branch.
- All code changes go through `green-commits` — run lint and tests before committing.
- Keep replies concise and focused on the reviewer's concern.
- If a comment is ambiguous, make a reasonable interpretation, implement it, and note your assumption in the reply.
