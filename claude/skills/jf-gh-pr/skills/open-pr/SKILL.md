---
name: open-pr
description: Open a draft pull request for the current branch. Use when the user wants to create a PR, open a pull request, or submit work for review. PRs are always created as drafts.
---

# Open a draft PR

Always create PRs as **drafts**. Do not add reviewers — that happens at the `pr-ready` stage.

## Steps

1. **Gather context** — run in parallel:
   - `git log origin/master..HEAD --oneline` — commits going into the PR
   - `git diff origin/master...HEAD --stat` — files changed
   - `git branch --show-current` — branch name
   - Look for a repo PR template (check in this priority order):
     1. `.github/PULL_REQUEST_TEMPLATE.md`
     2. `.github/pull_request_template.md`
     3. `docs/PULL_REQUEST_TEMPLATE.md`
     4. `docs/pull_request_template.md`
     5. `PULL_REQUEST_TEMPLATE.md`
     6. Files inside `.github/PULL_REQUEST_TEMPLATE/` or `docs/PULL_REQUEST_TEMPLATE/`

2. **Derive the PR title** from the branch name or top commit. Keep it under 70 characters. Follow Conventional Commits style (same as the commit-preferences skill). The Jira ticket number belongs in the body, not the title.

3. **Build the PR body:**
   - **If a template file exists:** read it and fill in its sections based on the commits and diff. Keep all section headings from the template as-is. Remove HTML comments (`<!-- ... -->`).
   - **If no template exists:** use this fallback structure:

```
## Summary

- <bullet points — what was added/changed>

## Why

<motivation>

## How to test

1. <step>
```

   - Either way, prepend a Jira link as the **very first line** if a ticket can be inferred (e.g. branch `KAT-1309/foo` → `[KAT-1309](https://vendasta.jira.com/browse/KAT-1309)`). Omit if no ticket.
   - Always append `🤖 Generated with [Claude Code](https://claude.com/claude-code)` at the end.
   - Jira base URL: `https://vendasta.jira.com/browse/`

4. **Create the draft PR:**
```bash
gh pr create --draft --title "<title>" --body "$(cat <<'EOF'
<body>
EOF
)"
```

5. **Return the PR URL.**

6. **Open the PR in Arc.** Use the `open-in-arc` skill to open the new PR in the **`PR reviews`** Space (the Space is fixed — do not ask):
   ```bash
   "$HOME/.claude/skills/open-in-arc/open-in-arc.sh" "<pr-url>" "PR reviews"
   ```
   This is best-effort: if it fails (e.g. Arc isn't running), still report the URL — never block PR creation on it.

## Notes

- Never add `--reviewer` here — reviewers are added by the `pr-ready` skill.
- If the branch has no upstream yet, push first: `git push -u origin <branch>`.
