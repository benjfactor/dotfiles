#!/bin/bash
# On main/master in ~/Projects, block destructive commands.
# Read-only and safe commands are allowed through.

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

allow() { echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'; exit 0; }
deny()  { echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PermissionRequest\",\"decision\":{\"behavior\":\"deny\",\"message\":\"$1\"}}}"; exit 0; }

# dotfiles: always allow
if [[ "$CWD" == "$HOME/dotfiles"* || "$CWD" == "$HOME/.claude"* ]]; then
  allow
fi

# Only apply logic inside ~/Projects
if [[ "$CWD" != "$HOME/Projects"* ]]; then
  exit 0  # fall through to normal prompt
fi

# Must be a git repo
if ! git -C "$CWD" rev-parse --git-dir > /dev/null 2>&1; then
  exit 0  # fall through to normal prompt
fi

BRANCH=$(git -C "$CWD" rev-parse --abbrev-ref HEAD 2>/dev/null)

if [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
  # Block destructive git operations that modify files or history on the base branch.
  # Branch management (e.g. `git branch -d/-D` to clean up merged branches) is allowed —
  # it touches no files and is safe on master.
  if echo "$CMD" | grep -qE '^\s*git\s+(commit|push|merge|rebase|reset|revert|tag|cherry-pick)'; then
    deny "Blocked destructive git command on branch '$BRANCH'. Switch to a feature branch first."
  fi

  # Block destructive filesystem operations
  if echo "$CMD" | grep -qE '^\s*(rm|rmdir|mv|mkdir|chmod|chown|truncate|shred)\s'; then
    deny "Blocked destructive filesystem command on branch '$BRANCH'. Switch to a feature branch first."
  fi

  # Everything else (reads, queries, builds, tests, etc.) is allowed
  allow
fi

allow
