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
SCRIPT="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/skills/jf-gchat}/skills/send-gchat-message/scripts/send_gchat.py"

# Post to one or more teams/spaces (mix freely):
python3 "$SCRIPT" --targets "phoenix,marina" --message "heads up: ..."

# GitHub team handle form, body from a file (use a file for multi-line/markdown):
python3 "$SCRIPT" --targets "@vendasta/phoenix" --message-file /tmp/msg.md

# Just resolve targets to space IDs without sending (useful for a review gate):
python3 "$SCRIPT" --targets "phoenix,some-new-team" --resolve-only

# Add @mentions by person slug (see PEOPLE in send_gchat.py) or raw user ID:
python3 "$SCRIPT" --targets "meerkats" --message "PR ready" --mention "craig,daniel"
python3 "$SCRIPT" --targets "meerkats" --message "product question" --mention "will"

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

### Calling it from another skill

A skill in **another plugin** invokes this skill and lets it do the sending. It
must not import `send_gchat` or shell out to the script: the module only exists
inside this plugin's install tree, and that path is not a stable address from
outside it. Describe the targets and the message; this skill owns the rest.

A skill **in this plugin** can import the module directly, resolving it from the
plugin root the harness supplies:

```python
import sys, os
sys.path.insert(0, os.path.join(os.environ['CLAUDE_PLUGIN_ROOT'], 'skills/send-gchat-message/scripts'))
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
- Known people are mapped in `PEOPLE` in `send_gchat.py` (`craig`, `daniel`, `will`)
  and can be passed to `--mention` by slug; raw `users/...` IDs still work. An
  unknown slug is a hard error rather than a silently broken mention.
- Resolving an arbitrary person (e.g. GitHub username → Chat user ID) is still not
  supported. To add someone, @-mention them once in Chat and read the ID from
  `annotations[].userMention.user.name` on that message, then add it to `PEOPLE`.
