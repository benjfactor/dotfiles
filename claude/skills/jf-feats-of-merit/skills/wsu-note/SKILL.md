---
name: wsu-note
description: Capture a WSU-worthy moment to the weekly notes file. Use when the user says something worth recording for their Weekly Status Update. Appends a timestamped entry to ~/.claude/wsu/YYYY-WNN.md.
---

# WSU Note

Appends a timestamped note to the current week's notes file so it's available when `/wsu` compiles the Weekly Status Update.

## Steps

1. Get today's date and ISO week: `date '+%Y-%m-%d %H:%M'` and `date +%G-W%V`
2. Append to the notes file:
```bash
mkdir -p ~/.claude/wsu
echo "- $(date '+%Y-%m-%d %H:%M')  <note>" >> ~/.claude/wsu/$(date +%G-W%V).md
```
3. Confirm to the user: `Noted.`

That's it — no synthesis, no page updates. Just capture and confirm.

## Notes

- The note text should be taken verbatim from the user's message — don't rewrite it.
- If the user says "note that I…" or "remember that…", strip the preamble and capture the substance.
