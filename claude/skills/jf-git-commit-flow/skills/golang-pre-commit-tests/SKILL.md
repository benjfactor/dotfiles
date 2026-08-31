---
name: golang-pre-commit-tests
description: In Go/Golang repositories, run the full internal test suite before committing (e.g. go test ./internal/...) so commits don't introduce breaks outside the changed package. Apply when working in a repo that has go.mod or Go packages and you are about to commit or push.
---

# Go repos: run full internal tests before commit

Use this skill when working in a **Go (Golang) repository** and making commits.

## Rule

**Before committing or pushing**, run the repository’s broad test suite so changes don’t break other packages.

- Prefer **`go test ./internal/...`** when the repo has an `internal/` tree (e.g. email, business-center).
- If the repo uses a different layout, use the equivalent broad test (e.g. `go test ./...` or the path the repo’s README/CI uses).

Do this **before** `git commit` or `git push`, so you only commit when the full internal (or equivalent) tests pass.

## When to apply

- The workspace is a Go repo (has `go.mod` and Go packages).
- You are about to commit, push, or the user asks you to “commit” or “push” changes.
- You have made code changes and want to ensure nothing else is broken.

## When to skip

- Repo is not Go (no `go.mod`).
- User explicitly says to skip tests or commit anyway.
- Only documentation or non-Go files were changed and the user doesn’t care about running tests.

## Example

```bash
# Before committing in a Go repo with internal packages:
go test ./internal/... -count=1

# Then, if all pass:
git add ...
git commit -m "..."
git push ...
```

## Why

Running only tests for the package you changed (e.g. `go test ./internal/v2/trackedmessage/...`) can miss breakage in other packages that depend on it or share behavior. Running `go test ./internal/...` (or the repo’s full test path) catches those breaks before commit.
