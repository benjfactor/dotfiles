#!/usr/bin/env python3
"""Send a message to one or more Google Chat spaces.

Reusable primitive: resolves raw space IDs directly, or team identifiers
(`@vendasta/<slug>` or `<slug>`) to space IDs via TEAM_CHANNELS, falling back to
a live `spaces.list` "Team: <Name>" displayName lookup. notify-pr-channels and
other skills import this module so auth + channel resolution live in one place.

Usage:
  send_gchat.py --targets "phoenix,marina,AAAAIj8WMWc" --message "text"
  send_gchat.py --targets "@vendasta/phoenix" --message-file body.md
  send_gchat.py --targets "phoenix" --resolve-only          # print resolution, do not send
  send_gchat.py --targets "meerkats" --message "..." --mention "users/101...,users/107..."

Auth: OAuth via GCP secret google-chat-oauth-client-secret (repcore-prod),
cached refresh token at ~/.config/google-chat-cli/credentials-rw.json.
"""
import argparse
import json
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

CLIENT_ID = "642433220657-955eqfa32mlb0o3koe8g4qmuv1ue414s.apps.googleusercontent.com"
CREDS_FILE = Path.home() / ".config/google-chat-cli/credentials-rw.json"

# Team slug -> Google Chat space ID. Single source of truth for team channel
# resolution (notify-pr-channels imports this). Unmapped teams are resolved live
# via spaces.list ("Team: <Name>") and can be pasted back here to skip the lookup.
TEAM_CHANNELS = {
    "meerkats":                            "AAAAIj8WMWc",  # personal team PR channel (Craig + Daniel)
    "snapcats":                            "AAAAAHjNt6A",
    "snack-ops":                           "AAAAjno8gDs",
    "phoenix":                             "AAAAN_I9hG8",
    "marina":                              "AAAABIynxDE",  # discovered via spaces.list 2026-06-24
    "autobots":                            "AAAAWOyaLAg",
    "np-easy":                             "AAAAqGa-a8I",
    "warped-tour":                         "AAQANVVa_PA",
    "marketplace-institute-of-technology": "AAAACpnkUis",
}


def get_access_token():
    client_secret = subprocess.run(
        ['gcloud', 'secrets', 'versions', 'access', 'latest',
         '--secret=google-chat-oauth-client-secret', '--project=repcore-prod'],
        capture_output=True, text=True,
    ).stdout.strip()
    creds = json.loads(CREDS_FILE.read_text())
    data = urllib.parse.urlencode({
        'client_id': CLIENT_ID, 'client_secret': client_secret,
        'refresh_token': creds['refresh_token'], 'grant_type': 'refresh_token',
    }).encode()
    resp = json.loads(urllib.request.urlopen(
        urllib.request.Request('https://oauth2.googleapis.com/token', data=data, method='POST')
    ).read())
    return resp['access_token']


def _looks_like_space_id(s):
    # Space IDs are opaque mixed-case tokens (AAAAIj8WMWc, AAQANVVa_PA); team slugs
    # are lowercase-with-dashes. An uppercase char means it's a raw space ID.
    return bool(re.fullmatch(r'[A-Za-z0-9_-]{6,}', s)) and any(c.isupper() for c in s)


def _list_spaces(token):
    spaces, page = [], ''
    for _ in range(10):
        url = 'https://chat.googleapis.com/v1/spaces?pageSize=1000' + (('&pageToken=' + page) if page else '')
        req = urllib.request.Request(url)
        req.add_header('Authorization', 'Bearer ' + token)
        d = json.loads(urllib.request.urlopen(req).read())
        spaces += d.get('spaces', [])
        page = d.get('nextPageToken', '')
        if not page:
            break
    return spaces


def resolve_target(target, token=None):
    """Resolve a target to (space_id, how). Accepts a raw space ID, a team slug,
    or @vendasta/<slug>. `how` is one of: raw, map, lookup, unresolved."""
    t = target.strip()
    m = re.match(r'@?vendasta/([\w-]+)$', t)
    if m:
        t = m.group(1)
    if _looks_like_space_id(t):
        return t, 'raw'
    slug = t.lower()
    if slug in TEAM_CHANNELS:
        return TEAM_CHANNELS[slug], 'map'
    # Live fallback: match a space named "Team: <slug words>".
    if token is None:
        token = get_access_token()
    want = slug.replace('-', ' ')
    for s in _list_spaces(token):
        name = (s.get('displayName') or '').strip().lower()
        if name == f"team: {want}" or (name.startswith('team:') and want in name):
            return s['name'].split('/')[-1], 'lookup'
    return None, 'unresolved'


def post_message(token, space_id, text):
    """Post text to a space. Returns (ok, error_string_or_None)."""
    body = json.dumps({'text': text}).encode()
    req = urllib.request.Request(
        f'https://chat.googleapis.com/v1/spaces/{space_id}/messages', data=body, method='POST')
    req.add_header('Authorization', 'Bearer ' + token)
    req.add_header('Content-Type', 'application/json')
    try:
        urllib.request.urlopen(req).read()
        return True, None
    except urllib.error.HTTPError as e:
        return False, f"{e.code} {e.read().decode()[:300]}"


def main():
    ap = argparse.ArgumentParser(description="Send a Google Chat message to spaces/teams.")
    ap.add_argument('--targets', required=True,
                    help='comma-separated space IDs / team slugs / @vendasta/<team>')
    ap.add_argument('--message', help='message text')
    ap.add_argument('--message-file', help='read message text from this file')
    ap.add_argument('--mention', default='',
                    help='comma-separated user IDs (users/123...) appended as <users/...> mentions')
    ap.add_argument('--resolve-only', action='store_true',
                    help='print target resolution and exit without sending')
    args = ap.parse_args()

    targets = [t for t in args.targets.split(',') if t.strip()]
    token = get_access_token()

    resolved = []
    for t in targets:
        sid, how = resolve_target(t, token)
        print(f"{t} -> {sid or 'UNRESOLVED'} ({how})")
        if sid:
            resolved.append((t, sid))

    if args.resolve_only:
        return

    text = Path(args.message_file).read_text() if args.message_file else args.message
    if not text:
        print("ERROR: --message or --message-file required to send")
        sys.exit(1)
    if args.mention:
        text = text + ' ' + ' '.join(f"<{m.strip()}>" for m in args.mention.split(',') if m.strip())

    failures = 0
    for t, sid in resolved:
        ok, err = post_message(token, sid, text)
        print(f"{'posted' if ok else 'ERROR'} -> {t} ({sid})" + (f": {err}" if err else ''))
        failures += 0 if ok else 1
    if failures:
        sys.exit(1)


if __name__ == '__main__':
    main()
