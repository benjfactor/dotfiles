#!/usr/bin/env python3
"""Post a PR notification to Google Chat channels.

Does not post to the personal team PR channel (or meerkats). Reads the PR body for
@vendasta/<team> mentions and posts to those external team channels only.

Auth, channel resolution, and the TEAM_CHANNELS map are delegated to the
send-gchat-message skill's shared module (single source of truth) so this script
only owns the PR-specific message shape.

Usage:
    chat_post.py <pr_url> <pr_title> [prefix]

`prefix` is an optional first line prepended to every message (e.g.
"Found during deploy monitor for a different PR.").
"""
import os
import re
import subprocess
import sys

# Reuse the shared Chat primitive (auth, post_message, resolve_target, TEAM_CHANNELS).
sys.path.insert(0, os.path.expanduser('~/.claude/skills/send-gchat-message/scripts'))
import send_gchat  # noqa: E402

# Team members (Google Chat user IDs) mentioned on the personal team channel.
# People IDs live in send_gchat.PEOPLE, so the generic posting skill stays the one place they are
# maintained. Adding someone there makes them available to --mention here and everywhere else.
CRAIG_ID = send_gchat.PEOPLE["craig"]
DANIEL_ID = send_gchat.PEOPLE["daniel"]
TEAM_SPACE = "AAAAIj8WMWc"                  # personal team PR channel (always posted)


def get_pr_body(pr_url):
    result = subprocess.run(
        ['gh', 'pr', 'view', pr_url, '--json', 'body', '--jq', '.body'],
        capture_output=True, text=True,
    )
    return result.stdout if result.returncode == 0 else ''


def main():
    if len(sys.argv) < 3:
        print("Usage: chat_post.py <pr_url> <pr_title> [prefix]")
        sys.exit(1)

    pr_url, pr_title = sys.argv[1], sys.argv[2]
    prefix = (sys.argv[3].rstrip() + "\n") if len(sys.argv) > 3 and sys.argv[3].strip() else ""
    token = send_gchat.get_access_token()

    # The personal team channel is no longer posted to (pr-watch finds those PRs via GitHub). It stays in
    # posted_spaces so a @vendasta/meerkats tag in the body is skipped too. Spaces are deduped by id, not
    # team name: two different mentions can resolve to the same space.
    posted_spaces = {TEAM_SPACE}
    for team in re.findall(r'@vendasta/([\w-]+)', get_pr_body(pr_url)):
        space_id, how = send_gchat.resolve_target(team, token)
        if not space_id:
            print(f"Skipping @vendasta/{team}: no channel found ({how})")
            continue
        if space_id in posted_spaces:
            print(f"Skipping @vendasta/{team}: that is the team channel, or already posted ({space_id})")
            continue
        posted_spaces.add(space_id)
        print(f"Found @vendasta/{team} in PR body — posting to their channel ({space_id})")
        ok, err = send_gchat.post_message(token, space_id, f'{prefix}{pr_title}\n{pr_url}')
        print(f"{'Posted to' if ok else 'Error posting to'} {team} ({space_id})" + (f": {err}" if err else ''))


if __name__ == '__main__':
    main()
