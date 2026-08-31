---
name: open-tracked-pr
description: Open a draft PR for the current branch, prepend its Jira ticket link to the body, and show it in Arc. Use when the work has a Jira ticket and the branch is named after it (e.g. KAT-1309/simple-templates-nav). For a plain PR with no tracker link and no browser step, use open-pr instead.
---

# Open a tracked PR

A thin wrapper around a plain draft PR: it adds the two things that are specific
to how this person tracks work, and owns nothing else.

- **Opening the PR** belongs to `open-pr` — title derivation, repo template
  discovery, body structure, draft-only, no reviewers. Do not reimplement it.
- **Showing it in the browser** belongs to `open-in-arc`.
- **This skill** derives the ticket link and prepends it.

## Steps

1. **Derive the ticket** from the branch name before opening anything, so you
   know whether there is a link to add:
   ```bash
   git branch --show-current | grep -oE '[A-Z]+-[0-9]+' | head -1
   ```
   The pattern is deliberately the uppercase form — that is the branch
   convention, and it is the same pattern the `prepare-commit-msg` hook greps
   for. A lowercase ticket in the branch name yields nothing here, which is the
   correct signal that the branch was named wrongly: say so rather than
   guessing at the key.

2. **Open the draft PR** by handing off to `open-pr`. Let it build the title and
   body from the commits, diff and repo template.

3. **Prepend the ticket link** as the very first line of the body, above
   everything the template produced:
   ```
   [<KEY>](https://vendasta.jira.com/browse/<KEY>)
   ```
   ```bash
   BODY=$(gh pr view --json body --jq '.body')
   gh pr edit --body "[<KEY>](https://vendasta.jira.com/browse/<KEY>)

   ${BODY}"
   ```
   If step 1 found no ticket, skip this step entirely and say the PR was opened
   without a tracker link — do not invent a key or ask for one unprompted.

4. **Show it in the browser.** Ask `open-in-arc` to open the PR URL in the
   **`PR reviews`** Space (the Space is fixed — do not ask which one).

   This is best-effort. If it fails — Arc isn't running, or isn't installed —
   still report the URL. Never let the browser step block or undo a created PR.

5. **Report** the PR URL, whether a ticket link was added, and whether the
   browser step succeeded.

## Notes

- The PR stays a **draft** and gets no reviewers. Marking it ready and notifying
  reviewers is `pr-ready`'s job.
- Steps 3 and 4 are independent: a failure in one does not skip the other.
