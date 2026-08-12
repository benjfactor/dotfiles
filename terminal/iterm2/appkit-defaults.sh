#!/usr/bin/env bash
# Apply the AppKit defaults iTerm2 will not keep in its own settings file.
#
# These five keys live in iTerm2's preference domain but are not iTerm2
# settings -- they are AppKit keys that macOS resolves per application. In
# managed mode (LoadPrefsFromCustomFolder, see setup.sh) iTerm2 rewrites
# com.googlecode.iterm2.plist itself and drops all five, because it only writes
# back keys it owns.
#
# So tracking them in that plist cannot work. It provisions a new machine
# exactly once, then iTerm2 saves and they vanish -- leaving a phantom deletion
# in the diff that sync.sh eventually commits away for good. Applied through
# `defaults` they live in the preference domain instead, which iTerm2 leaves
# alone: proof is that the tracked plist no longer contains them while
# `defaults read` still returns every one.
#
# Idempotent. --check reports without writing and exits non-zero if anything
# differs, which is how bootstrap.sh consumes it.

set -euo pipefail

DOMAIN=com.googlecode.iterm2
CHECK=false
[[ "${1:-}" == "--check" ]] && CHECK=true

# key | write-type | write-value | what `defaults read` returns for it
#
# That fourth column is not redundant: `-bool false` is stored as a boolean and
# reads back as "0", so comparing against "false" would rewrite the key on every
# run and never converge.
SETTINGS=(
  "AppleAntiAliasingThreshold|int|1|1"
  "ApplePressAndHoldEnabled|bool|false|0"
  "AppleScrollAnimationEnabled|int|0|0"
  "AppleSmoothFixedFontsSizeThreshold|int|1|1"
  "AppleWindowTabbingMode|string|manual|manual"
)

# What each buys, since the names give little away:
#   AppleAntiAliasingThreshold           antialias text at any size above 1px
#   ApplePressAndHoldEnabled=false       holding a key REPEATS it instead of
#                                        opening the accent picker -- the one
#                                        that actually matters in vim
#   AppleScrollAnimationEnabled=0        no smooth-scroll easing
#   AppleSmoothFixedFontsSizeThreshold   smooth fixed-width fonts above 1px
#   AppleWindowTabbingMode=manual        new windows are windows, not tabs

changed=0 already=0 differs=0

for entry in "${SETTINGS[@]}"; do
  IFS='|' read -r key type value expected <<<"$entry"
  current="$(defaults read "$DOMAIN" "$key" 2>/dev/null || echo '(unset)')"

  if [[ "$current" == "$expected" ]]; then
    echo "ok       $key = $current"
    already=$((already + 1))
    continue
  fi

  if $CHECK; then
    echo "DIFFERS  $key is '$current', want '$expected'"
    differs=$((differs + 1))
    continue
  fi

  defaults write "$DOMAIN" "$key" "-$type" "$value"
  echo "set      $key = $value  (was '$current')"
  changed=$((changed + 1))
done

echo
if $CHECK; then
  echo "already set: $already   differing: $differs"
  [[ $differs -eq 0 ]] || exit 1
  exit 0
fi

echo "set: $changed   already correct: $already"

# cfprefsd hands a running application a cached copy of its domain, so iTerm2
# will not observe these until it restarts. Nothing is lost either way -- the
# values are on disk -- but the behaviour changes only after a relaunch.
if pgrep -x iTerm2 >/dev/null; then
  echo
  echo "note: iTerm2 is running and caches its preferences, so these take"
  echo "      effect after you quit and reopen it. Re-run with --check"
  echo "      afterwards to confirm they survived the restart."
fi
