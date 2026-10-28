#!/usr/bin/env bash
# Poll a PR and print one line per new piece of feedback. Meant to be run by Monitor.
#
# Usage: watch.sh <PR_NUMBER> <BASELINE_ISO> [--repo owner/name] [--interval SECONDS]
#                 [--state FILE] [--include-self]
#
# Reports reviews, top-level comments, inline review comments and CI check
# changes (ci/cloudbuild, or a Cloud Build trigger named *-any-branch-*) at or after BASELINE_ISO (e.g. 2026-10-08T15:50:00Z). The first poll
# always prints a BASELINE line, so anything that landed between taking the
# baseline and the first poll is reported, never absorbed. Later polls print
# nothing when nothing changed. Your own comments are skipped unless
# --include-self, because the watcher's replies would otherwise echo back.
# Monitor expires after 30 minutes; re-arm with the same BASELINE_ISO and
# --state FILE so items already reported are not reported again.
#
# Output lines (tab-free, one event each):
#   BASELINE ...                       first poll summary
#   REVIEW <state> @<who> <time> id=<id>: <body>
#   COMMENT @<who> <time> id=<id>: <body>
#   INLINE @<who> <time> id=<id> reply-to=<root id> <path>:<line>: <body>
#   CI <state> <url>
#   ERROR ...                          gh failed (printed once per failure streak)

set -u

usage() { echo "usage: watch.sh <PR_NUMBER> <BASELINE_ISO> [--repo owner/name] [--interval SECONDS] [--state FILE] [--include-self]" >&2; exit 2; }

[ $# -ge 2 ] || usage
pr=$1
baseline=$2
shift 2
repo=""
interval=300
include_self=0
state=""
while [ $# -gt 0 ]; do
  case $1 in
    --repo) repo=$2; shift 2 ;;
    --interval) interval=$2; shift 2 ;;
    --state) state=$2; shift 2 ;;
    --include-self) include_self=1; shift ;;
    *) usage ;;
  esac
done

if [ -z "$repo" ]; then
  repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null) || { echo "ERROR could not resolve repo; pass --repo"; exit 1; }
fi
me=""
[ $include_self -eq 1 ] || me=$(gh api user --jq .login 2>/dev/null || true)

if [ -n "$state" ]; then
  seen=$state
  touch "$seen"
else
  seen=$(mktemp -t pr-watch-seen.XXXXXX)
  trap 'rm -f "$seen"' EXIT
fi

# Each fetch prints "<id>\t<line>" for items at/after the baseline, excluding $me.
# Bodies are flattened to one line and capped so Monitor events stay readable.
flat='gsub("[\\r\\n\\t]+"; " ") | if length > 300 then .[0:300] + "…" else . end'

fetch_pr() {
  gh pr view "$pr" --repo "$repo" --json reviews,comments,statusCheckRollup --jq "
    ([.reviews[] | select(.submittedAt >= \"$baseline\" and .author.login != \"$me\")
      | \"\(.id)\tREVIEW \(.state) @\(.author.login) \(.submittedAt) id=\(.id): \(.body | $flat)\"]
     + [.comments[] | select(.createdAt >= \"$baseline\" and .author.login != \"$me\")
      | \"\(.id)\tCOMMENT @\(.author.login) \(.createdAt) id=\(.id): \(.body | $flat)\"]
     + [.statusCheckRollup[] | select((.context // .name // \"\") | test(\"^ci/cloudbuild$|-any-branch-\"))
      | \"ci\tCI \(.state // .conclusion // .status) \(.targetUrl // .detailsUrl // \"\")\"])[]"
}

# Inline comments drafted in a pending review keep their draft time, so also take
# any comment whose review was submitted after the baseline.
fetch_inline() {
  local reviews
  reviews=$(gh api --paginate "repos/$repo/pulls/$pr/reviews" --jq ".[] | select(.submitted_at >= \"$baseline\") | .id" | paste -sd, -) || return 1
  gh api --paginate "repos/$repo/pulls/$pr/comments" --jq "
    .[] | select((.created_at >= \"$baseline\" or (.pull_request_review_id as \$r | any([$reviews][]; . == \$r))) and .user.login != \"$me\")
    | \"inline-\(.id)\tINLINE @\(.user.login) \(.created_at) id=\(.id) reply-to=\(.in_reply_to_id // .id) \(.path):\(.line // .original_line // \"?\"): \(.body | $flat)\""
}

first=1
failing=0
ci_last=$(sed -n 's/^ci=//p' "$seen" | tail -1)
ci_prior=$ci_last
while true; do
  if out=$(fetch_pr) && inline=$(fetch_inline); then
    failing=0
    events=""
    while IFS=$'\t' read -r id line; do
      [ -n "$id" ] || continue
      if [ "$id" = ci ]; then
        [ "$line" = "$ci_last" ] || { events+="$line"$'\n'; ci_last=$line; echo "ci=$line" >> "$seen"; }
      elif ! grep -qxF "$id" "$seen"; then
        echo "$id" >> "$seen"
        events+="$line"$'\n'
      fi
    done <<< "$out"$'\n'"$inline"

    if [ $first -eq 1 ]; then
      n=$(printf '%s' "$events" | grep -cv '^CI ' || true)
      echo "BASELINE $repo#$pr since $baseline: $n unreported item(s), ${ci_last:-CI unknown}"
      # A fresh watch summarizes CI above; a re-arm reports a CI flip as its own event.
      if [ -n "$ci_prior" ]; then printf '%s' "$events"; else printf '%s' "$events" | grep -v '^CI ' || true; fi
      first=0
    else
      printf '%s' "$events"
    fi
  elif [ $failing -eq 0 ]; then
    echo "ERROR gh poll failed for $repo#$pr; retrying every ${interval}s"
    failing=1
  fi
  sleep "$interval"
done
