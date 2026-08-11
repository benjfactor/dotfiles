#!/usr/bin/env bash
# Capture this machine's current iTerm2 settings into the repo, then commit.
#
# Run this on the SOURCE machine before you go set things up on another one,
# so the destination picks up your latest tweaks rather than a stale snapshot.
#
# Usage:
#   ./sync.sh          # write + show diff, then prompt to commit
#   ./sync.sh --push   # same, but also push when the commit succeeds

set -euo pipefail

FOLDER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLIST="$FOLDER/com.googlecode.iterm2.plist"
PUSH=false
[[ "${1:-}" == "--push" ]] && PUSH=true

# iTerm2 only flushes its in-memory settings on quit (or when you hit
# "Save Settings to Folder"). If it's running, what `defaults export` sees may
# lag whatever you just changed in the UI.
if pgrep -x iTerm2 >/dev/null; then
  echo "!! iTerm2 is running -- settings changed in this session may not be"
  echo "   captured yet. For a guaranteed-complete snapshot, either:"
  echo "     - quit iTerm2 (Cmd-Q) and re-run this, or"
  echo "     - Settings -> General -> Settings -> 'Save Settings to Folder' first."
  echo
  read -r -p "Continue anyway? [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]] || exit 1
fi

# Export the live prefs, drop machine-local keys, write readable XML.
# iTerm2 prefixes anything intentionally machine-specific with "NoSync"
# (recent hosts, per-window state, one-off "don't warn me again" flags).
# Those must not travel between machines.
#
# The binary1 hop is not decoration: iTerm2 key bindings contain raw control
# characters that Apple's plist writer emits happily but Python's XML parser
# rejects. Reading/writing binary sidesteps XML entirely, and plutil does the
# final conversion using Apple's own (lenient) writer.
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

defaults export com.googlecode.iterm2 - | plutil -convert binary1 -o "$TMP" -
python3 -c '
import plistlib, sys
p = sys.argv[1]
with open(p, "rb") as f:
    data = plistlib.load(f)
kept = {k: v for k, v in data.items() if not k.startswith("NoSync")}
sys.stderr.write(f"exported {len(kept)} keys (dropped {len(data)-len(kept)} machine-local NoSync* keys)\n")
with open(p, "wb") as f:
    plistlib.dump(kept, f, fmt=plistlib.FMT_BINARY, sort_keys=True)
' "$TMP"
plutil -convert xml1 -o "$PLIST" "$TMP"
plutil -lint "$PLIST" >/dev/null

cd "$FOLDER"
# --porcelain rather than `git diff --quiet` so a not-yet-tracked plist
# (first run on a fresh clone) still registers as something to commit.
if [[ -z "$(git status --porcelain -- "$PLIST")" ]]; then
  echo "no changes -- repo already matches this machine."
  exit 0
fi

echo
echo "--- changed settings ---"
git diff --stat -- "$PLIST" || true
echo
read -r -p "Commit this? [y/N] " reply
if [[ "$reply" =~ ^[Yy]$ ]]; then
  git add "$PLIST"
  git commit -m "chore(iterm2): sync settings from $(scutil --get ComputerName 2>/dev/null || hostname -s)"
  $PUSH && git push
  echo "committed."
else
  echo "left uncommitted."
fi
