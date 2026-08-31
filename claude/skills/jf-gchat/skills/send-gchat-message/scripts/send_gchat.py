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
  send_gchat.py --targets "meerkats" --message "..." --mention "craig,will"
  # reply into an existing thread (URL, full name, or bare thread id):
  send_gchat.py --targets "AAAACOXIXAM" --message-file body.md \
    --thread "https://chat.google.com/room/AAAACOXIXAM/ZpNybdmNiAw/ZpNybdmNiAw"

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
    "autobots":                            "AAAAkkgulAw",  # corrected via spaces.list 2026-06-26 (old AAAAWOyaLAg → 403)
    "np-easy":                             "AAAAqGa-a8I",
    "warped-tour":                         "AAQANVVa_PA",
    "marketplace-institute-of-technology": "AAAACpnkUis",
}

# Person slug -> Google Chat user ID, for --mention. Same rationale as TEAM_CHANNELS: this is the
# generic posting primitive, so anything reusable lives here rather than in a caller. IDs come from
# the userMention annotation on a message where the person was @-ed:
#   GET /v1/spaces/<space>/messages -> annotations[].userMention.user.name
PEOPLE = {
    "craig":  "users/101609381686230694100",  # Craig Kumick
    "daniel": "users/107059066615888383168",  # Daniel Ngo
    "will":   "users/116331619409537721608",  # Will Fawcett
}


def resolve_person(ref):
    """Accept a slug ('craig'), a display first name, or a raw 'users/123' ID."""
    ref = ref.strip()
    if not ref:
        return None
    if ref.startswith("users/"):
        return ref
    return PEOPLE.get(ref.lower().lstrip("@"))


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


def parse_thread_ref(ref, default_space=None):
    """Resolve a thread reference to (space_id, thread_name).

    Accepts any of:
      - a Chat web URL: https://chat.google.com/room/<space>/<thread>[/<msg>]
      - a full resource name: spaces/<space>/threads/<thread>
      - a bare thread id (combined with default_space)

    The web-URL thread segment is used directly as the REST thread id — verified
    working against live threads (KAT-1584). Returns (space_id, 'spaces/.../threads/...').
    """
    ref = ref.strip()
    m = re.search(r'/room/([^/]+)/([^/?#]+)', ref)              # web URL
    if m:
        return m.group(1), f"spaces/{m.group(1)}/threads/{m.group(2)}"
    m = re.fullmatch(r'spaces/([^/]+)/threads/([^/]+)', ref)    # full resource name
    if m:
        return m.group(1), ref
    if default_space is None:                                   # bare thread id
        raise ValueError("bare thread id needs a space — pass a single --targets space")
    return default_space, f"spaces/{default_space}/threads/{ref}"


def post_message(token, space_id, text, thread_name=None, fail_if_thread_missing=True):
    """Post text to a space, optionally into an existing thread.

    Returns (ok, error_string_or_None). Backward-compatible: callers that omit the
    thread args get the original unthreaded behavior. When thread_name is set, the
    message replies into that thread; fail_if_thread_missing chooses the reply
    option — True => REPLY_MESSAGE_OR_FAIL (error, no stray message, if the thread
    isn't found), False => REPLY_MESSAGE_FALLBACK_TO_NEW_THREAD (start a new thread).
    """
    payload = {'text': text}
    url = f'https://chat.googleapis.com/v1/spaces/{space_id}/messages'
    if thread_name:
        payload['thread'] = {'name': thread_name}
        opt = 'REPLY_MESSAGE_OR_FAIL' if fail_if_thread_missing else 'REPLY_MESSAGE_FALLBACK_TO_NEW_THREAD'
        url += f'?messageReplyOption={opt}'
    body = json.dumps(payload).encode()
    req = urllib.request.Request(url, data=body, method='POST')
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
                    help='comma-separated people to @-mention: slugs from PEOPLE (craig, daniel, will) '
                         'or raw user IDs (users/123...)')
    ap.add_argument('--resolve-only', action='store_true',
                    help='print target resolution and exit without sending')
    ap.add_argument('--thread',
                    help='reply into an existing thread: a Chat URL '
                         '(https://chat.google.com/room/<space>/<thread>/...), a full '
                         'spaces/<space>/threads/<thread> name, or a bare thread id. '
                         'Requires exactly one --targets space.')
    ap.add_argument('--thread-new-ok', action='store_true',
                    help='with --thread, fall back to a NEW thread if the thread is not '
                         'found (REPLY_MESSAGE_FALLBACK_TO_NEW_THREAD) instead of failing. '
                         'Default fails loudly (REPLY_MESSAGE_OR_FAIL) so a wrong thread id '
                         'never leaves a stray top-level message.')
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

    # Resolve the thread reference (if any) to a thread name + owning space.
    thread_name = None
    if args.thread:
        if len(resolved) != 1:
            print("ERROR: --thread requires exactly one resolved target space")
            sys.exit(1)
        target_space = resolved[0][1]
        tspace, thread_name = parse_thread_ref(args.thread, default_space=target_space)
        if tspace != target_space:
            print(f"ERROR: --thread belongs to space {tspace} but --targets resolved to {target_space}")
            sys.exit(1)

    text = Path(args.message_file).read_text() if args.message_file else args.message
    if not text:
        print("ERROR: --message or --message-file required to send")
        sys.exit(1)
    if args.mention:
        ids, unknown = [], []
        for ref in args.mention.split(','):
            if not ref.strip():
                continue
            uid = resolve_person(ref)
            (ids.append(uid) if uid else unknown.append(ref.strip()))
        if unknown:
            print(f"ERROR: unknown --mention {unknown}; known slugs: {sorted(PEOPLE)}")
            sys.exit(1)
        text = text + ' ' + ' '.join(f"<{u}>" for u in ids)

    failures = 0
    for t, sid in resolved:
        ok, err = post_message(token, sid, text, thread_name=thread_name,
                               fail_if_thread_missing=not args.thread_new_ok)
        dest = f"{t} ({sid})" + (f" thread {thread_name.split('/')[-1]}" if thread_name else '')
        print(f"{'posted' if ok else 'ERROR'} -> {dest}" + (f": {err}" if err else ''))
        failures += 0 if ok else 1
    if failures:
        sys.exit(1)


if __name__ == '__main__':
    main()
