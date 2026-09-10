---
name: commit-preferences
description: Generates or suggests git commit messages following the user's Conventional Commits preferences (feat, fix, chore, refactor, prefactor, doc, wip) and optional scopes. Use when writing commit messages, amending commits, or when the user asks for commit message help or mentions conventional commits.
---

# Commit message preferences

Follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/): `<type>[optional scope]: <description>` with optional body and footers.

## Types to use

| Type | When to use |
|------|-------------|
| **feat** | New feature (user-facing or notable capability). |
| **fix** | Bug fix. |
| **chore** | Maintenance, tooling, config, dependencies—no behavior change. |
| **refactor** | Code restructure with no new behavior or features; same surface, better internals. |
| **prefactor** | Refactors done on a branch *before* the main feature (the feature is usually in another branch). |
| **doc** | Documentation only (README, comments, API docs). |
| **wip** | Partial commit: saving current local state (may or may not work), temporary files (e.g. vim rest file to remove before merging), or partial work that needs a follow-up commit. |

- **refactor** vs **feat**: Use `refactor` when behavior and surface stay the same; use `feat` when something new is added.
- **prefactor**: Use when the whole branch is preparatory refactors leading up to a later feat (often in a different branch). Other types (e.g. `chore`, `refactor`) are fine too when they fit better.
- **wip**: Use only for in-progress checkpoints, not for final merge-ready commits.

Other conventional types (e.g. `build`, `ci`, `perf`, `test`, `style`) are acceptable when they clearly fit.

### Working style

Prefer small, incremental working commits when suggesting or generating messages.

## Scope

- **Galaxy repo**: Prefer scope = nx app or lib name, e.g. `feat(business-center-client): add dashboard widget`.
- Scope is optional elsewhere; use when it adds clarity (e.g. area of the codebase or module).

## What not to change

- **Reverts and merges**: Leave git’s default first line as-is (e.g. `Revert "..."`, `Merge branch '...'`). Optional: add extra detail in body or after the first line, but keep the first line unchanged.

## Examples

```
feat(auth): add SSO login for Google
fix(reports): correct date formatting in export
chore(deps): bump eslint to 8.x
refactor(api): extract validation into shared helpers
prefactor(store): normalize state shape before adding filters
doc: update API section in README
wip: checkpoint auth flow before adding SSO
```
