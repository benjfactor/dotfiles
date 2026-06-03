---
name: pr-studio-open-in-arc
description: After the vendasta pr-studio review server starts and prints its URL, automatically open that URL in the user's Arc browser in the "PR reviews" Space. Use whenever the pr-studio (vendasta-pr-studio:pr-studio) server is ready / has reported its URL, or the user runs /pr-studio, so they don't have to open the link by hand.
---

# Open PR Studio in Arc

When the **vendasta pr-studio** review server is ready, open its URL in Arc automatically — the user should not have to click the link.

## When this fires

During the `vendasta-pr-studio:pr-studio` workflow, `start_server.py` prints JSON like `{"url": "http://localhost:PORT/...", "session_dir": "...", "pid": ...}` once the server is listening. **That printed `url` is the ready signal.** As soon as you've parsed it, open it in Arc.

## What to do

Open the parsed `url` in Arc, in the **`PR reviews`** Space. Use the [`open-in-arc`](../open-in-arc/SKILL.md) skill — it handles window/Space targeting:

```bash
"$HOME/.claude/skills/open-in-arc/open-in-arc.sh" "<url>" "PR reviews"
```

The Space is fixed (`PR reviews`), so **do not ask** which Space — that's the whole point of this skill.

Then still tell the user the URL (and the `<url>/diagram` link) in text, as the pr-studio workflow normally does, so they have it even if focus didn't switch.

## Notes
- Tab opens in the user's existing Arc window — no new window.
- If Arc has no window open, `open-in-arc.sh` falls back to a plain launch (the tab won't land in `PR reviews`, but the URL still opens).
- This only opens the **main review URL**. The diagram page (`<url>/diagram`) is for the user to open themselves unless they ask.
