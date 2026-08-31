---
name: git-worktree-jira-branch
description: When starting new work, create a new git worktree with kebab-case name and a JIRA-style branch from origin/master. Use when the user wants a new worktree, new branch, or mentions JIRA ticket workflow.
---

# Git worktree + JIRA-style branch

Use this skill when starting new work that should live in its own worktree and branch.

## Naming convention

- **Worktree path (all lowercase kebab):** `{repo}-{jira-ticket-lower}-{work-description}` — the entire path must be **lowercase** (ticket id lower too).
  - ✅ Correct: `email-kat-1376-use-immutable-ids`, `email-kat-1384-outlook-reply-is-contact`
  - ❌ Wrong: `email-KAT-1376-use-immutable-ids`, `email-KAT-1384-outlook-reply-is-contact` (uppercase ticket in path)
- **Branch (uppercase ticket, slash before the description):** `{JIRA-TICKET}/{work-description}` — the **uppercase ticket is the part the hook needs**: `prepare-commit-msg` greps `[A-Z]+-[0-9]+` off the branch name to append the Jira ID, so a lowercase ticket matches nothing and every commit silently gets no ID. The slash is house style, not a hook requirement.
  - ✅ Correct: `KAT-1376/use-immutable-ids`, `KAT-1384/outlook-reply-is-contact`
  - ❌ Wrong: `kat-1376/use-immutable-ids`, `kat-1384/outlook-reply-is-contact` (lowercase ticket — hook appends no Jira ID)
  - ⚠️ Works, but off-style: `KAT-1376-use-immutable-ids` (the hook accepts it; prefer the slash)
- **Base:** Create the branch from `origin/master`. The branch must **not** track `origin/master`; it should track `origin/{TICKET}/{description}` so pushes go to the feature branch (see Remote tracking below).

## When to use

- User asks for a new worktree or branch for a JIRA ticket.
- User says they like "new work" in a new worktree with kebab-style name and JIRA-style branch.
- Starting implementation for a ticket (e.g. KAT-1376, KAT-1318).

## Instructions

1. **Resolve repo and ticket:** From context, get the repo name (e.g. `email`), the JIRA ticket (e.g. `KAT-1376`), and a short work description (e.g. `use-immutable-ids`). Use kebab-case for the description.

2. **Worktree path (all lowercase):** Build the worktree path as `{repo}-{ticket-lower}-{description}` and place it as a sibling of the main repo. Use **lowercase** for the ticket (e.g. `kat-1376`, not `KAT-1376`).
   - Example: repo at `/Users/you/Projects/email` → worktree at `/Users/you/Projects/email-kat-1376-use-immutable-ids`
   - ❌ Wrong: `../email-KAT-1376-use-immutable-ids` (uppercase in path)

3. **Branch name:** Always `{TICKET}/{description}` — ticket **uppercase**, because the hook greps `[A-Z]+-[0-9]+` and a lowercase ticket silently yields no Jira ID. Slash before the description is house style, not a hook requirement.
   - Example: `KAT-1376/use-immutable-ids`, `KAT-1318/create-trkd-msg-evnt`

4. **Create worktree and branch:** Use the slash-form branch name and a **lowercase** worktree path. Do **not** create the branch with a hyphenated name and rename later. Do **not** use uppercase in the worktree path (e.g. use `email-kat-1384-outlook-reply-is-contact`, not `email-KAT-1384-outlook-reply-is-contact`).
   ```bash
   cd /path/to/repo
   git fetch origin
   # worktree-name must be all lowercase, e.g. email-kat-1384-outlook-reply-is-contact
   git worktree add ../{worktree-name} -b {TICKET}/{description} origin/master
   ```
   This **sets the new branch's upstream to `origin/master`** — `branch.autoSetupMerge` defaults to tracking when you branch from a remote-tracking ref. Unset it before doing any work: `git -C ../{worktree-name} branch --unset-upstream`. With `push.default = simple` a bare `git push` refuses rather than pushing to master, but it suggests `git push origin HEAD:master` — do not paste that. The remote branch is created on first push (step 5).

5. **Remote tracking (first push):** The worktree branch should track `origin/{TICKET}/{description}`, not `origin/master`. Do **not** try to set it in the create step (the remote branch does not exist yet) — just unset the `origin/master` upstream git added, per step 4. Tell the user: on first push from the worktree, run:
   ```bash
   git push -u origin '{TICKET}/{description}'
   ```
   That creates the remote branch and sets tracking. After that, plain `git push` and `git pull` use the feature branch.

6. **Confirm:** Tell the user the worktree path, branch name (slash form), and the first-push command above.

## Examples

| Repo  | Ticket   | Description        | Worktree path                          | Branch                 |
|-------|----------|--------------------|----------------------------------------|------------------------|
| email | KAT-1376 | use-immutable-ids | `../email-kat-1376-use-immutable-ids`  | `KAT-1376/use-immutable-ids` |
| email | KAT-1318 | hawt-fix           | `../email-kat-1318-hawt-fix`           | `KAT-1318/hawt-fix`    |

## Fixing an existing worktree

**Wrong branch name or tracking:** If the worktree was created with the wrong branch name (e.g. hyphenated) or the branch is tracking `origin/master`:

1. **From the worktree directory:** Fetch latest, then rename the branch to the slash form and reset to `origin/master`:
   ```bash
   cd /path/to/worktree
   git fetch origin
   git branch -m {old-name} '{TICKET}/{description}'
   git reset --hard origin/master
   ```
2. **First push:** Run `git push -u origin '{TICKET}/{description}'` to create the remote branch and set tracking. Do not set upstream before pushing (the remote branch does not exist yet).

**Wrong worktree path case (e.g. uppercase):** If the worktree folder was created with uppercase (e.g. `email-KAT-1384-outlook-reply-is-contact`) and should be lowercase:

1. From the main repo, remove the worktree (this deletes the worktree directory): `git worktree remove /path/to/email-KAT-1384-...`
2. Add the worktree again at the **lowercase** path: `git worktree add ../email-kat-1384-outlook-reply-is-contact 'KAT-1384/outlook-reply-is-contact'`
3. If you had uncommitted changes, they were lost when the worktree was removed; commit or stash before removing.

## References

- [Cursor docs: Skill directories](https://cursor.com/docs/context/skills#skill-directories) — skills load from a user-level skills directory in either Cursor or Claude Code.
