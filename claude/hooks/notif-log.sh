#!/bin/bash
# Diagnostic: append every Notification hook payload to a log so we can see
# the exact notification type Claude Code emits for each "needs input" moment.
# Non-invasive — does not play sound, just records. Remove once diagnosed.
INPUT=$(cat)
printf '%s  %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$INPUT" >> "$HOME/.claude/notification-debug.log"
exit 0
