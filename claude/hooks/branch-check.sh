#!/bin/bash
# Location gate for Bash commands.
#
# The allow-list in settings.json decides WHAT commands may run. This hook
# decides WHERE they may run, which the allow-list cannot express: its patterns
# match the command string and know nothing about the working directory.
#
# Policy:
#   ~/dotfiles, ~/.claude   -> full access, master included (it is the one repo
#                              where committing to master is intended)
#   ~/Projects + git repo   -> full access on a feature branch or worktree;
#                              on main/master, destructive commands are blocked
#   anywhere else           -> reads yes, local writes no. Covers ~/Downloads,
#                              /etc, $HOME itself, and any non-repo directory.
#
# Remote writes are deliberately untouched: gh, git push, and the Jira/Confluence
# MCP tools do not mutate this disk, and are useful from anywhere.

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

allow() { echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'; exit 0; }
deny()  { echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PermissionRequest\",\"decision\":{\"behavior\":\"deny\",\"message\":\"$1\"}}}"; exit 0; }

# Commands that mutate this machine's filesystem. Kept as one list so the
# on-master rule and the outside-a-repo rule cannot drift apart.
DESTRUCTIVE_FS='^\s*(sudo\s+)?(rm|rmdir|mv|cp|mkdir|chmod|chown|truncate|shred|dd|ln|tee)\s'
DESTRUCTIVE_GIT='^\s*git\s+(commit|push|merge|rebase|reset|revert|tag|cherry-pick)'

# --- 1. dotfiles and claude config: always allowed, master included ----------
if [[ "$CWD" == "$HOME/dotfiles"* || "$CWD" == "$HOME/.claude"* ]]; then
  allow
fi

# --- 2. inside ~/Projects and inside a git repo ------------------------------
if [[ "$CWD" == "$HOME/Projects"* ]] && git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1; then
  BRANCH=$(git -C "$CWD" rev-parse --abbrev-ref HEAD 2>/dev/null)

  if [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
    # Branch management (git branch -d) is intentionally still allowed here:
    # it touches no files and cleaning up merged branches on master is normal.
    if echo "$CMD" | grep -qE "$DESTRUCTIVE_GIT"; then
      deny "Blocked destructive git command on branch '$BRANCH'. Switch to a feature branch or worktree first."
    fi
    if echo "$CMD" | grep -qE "$DESTRUCTIVE_FS"; then
      deny "Blocked destructive filesystem command on branch '$BRANCH'. Switch to a feature branch or worktree first."
    fi
  fi

  # Feature branch or worktree: near-full access, which is the point.
  allow
fi

# --- 3. everywhere else ------------------------------------------------------
# Outside ~/Projects, or inside it but not a git repo. Previously this fell
# through to the allow-list, which meant a broad rule like `Bash(go install:*)`
# was auto-approved anywhere on disk. Now local writes are refused outright and
# everything else falls through to the normal prompt.
if echo "$CMD" | grep -qE "$DESTRUCTIVE_FS"; then
  deny "Blocked: '$CWD' is not a version-controlled repo under ~/Projects, so filesystem writes are not auto-approved here. cd into a repo, or run it yourself if you meant to."
fi

exit 0  # not a write -- fall through to normal permission handling
