---
name: plan-implementation-commits
description: When implementing a plan, RFC, or multi-step task, make small logical commits and push to the feature branch as you go. Do not finish all work then commit once at the end. Apply after each step or todo; see green-commits for full rules.
---

# Plan implementation: small commits and push

**When to use:** Whenever you are **implementing a plan**, RFC, sprint task list, or any multi-step coding job. Check this skill at the **start** of plan execution so you commit and push correctly.

## Rule

- **Small commits:** After each **logical step** (e.g. one todo, one coherent change, or one phase like "add new package" / "wire callers" / "remove old"), create a **commit** with a clear message.
- **Push as you go:** **Push** to the **current feature branch** after each commit (or after each small batch of related commits). Do **not** leave all changes uncommitted until the end.
- **Do not:** Implement the entire plan, then make one big commit and push at the end.

## Refactors (add → switch → remove)

For refactors that replace old code with new:

1. **Add new:** Add new code and tests. Build + test + lint. **Commit and push.**
2. **Switch callers:** Update call sites to use the new code; repo still builds. **Commit and push.**
3. **Remove old:** Delete old code. **Commit and push.**

Use at least 2–3 commits; never do add + switch + remove in a single commit for multi-file refactors.

## Relation to other skills

- **green-commits** (~/.claude/skills/green-commits): Full rules (never push to master, green = build + tests + lint, ask if unsure). This skill is the **plan-specific** reminder to do small commits and push **during** implementation.
- **commit-preferences**: Use when writing commit messages (Conventional Commits, scopes, etc.).

## Example

```
# After completing step 1 of the plan (e.g. "Add notification workflow package"):
git add internal/v2/outlook/workflows/notification/
git commit -m "refactor(outlook): add notification workflow package"
git push origin KAT-1384/refactor-reply-for-all-inbound

# After step 2 (e.g. "Wire and remove reply package"):
git add server/dependencies/internal.go internal/v2/outlook/api/... internal/v2/outlook/workflows/reply/
git commit -m "refactor(outlook): wire notification workflow, remove reply package"
git push origin KAT-1384/refactor-reply-for-all-inbound
```
