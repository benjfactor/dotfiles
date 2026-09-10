#!/usr/bin/env bash
# Map a source line to the commit + PR that last touched it.
#
# Usage: attribute_pr.sh <file> <line> [git-ref]
#   Run from inside the target repo. <git-ref> defaults to origin/master.
#
# This is an INPUT to attribution, not the answer. Blame tells you who last
# touched a line — not necessarily the PR that made a latent bug reachable.
# Always corroborate with the bug's true onset (wide log window) and a disproof
# pass before naming a PR. See SKILL.md.
set -euo pipefail

file="${1:?usage: attribute_pr.sh <file> <line> [git-ref]}"
line="${2:?usage: attribute_pr.sh <file> <line> [git-ref]}"
ref="${3:-origin/master}"

sha=$(git blame -L "${line},${line}" "$ref" -- "$file" | awk '{print $1}' | tr -d '^')
echo "line:   ${file}:${line} (@ ${ref})"
echo "commit: ${sha}"
git show -s --format='        %an  %ci%n        %s' "$sha"

owner_repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || echo "")
echo "PR(s) containing this commit:"
if [ -n "$owner_repo" ]; then
  gh api "repos/${owner_repo}/commits/${sha}/pulls" \
    --jq '.[] | "        #\(.number)  \(.title)  — \(.html_url)"' 2>/dev/null \
    || echo "        (none found via API)"
else
  echo "        (could not resolve repo; run inside a gh-authenticated checkout)"
fi
