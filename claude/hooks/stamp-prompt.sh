#!/usr/bin/env bash
# UserPromptSubmit: stamp each prompt with the current local date/time.
# UserPromptSubmit is one of only three hook events whose stdout Claude Code
# injects as visible context, so this is the only way to get a live per-message
# stamp. Side benefit: it keeps Claude's sense of "today" accurate in long or
# resumed sessions instead of frozen at session start.
set +e
cat >/dev/null 2>&1   # drain hook JSON on stdin; we don't need any of it
date '+⏱ %A %d %B %Y · %H:%M:%S %Z'
exit 0
