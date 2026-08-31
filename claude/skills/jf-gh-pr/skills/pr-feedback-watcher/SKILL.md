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
python3 "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/skills/jf-gh-pr}"/skills/pr-feedback-watcher/scripts/review_gate.py <PR_NUMBER> [--team <slug>]...
```

It prints a JSON verdict: `humanApprovals`, `humanApprovers`, `teamsOfInterest`, `teamMemberApprovals` (per team, who approved), `ownerApproved`, `ci`, and `fullyReady`. Use it for the baseline and on each poll. If `membershipUncheckable` is non-empty, the org/team read failed for those teams — report it and fall back to eyeballing approver names.

## Step 1: Get baseline state

Before starting the poll loop, capture the current review state so you can detect new items:

```bash
gh pr view <PR_NUMBER> --json reviews,comments,reviewRequests,number,url \
  --jq '{number: .number, url: .url, reviews: .reviews, comments: .comments}'
```

Record the latest `submittedAt` / `createdAt` timestamps. Any item newer than these timestamps on the next poll is "new."

## Step 2: Poll for feedback with Monitor tool

Use the `Monitor` tool (not a bash sleep loop) to poll every 2 minutes:

```
while true; do
  gh pr view <PR_NUMBER> --json reviews,comments \
    --jq '{reviews: [.reviews[] | {author: .author.login, state: .state, body: .body, submittedAt: .submittedAt}], comments: [.comments[] | {author: .author.login, body: .body, createdAt: .createdAt}]}' 2>/dev/null
  sleep 120
done
```

Set `persistent: true`. Each poll emits one JSON blob — compare timestamps against your baseline to find new items only.

## Step 3: Categorize and act on new feedback

For each new item:

**Code change requested** (inline diff comment or `CHANGES_REQUESTED` review):
- Implement the change. Use the `green-commits` skill: run lint and tests, commit in small logical increments, push.
- After pushing, proceed to Step 4 to check the build.

**Question or general comment**:
- Reply with a top-level PR comment:
  ```bash
  gh pr comment <PR_NUMBER> --body "<response>"
  ```
- To reply to a specific review thread (inline):
  ```bash
  gh api repos/<owner>/<repo>/pulls/<pr>/comments/<comment_id>/replies \
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

- `SUCCESS` → green. Resume the feedback poll loop (Step 2).
- `FAILURE` → fetch the build log and diagnose. Fix via `green-commits`, push, recheck. If you cannot resolve the failure without user input, stop and report with full context.
- `PENDING` or active → GitHub lags. Extract the Cloud Build ID from the URL and use the `gcp-ci-watch` skill to monitor until terminal. Then handle the result as above.

## Exit conditions

Re-run `review_gate.py` after each new approval and after each green build, then:

- **`fullyReady: true`** (green CI + ≥2 human approvals + an owning-team member approved) → stop. Report: "PR #X ready — N approvals incl. `<team>` member `<who>`, CI green. Run `/merge-pr` when you're ready."
- **≥2 human approvals + green CI, but no owning-team member approved** (`ownerApproved: false`, or a specific team you care about is still missing) → **stop and ask.** Show the per-team breakdown and: "Approvals + CI are met, but `<team>` hasn't signed off. Merge anyway, or keep waiting for them?" Let the user decide — don't auto-declare ready.
- **< 2 human approvals** → keep polling. One approval (even from the owning team) is not enough.
- **A build failure** that can't be resolved without user input → report details and stop.
- **The user explicitly stops the watch.**

When the user starts the watch and names a team to wait for ("watch it and wait for autobots"), pass that as `--team autobots` so the gate requires *that* team specifically.

## Notes

- Never commit or push to master — all changes go to the feature branch.
- All code changes go through `green-commits` — run lint and tests before committing.
- Keep replies concise and focused on the reviewer's concern.
- If a comment is ambiguous, make a reasonable interpretation, implement it, and note your assumption in the reply.
