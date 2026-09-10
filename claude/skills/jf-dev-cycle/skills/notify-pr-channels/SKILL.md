---
name: notify-pr-channels
description: Post PR build/ready notifications to Google Chat channels. Always posts to personal team channel (@Craig and @Daniel). Also auto-detects @vendasta/<team> mentions in the PR body and posts to matching external team channels (snapcats, snack-ops, etc.).
---

# Notify PR Channels

When a build passes or a PR is ready, always post to the personal team channel,
then read the PR body for `@vendasta/<team>` mentions and post to any matching
external team channels.

This skill owns the **PR-specific message shape and target selection**. Chat
auth, channel resolution and delivery belong to `jf-gchat:send-gchat-message`;
invoke that skill rather than reaching for its script.

## Channels

| Channel | Google Chat URL | Type |
|---|---|---|
| Personal team PR | https://chat.google.com/room/AAAAIj8WMWc?cls=7 | Always posted — @Craig and @Daniel |
| Snapcats | https://chat.google.com/room/AAAAAHjNt6A?cls=7 | External — posted when `@vendasta/snapcats` in PR body |
| SnackOps | https://chat.google.com/room/AAAAjno8gDs?cls=7 | External — posted when `@vendasta/snack-ops` in PR body |
| Phoenix | https://chat.google.com/room/AAAAN_I9hG8?cls=7 | External — posted when `@vendasta/phoenix` in PR body |
| Autobots | https://chat.google.com/room/AAAAWOyaLAg?cls=7 | External — posted when `@vendasta/autobots` in PR body |
| NP-Easy (CRMaaS) | https://chat.google.com/room/AAAAqGa-a8I?cls=7 | External — posted when `@vendasta/np-easy` in PR body |
| Warped Tour | https://chat.google.com/room/AAQANVVa_PA?cls=7 | External — posted when `@vendasta/warped-tour` in PR body |
| Marketplace Institute of Technology | https://chat.google.com/room/AAAACpnkUis?cls=7 | External — posted when `@vendasta/marketplace-institute-of-technology` in PR body |

The table above is a convenience listing. The authoritative team→space map lives
with the Chat-sending capability, which also resolves an unmapped team live by
listing spaces for one named `Team: <Name>` — so a missing entry degrades to a
lookup rather than a failure. To add a team permanently, record its slug and
space ID there.

## When to notify

Only run this skill after the PR is marked ready for review. Do not notify
channels while the PR is still a draft — reviewers shouldn't be pinged until the
work is ready for their attention. If the PR stays as a draft, remind the user to
run this step when marking it ready.

## Steps

1. **Read the PR.** Title and URL for the message, body for team mentions:
   ```bash
   PR_URL=$(gh pr view --json url --jq '.url')
   PR_TITLE=$(gh pr view --json title --jq '.title')
   PR_BODY=$(gh pr view --json body --jq '.body')
   ```

2. **Build the message.** One line of title, one line of URL:
   ```
   <PR_TITLE>
   <PR_URL>
   ```
   If the caller supplied a reason for posting (for example "Found during deploy
   monitor for a different PR."), prepend it as a first line on **every** message.

3. **Post to the personal team channel**, always, mentioning Craig and Daniel.
   Target space `AAAAIj8WMWc`, mentions `craig,daniel`.

4. **Find external teams.** Extract every `@vendasta/<slug>` from `PR_BODY`.

5. **Resolve those slugs to space IDs before posting**, and drop any that
   resolve to a space already being posted to — including the personal team
   channel itself. Deduplicate on the **resolved space ID, not the slug**: a
   team whose channel *is* the personal team channel (meerkats) would otherwise
   be posted to twice, and two different slugs can resolve to one space. The
   Chat-sending capability exposes a resolve-without-sending mode for exactly
   this check.

6. **Post to each remaining distinct space** with the same message, without the
   Craig/Daniel mentions — those are for the personal channel only.

7. **Report** which channels were posted to, and which slugs were skipped and
   why (unresolved, or already covered by another target).

Write multi-line message bodies to a file and pass the file, rather than
inlining them in a shell command — heredoc quoting is fragile.

## Notes

- Craig and Daniel are referred to by their person slugs (`craig`, `daniel`),
  which the Chat-sending capability maps to user IDs. Don't hardcode raw
  `users/...` IDs here.
- Auth is interactive OAuth, owned by the Chat-sending capability, so this may
  be unavailable in fully headless or cron contexts.
