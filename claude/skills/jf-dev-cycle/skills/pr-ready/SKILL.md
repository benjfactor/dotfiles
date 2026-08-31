---
name: pr-ready
description: Mark a draft PR as ready for review, tag the meerkats team handle in the PR description, and post in the team Google Chat PR channel. Use when the user says the PR is ready, wants to request review, or wants to move out of draft.
---

# Mark PR Ready

## Steps

1. **Get PR details** — run in parallel:
   ```bash
   gh pr view --json number,url,title,isDraft
   git branch --show-current
   ```

2. **Mark as ready** (if still a draft):
   ```bash
   gh pr ready
   ```

3. **Tag the meerkats team handle in the PR description.** Do NOT request the team as a formal GitHub reviewer (`--add-reviewer`) — the `@vendasta/meerkats` handle in the body is the signal. Only append it if it isn't already present (the description may already carry it):
   ```bash
   BODY=$(gh pr view --json body --jq '.body')
   case "$BODY" in
     *"@vendasta/meerkats"*) echo "already tagged" ;;
     *) gh pr edit --body "${BODY}

@vendasta/meerkats" ;;
   esac
   ```

4. **Post in the personal team PR channel** — hand off to `notify-pr-channels`,
   which owns the message shape, the channel list and the Craig/Daniel mentions.
   Don't assemble the Chat post here.

5. **Report back** with the PR URL and confirmation that the team handle is tagged and the Chat post went out.

## Notes

- If the PR is already out of draft, skip step 2 — still ensure the body tag (step 3) and post.
- Do NOT post in the snapcats channel for `pr-ready` — that's only for build notifications via `notify-pr-channels`.
- Chat posting uses interactive OAuth rather than a webhook, so it can be unavailable in headless contexts — `notify-pr-channels` documents the auth path.
