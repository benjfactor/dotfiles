---
name: green-commits
description: When writing code (implementing a plan, task, or job), commit and push to a feature branch in small, green increments as you go—the user should not have to ask. Never commit or push to master. Use small, green commits after each logical step; do not do all work then commit once at the end. For refactors, use separate commits: add new → switch callers → remove old; push after each. If unsure whether to commit/push, ask. Defines "green" as full-repo build, tests, and lint passing.
---

# Committing and pushing when writing code

**When to use:** Whenever you **write code**, implement a plan, or do a multi-step task that produces code changes. Check **~/.claude/skills** (and the project’s `.claude/skills` if present) at the **start** of coding tasks so this skill is applied. The user should **not** have to remind you to use small commits or push.

**Default behavior:** Commit and **push** in **small, green increments as you go**—after each logical step or coherent change—not only when everything is finished. Do it by default; do not wait for the user to say "commit" or "push." If you're unsure whether they want commits/pushes (e.g. exploratory or WIP), ask.

## Default behavior

When you complete work (a plan, task, or multi-step job) that results in changes:

- **Commit and push to a feature branch** without being asked.
- Do **not** wait for the user to say "commit and push" or "push."

If it's ambiguous whether the work is "done" or whether they want it committed (e.g. exploratory or WIP), **ask**: e.g. "Should I commit and push this to the current branch?"

## Rules when committing and pushing

### 1. Never commit or push to master

- **Never** run `git push origin master` (or equivalent main branch).
- Only commit and push to **feature branches** (e.g. the branch the user is already on, or a branch they asked for).
- If the current branch is `master` or `main`, **always ask** which branch to use before pushing; do not switch branches without asking.

### 2. Small and green commits (as you go)

- **Small**: Prefer multiple logical commits (e.g. one per coherent change or per todo/step) rather than one big dump. Makes history and revert easier.
- **As you go**: When implementing a plan with multiple steps or todos, **commit and push after each logical step** (e.g. after each todo you complete), then continue. Do **not** make all edits first and commit only at the end.
- **Green**: Each commit (and the push) must be **green**. See "What green means" below.

### 2b. Refactors: add → switch → remove (separate commits)

When refactoring (e.g. replacing one implementation with another, or merging two activities into one):

1. **Add new path**: Add the new code and its tests. Run build/tests/lint. **Commit and push.**
2. **Switch callers**: Update callers to use the new path; keep the old code so the repo still builds. Run build/tests/lint. **Commit and push.**
3. **Remove old path**: Delete the old code and any now-unused tests. Run build/tests/lint. **Commit and push.**

Do **not** do all three in one commit. If the refactor is small (e.g. one file rename), one commit is fine; for multi-file "add new then remove old" work, use at least 2–3 commits with push after each.

### 3. Ask if unsure

- If you're not sure the user wants this work committed and pushed (e.g. they said "just explore" or "draft only"), ask: "Do you want me to commit and push this to \<branch\>?"

## What "green" means

**Green** = the **full repository** passes:

1. **Build** – e.g. `go build ./...` (often implied when running tests or lint).
2. **Tests** – full test suite (e.g. `go test ./...` or whatever the repo/CI uses).
3. **Lint** – the repo’s linter (e.g. golangci-lint, `go vet`, or project-specific). Same bar as CI.

You don't need to run full CI; running build, tests, and lint locally is enough. Don't commit or push until the repo is green (or the user explicitly accepts otherwise).

**Scope:** The **entire repo** must pass. If the repo has pre-existing failures elsewhere, the push is not green until those are fixed or the user says to proceed anyway.

**Rare case – master is broken:** If the main branch itself doesn't pass, that’s usually a separate fix (own PR, coordination with others). Don’t block indefinitely; note it and let the user decide.

## Where this skill lives

This skill is in **~/.claude/skills/green-commits/**. For a full list of the user’s preferences (including this one), see **~/.claude/skills/README.md**. In new chats, check that file at the start of coding tasks so you apply these rules without being reminded.

## Example flow

```bash
# After completing work, before committing:
go build ./...
go test ./... -count=1
# Run repo linter (e.g. golangci-lint, make lint, or go vet ./...)

# If all pass, small commits to current (feature) branch:
git add <files>
git commit -m "short message"
# Repeat for next logical chunk if needed, re-running tests/lint as needed.

# Push to the feature branch only (never master):
git push origin <feature-branch>
```

## Audience

This skill is for the **AI only** – default instructions for when and how to commit and push after completing work.
