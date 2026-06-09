---
name: notify-pr-channels
description: Post PR build/ready notifications to Google Chat channels. Always posts to personal team channel (@Craig and @Daniel). Also auto-detects @vendasta/<team> mentions in the PR body and posts to matching external team channels (snapcats, snack-ops, etc.).
---

# Notify PR Channels

When a build passes or a PR is ready, the script always posts to the personal team channel, then reads the PR body for `@vendasta/<team>` mentions and posts to any matching external team channels.

## Channels

| Channel | Google Chat URL | Type |
|---|---|---|
| Personal team PR | https://chat.google.com/room/AAAAIj8WMWc?cls=7 | Always posted — @Craig and @Daniel |
| Snapcats | https://chat.google.com/room/AAAAAHjNt6A?cls=7 | External — posted when `@vendasta/snapcats` in PR body |
| SnackOps | https://chat.google.com/room/AAAAjno8gDs?cls=7 | External — posted when `@vendasta/snack-ops` in PR body |
| Phoenix | https://chat.google.com/room/AAAAN_I9hG8?cls=7 | External — posted when `@vendasta/phoenix` in PR body |
| Autobots | https://chat.google.com/room/AAAAWOyaLAg?cls=7 | External — posted when `@vendasta/autobots` in PR body |

To add a new external team: add their slug → space ID to `TEAM_CHANNELS` in `scripts/chat_post.py`.

## When to notify

Only run this skill after the PR is marked ready for review. Do not notify channels while the PR is still a draft — reviewers shouldn't be pinged until the work is ready for their attention. If the PR stays as a draft, remind the user to run this step when marking it ready.

## Sending messages

Use the bundled script — no webhook URLs needed, auth is handled via OAuth:

```bash
python3 ~/.claude/skills/notify-pr-channels/scripts/chat_post.py "<PR_URL>" "<PR_TITLE>"
```

The script:
- Always posts to the personal team PR channel with @Craig Kumick and @Daniel Ngo mentions
- Reads the PR body via `gh pr view` and posts to any external team channels whose `@vendasta/<slug>` appears in the body
- Auth: refreshes OAuth token via GCP secret `google-chat-oauth-client-secret` (repcore-prod), cached at `~/.config/google-chat-cli/credentials-rw.json`

### Known user IDs (hardcoded in script)
- Craig Kumick: `users/101609381686230694100`
- Daniel Ngo: `users/107059066615888383168`

## Steps

1. Get the PR URL and title: `gh pr view --json url,title,number`
2. Run the script:
   ```bash
   PR_URL=$(gh pr view --json url --jq '.url')
   PR_TITLE=$(gh pr view --json title --jq '.title')
   python3 ~/.claude/skills/notify-pr-channels/scripts/chat_post.py "$PR_URL" "$PR_TITLE"
   ```
