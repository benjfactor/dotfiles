---
name: send-gchat-message
description: Send a message to one or more Google Chat spaces, resolving raw space IDs or team identifiers (@vendasta/<team> or a team slug) to space IDs. Low-level primitive used by notify-pr-channels and other skills that need to post to Chat. Use when you need to deliver an arbitrary message to a Chat channel/team, or when another skill asks to "post to the team's channel".
---

# Send Google Chat Message

A small, reusable primitive for posting a message to Google Chat. It owns
**auth** and **channel resolution** so callers don't reimplement either.
`notify-pr-channels` delegates its actual sending here; `regression-triage`
uses it to alert the team that owns a buggy PR.

## What it does

- Resolves each target to a space ID:
  - **raw space ID** (e.g. `AAAAIj8WMWc`) → used as-is
  - **team slug** (`phoenix`) or **GitHub team handle** (`@vendasta/phoenix`) → looked up in `TEAM_CHANNELS`
  - **unmapped team** → live `spaces.list` fallback matching a space named `Team: <Name>`
- Posts the same message text to every resolved target.
- Optionally appends `<users/...>` mentions.

## Usage

```bash
SCRIPT=~/.claude/skills/send-gchat-message/scripts/send_gchat.py

# Post to one or more teams/spaces (mix freely):
python3 "$SCRIPT" --targets "phoenix,marina" --message "heads up: ..."

# GitHub team handle form, body from a file (use a file for multi-line/markdown):
python3 "$SCRIPT" --targets "@vendasta/phoenix" --message-file /tmp/msg.md

# Just resolve targets to space IDs without sending (useful for a review gate):
python3 "$SCRIPT" --targets "phoenix,some-new-team" --resolve-only

# Add @mentions by user ID:
python3 "$SCRIPT" --targets "meerkats" --message "PR ready" \
  --mention "users/101609381686230694100,users/107059066615888383168"

# Reply INTO an existing thread (pass a Chat URL, a full spaces/.../threads/... name,
# or a bare thread id). Requires exactly one --targets space:
python3 "$SCRIPT" --targets "AAAACOXIXAM" --message-file /tmp/msg.md \
  --thread "https://chat.google.com/room/AAAACOXIXAM/ZpNybdmNiAw/ZpNybdmNiAw"
```

Always write multi-line / markdown messages to a file and use `--message-file`
(shell heredoc quoting is fragile).

## Threading

`--thread` replies into an existing thread. Accepts a **Chat web URL**, a full
`spaces/<space>/threads/<thread>` name, or a **bare thread id** (the web-URL thread
segment works directly as the REST thread id). It needs exactly one resolved
`--targets` space, and the space must match the thread's.

By default a thread that can't be found **fails loudly** (`REPLY_MESSAGE_OR_FAIL`)
so a wrong id never leaves a stray top-level message in the channel. Pass
`--thread-new-ok` to fall back to starting a new thread instead
(`REPLY_MESSAGE_FALLBACK_TO_NEW_THREAD`). Importers can thread too:
`send_gchat.post_message(token, sid, text, thread_name="spaces/<s>/threads/<t>")`,
and `send_gchat.parse_thread_ref(url_or_name_or_id, default_space=sid)` resolves a
reference to `(space, thread_name)`.

## Resolution & the channel map

`TEAM_CHANNELS` in `scripts/send_gchat.py` is the **single source of truth** for
team→space IDs. When a team isn't in the map, the script discovers it live by
listing the authenticated user's spaces and matching `displayName == "Team: <slug>"`.
When you discover a new team this way, paste its `slug: space_id` into
`TEAM_CHANNELS` so future runs skip the lookup.

Importing from another skill:

```python
import sys, os
sys.path.insert(0, os.path.expanduser('~/.claude/skills/send-gchat-message/scripts'))
import send_gchat
token = send_gchat.get_access_token()
sid, how = send_gchat.resolve_target('@vendasta/phoenix', token)
send_gchat.post_message(token, sid, "hello")
```

## Auth

OAuth via GCP secret `google-chat-oauth-client-secret` (project `repcore-prod`),
cached refresh token at `~/.config/google-chat-cli/credentials-rw.json`. No
webhook URLs. Interactive-only auth means this may be unavailable in fully
headless/cron contexts.

## Notes

- `--resolve-only` is the right call before an outward-facing send when you want
  to confirm targets in a review gate first.
- Resolving an individual **person** (GitHub username → Chat user ID) is not
  supported — only teams/channels. Pass known `users/...` IDs via `--mention`.
