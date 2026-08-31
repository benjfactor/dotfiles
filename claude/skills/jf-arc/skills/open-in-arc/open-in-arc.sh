#!/usr/bin/env bash
# open-in-arc.sh — open a URL as a tab in the user's EXISTING Arc window,
# optionally focusing a named Arc Space first.
#
# Usage:
#   open-in-arc.sh <url> [space]   Open <url> as a new tab. If [space] is given,
#                                  focus that Space first so the tab lands there.
#   open-in-arc.sh --list-spaces   Print available Space titles (one per line).
#
# Notes:
#   - Targets window 1 (the user's existing window) — never spawns a second window
#     when one already exists, so the tab joins the current session.
#   - Plain `open -a Arc <url>` cannot target a Space; that's why this uses AppleScript.
set -euo pipefail

if [[ "${1:-}" == "--list-spaces" ]]; then
  osascript -e 'tell application "Arc" to get title of every space of window 1' \
    | tr ',' '\n' | sed 's/^[[:space:]]*//'
  exit 0
fi

url="${1:?usage: open-in-arc.sh <url> [space]   (or --list-spaces)}"
space="${2:-}"

# If Arc has no window yet, fall back to a plain open (creates one; can't target a Space).
win_count="$(osascript -e 'tell application "Arc" to count windows' 2>/dev/null || echo 0)"
if [[ "${win_count}" -eq 0 ]]; then
  open -a Arc "${url}"
  exit 0
fi

if [[ -n "${space}" ]]; then
  osascript - "${url}" "${space}" <<'APPLESCRIPT'
on run argv
  set theURL to item 1 of argv
  set theSpace to item 2 of argv
  tell application "Arc"
    activate
    tell window 1
      repeat with s in spaces
        if (title of s) is theSpace then focus s
      end repeat
      make new tab with properties {URL:theURL}
    end tell
  end tell
end run
APPLESCRIPT
else
  osascript - "${url}" <<'APPLESCRIPT'
on run argv
  set theURL to item 1 of argv
  tell application "Arc"
    activate
    tell window 1 to make new tab with properties {URL:theURL}
  end tell
end run
APPLESCRIPT
fi
