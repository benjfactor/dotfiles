#!/usr/bin/env python3
"""Evaluate the review/merge gate for a PR.

Gate (see SKILL.md): green CI + >= 2 human approvals, and ideally >= 1 approval
from a member of a "team of interest". Teams of interest are NOT derived from
CODEOWNERS — they come from:
  - teams passed explicitly via --team (e.g. a team you asked to wait for), and
  - @<org>/<team> slugs mentioned in the PR body, and
  - teams already requested as reviewers on the PR.

Bot approvals (github-actions, *[bot]) never count toward the human total.

CI is read from the status check rollup. By default *every* reported check must
be green, which is the right default for an unknown repo. A repo that publishes
one authoritative check can narrow the read to it with --check-context (or the
CI_CHECK_CONTEXT environment variable), rather than this script naming any
particular CI provider.

Usage:
    review_gate.py <PR_NUMBER> [--repo owner/name] [--team slug]...
                               [--check-context <context>]

Prints a JSON verdict to stdout. Exit code is always 0 unless gh itself fails;
the caller reads the JSON and decides what to do.
"""
import json, os, re, subprocess, sys

# Rollup states, grouped by what they mean for the gate. Anything unrecognised is
# treated as still running, so a new state never reads as green by accident.
PASSING = {'SUCCESS', 'NEUTRAL', 'SKIPPED'}
FAILING = {'FAILURE', 'ERROR', 'CANCELLED', 'TIMED_OUT', 'ACTION_REQUIRED',
           'STARTUP_FAILURE', 'STALE'}


def gh_json(args):
    out = subprocess.run(['gh'] + args, capture_output=True, text=True)
    if out.returncode != 0:
        return None
    try:
        return json.loads(out.stdout)
    except json.JSONDecodeError:
        return None


def is_bot(login):
    return login == 'github-actions' or login.endswith('[bot]')


def check_state(c):
    return (c.get('state') or c.get('conclusion') or c.get('status') or '').upper()


def rollup_status(checks, context=None):
    """Collapse the rollup to one of SUCCESS / FAILURE / PENDING, or None.

    With a context, read only that check — a repo with one authoritative check.
    Without one, every check must pass: any failure fails the gate, and anything
    not yet passing holds it pending.
    """
    if context:
        for c in checks:
            if c.get('context') == context or c.get('name') == context:
                return check_state(c) or None
        return None
    states = [check_state(c) for c in checks]
    if not states:
        return None
    if any(s in FAILING for s in states):
        return 'FAILURE'
    if all(s in PASSING for s in states):
        return 'SUCCESS'
    return 'PENDING'


def main():
    if len(sys.argv) < 2:
        print(json.dumps({'error': 'usage: review_gate.py <PR_NUMBER> [--repo owner/name] '
                                   '[--team slug]... [--check-context <context>]'}))
        sys.exit(1)

    pr = sys.argv[1]
    repo = None
    explicit_teams = []
    check_context = os.environ.get('CI_CHECK_CONTEXT') or None
    i = 2
    while i < len(sys.argv):
        if sys.argv[i] == '--repo':
            repo = sys.argv[i + 1]; i += 2
        elif sys.argv[i] == '--team':
            explicit_teams.append(sys.argv[i + 1].lstrip('@').split('/')[-1]); i += 2
        elif sys.argv[i] == '--check-context':
            check_context = sys.argv[i + 1]; i += 2
        else:
            i += 1

    repo_args = ['--repo', repo] if repo else []
    if not repo:
        info = gh_json(['repo', 'view', '--json', 'nameWithOwner'])
        repo = info['nameWithOwner'] if info else None
    org = repo.split('/')[0] if repo else None

    data = gh_json(['pr', 'view', pr] + repo_args +
                   ['--json', 'reviews,body,reviewRequests,statusCheckRollup,url,title'])
    if data is None:
        print(json.dumps({'error': f'could not read PR {pr}'}))
        sys.exit(1)

    # Latest review state per author wins.
    latest = {}
    for r in data.get('reviews', []):
        login = (r.get('author') or {}).get('login')
        if not login:
            continue
        latest[login] = r.get('state')  # reviews are returned in chronological order
    approvers = sorted([u for u, s in latest.items() if s == 'APPROVED'])
    human_approvers = [u for u in approvers if not is_bot(u)]
    bot_approvers = [u for u in approvers if is_bot(u)]

    # Teams of interest: explicit + body @org/team mentions + requested reviewer teams.
    body = data.get('body') or ''
    body_teams = [m.split('/')[-1] for m in re.findall(r'@[\w-]+/[\w-]+', body)]
    requested_teams = [t.get('slug') or t.get('name', '').lower().replace(' ', '-')
                       for t in data.get('reviewRequests', []) if t.get('name') or t.get('slug')]
    teams = []
    for t in explicit_teams + body_teams + requested_teams:
        if t and t not in teams:
            teams.append(t)

    # Which teams of interest have an approving member?
    team_member_approvals = {}
    membership_errors = []
    for team in teams:
        members = gh_json(['api', f'orgs/{org}/teams/{team}/members', '--jq', '[.[].login]'])
        if members is None:
            membership_errors.append(team)
            continue
        hits = [u for u in human_approvers if u in members]
        if hits:
            team_member_approvals[team] = hits

    # If the user named teams explicitly, those are the REQUIRED owners; otherwise
    # any team of interest counts. owner_approved reflects the required set.
    required_teams = explicit_teams if explicit_teams else teams
    owner_approved = any(t in team_member_approvals for t in required_teams)

    ci = rollup_status(data.get('statusCheckRollup', []) or [], check_context)

    verdict = {
        'pr': int(pr),
        'url': data.get('url'),
        'title': data.get('title'),
        'humanApprovals': len(human_approvers),
        'humanApprovers': human_approvers,
        'botApprovers': bot_approvers,
        'teamsOfInterest': teams,
        'requiredTeams': required_teams,
        'teamMemberApprovals': team_member_approvals,
        'ownerApproved': owner_approved,
        'membershipUncheckable': membership_errors,
        'ci': ci,
        'ciCheckContext': check_context,
        'meets2Approvals': len(human_approvers) >= 2,
        'ciGreen': ci == 'SUCCESS',
        'fullyReady': len(human_approvers) >= 2 and ci == 'SUCCESS' and owner_approved,
    }
    print(json.dumps(verdict, indent=2))


if __name__ == '__main__':
    main()
