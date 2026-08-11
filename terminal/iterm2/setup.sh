#!/usr/bin/env bash
# Point THIS machine at the iTerm2 settings stored in this repo.
# Run once per machine. Safe to re-run.
#
# See README.md for the why (short version: never symlink the plist, cfprefsd
# will clobber it -- iTerm2's "custom folder" feature is the supported path).

set -euo pipefail

FOLDER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLIST="$FOLDER/com.googlecode.iterm2.plist"
LOCAL_PLIST="$HOME/Library/Preferences/com.googlecode.iterm2.plist"

if [[ ! -f "$PLIST" ]]; then
  echo "error: $PLIST not found. Wrong folder, or nothing has been synced yet." >&2
  exit 1
fi

if pgrep -x iTerm2 >/dev/null; then
  echo "!! iTerm2 is running."
  echo "   It rewrites its prefs on quit, which would undo this setup."
  echo "   Quit iTerm2 completely (Cmd-Q), then re-run this script from"
  echo "   Terminal.app or a plain shell."
  exit 1
fi

# Back up whatever this machine already had, so enabling the custom folder
# is reversible. iTerm2 will load from the repo folder after this.
if [[ -f "$LOCAL_PLIST" ]]; then
  BACKUP="$LOCAL_PLIST.backup-$(date +%Y%m%d-%H%M%S)"
  cp "$LOCAL_PLIST" "$BACKUP"
  echo "backed up existing local prefs -> $BACKUP"
fi

defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$FOLDER"
defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true

echo
echo "done. iTerm2 will load settings from:"
echo "  $FOLDER"
echo
echo "Next steps (manual, one time):"
echo "  1. Open iTerm2."
echo "  2. Settings -> General -> Settings tab."
echo "  3. Confirm 'Load settings from a custom folder or URL' is checked and"
echo "     points at the path above."
echo "  4. Set 'Save changes' to 'Automatically' so edits flow back to the repo."
echo
echo "Then commit any changes with: ./sync.sh"
