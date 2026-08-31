---
name: open-in-arc
description: Open a URL/link in the user's Arc browser (their browser of choice), as a tab in the existing window, optionally targeting a named Arc Space. Use whenever you need to open a link in a browser for this user — local dev servers, PRs, docs, preview URLs — or when the user says "open in Arc", "open this in my browser", or "open that link".
---

# Open in Arc

The user's browser of choice is **Arc** (`/Applications/Arc.app`). Always open links in Arc, not the system default.

Arc organizes tabs into **Spaces** (e.g. `Vendasta`, `PR reviews`, `yeti`, `Personal`) inside a single **window**. A new tab opens in the currently-active Space unless you focus a different one first.

## Helper script

Use the bundled script — it targets the user's *existing* window (never spawns a second one) and can focus a Space:

```bash
# Open a tab in the existing window, in the CURRENTLY ACTIVE space:
"${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/skills}/open-in-arc/open-in-arc.sh" "<url>"

# Open a tab in a SPECIFIC space (focuses it first, then opens):
"$HOME/.claude/skills/open-in-arc/open-in-arc.sh" "<url>" "PR reviews"

# List the user's current spaces:
"$HOME/.claude/skills/open-in-arc/open-in-arc.sh" --list-spaces
```

## Choosing the Space — ask when unspecified

Default behavior: **ask which Space** when the caller/user hasn't named one.

1. Run `open-in-arc.sh --list-spaces` to get the current Space titles.
2. Use `AskUserQuestion` to let the user pick a Space (include the active one as a sensible default).
3. Open with the chosen Space.

**Skip the question when the Space is already determined** — e.g. the user said "open it in my PR reviews space", or another skill calls this one with a specific Space (see `pr-studio-open-in-arc`). Don't ask redundantly.

## Direct AppleScript (if the script is unavailable)

```applescript
tell application "Arc"
  activate
  tell window 1
    repeat with s in spaces
      if (title of s) is "<SPACE>" then focus s   -- omit this loop to use the active space
    end repeat
    make new tab with properties {URL:"<URL>"}
  end tell
end tell
```

## Notes
- `make new tab` in `window 1` joins the user's existing session as the active tab — it does not open a new window.
- Plain `open -a Arc "<url>"` works but **cannot** target a Space — only use it as a fallback when no Arc window is open yet.
