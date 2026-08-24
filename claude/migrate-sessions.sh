#!/usr/bin/env bash
#
# Move Claude Code session state between machines.
#
# bootstrap.sh carries the *config* layer (CLAUDE.md, settings, hooks, skills)
# because those are tracked in this repo. Everything Claude Code accumulates
# while you work -- transcripts, prompt history, memory, WSU notes -- lives in
# the gitignored runtime directory and is lost on a new machine. This moves it.
#
#   ./migrate-sessions.sh export                 # -> ~/claude-sessions-<host>-<date>.tgz
#   scp <archive> newmachine:~/
#   ./migrate-sessions.sh import <archive>       # on the new machine
#
# Import is a MERGE and never overwrites by default: a file that already exists
# on the destination is left alone. Re-running is safe.
#
# See SETUP.md ("Moving sessions to another machine") for the full story.

set -euo pipefail

CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
DRY_RUN=0
FORCE=0
DEEP=0
WITH_JOBS=1
ENCRYPT=0
MERGE_SESSIONS=0

say()  { printf '%s\n' "$*"; }
warn() { printf 'warn  %s\n' "$*" >&2; }
die()  { printf 'error %s\n' "$*" >&2; exit 1; }
run()  { if [ "$DRY_RUN" = 1 ]; then printf 'would  %s\n' "$*"; else "$@"; fi; }

# ---------------------------------------------------------------------------
# What travels, and what deliberately does not.
#
# Carried: everything that is a record of work you did and cannot be
# regenerated on the other machine.
CARRY=(
  projects        # transcripts, per-project memory/ dirs  <- the main event
  history.jsonl   # prompt history (the up-arrow buffer)
  wsu             # weekly status notes, written by the wsu-note skill
  file-history    # per-session snapshots of edited files
  todos           # per-session todo lists (absent on some versions)
)
# Carried only with --jobs (default on): background job transcripts + state.
CARRY_JOBS=(jobs)

# Two things Claude Code needs that are NOT plain files under ~/.claude, and
# that a sessions-only migration silently leaves behind:
#
#   ~/.claude.json      lives beside the directory, not in it. Holds the
#                       per-project state that makes Claude feel already set
#                       up: trust decisions, tool allowlists, MCP enablement,
#                       editor and theme prefs. Without it every project
#                       re-prompts for trust and forgets its permissions.
#   plugins/*.json      which plugins and marketplaces are installed. The
#                       700MB of plugin code is re-downloadable; the list of
#                       what to download is not.

# Left behind, and why -- each of these is either machine-bound or regenerated:
#
#   plugins/          700MB+, re-downloaded on first launch
#   worktrees/        live git worktrees; the gitdir pointers are absolute
#   sessions/         per-machine session keys
#   daemon*/          daemon pid, lock, auth cooldown, log
#   session-env/      captured shell env (PATH, etc.) of THIS machine
#   shell-snapshots/  same
#   cache/ backups/ telemetry/ debug/ downloads/ paste-cache/
#   *.log, *cache*.json, policy-limits.json, remote-settings.json, stats-cache.json
#   CLAUDE.md settings.json hooks skills statusline-command.sh pr-studio/
#                     symlinks into this repo; bootstrap.sh recreates them
#
# settings.local.json is carried as a *reference copy* only (see import).

usage() {
  cat <<'USAGE'
usage:
  migrate-sessions.sh export [--out FILE] [--encrypt] [--no-jobs] [--dry-run]
  migrate-sessions.sh import ARCHIVE [--merge-sessions] [--deep] [--force] [--dry-run]
  migrate-sessions.sh inspect ARCHIVE

export   Package this machine's Claude session state into an archive.
         --encrypt    passphrase-encrypt it, so it can travel by any route --
                      AirDrop, USB, a shared drive -- without being readable
                      in transit. Uses gpg if present, else openssl.
         --out FILE   archive path (default ~/claude-sessions-<host>-<date>.tgz)
         --no-jobs    skip jobs/ (background job transcripts, usually the bulk)
         Carried by default: every transcript and its memory/ dir, prompt
         history, WSU notes, file history, background jobs, the per-project
         settings from ~/.claude.json (trust, tool allowlists), and the list of
         installed plugins. NOT carried: plugin code (re-downloadable, and
         import prints the commands), and your login, which lives in the
         Keychain -- sign in once on the new machine.

import   Merge an archive into this machine's ~/.claude. Encrypted archives
         are detected by extension and decrypted on the way in.

         Sessions are unioned. Sessions only the archive has are added, ones
         only this machine has are kept, and ones both have are left exactly as
         they are here -- {a,b,c,d} merged into {b,d,e} gives {a,b,c,d,e}.
         Nothing is ever clobbered.

         --merge-sessions  additionally union the LINES of sessions both
                      machines have, recovering turns added on the other
                      machine after an earlier import. Off by default: it
                      rewrites transcripts you already have, which is only
                      worth doing if you actually work on both machines.
         --deep       rewrite home paths inside message bodies too, not just
                      the structural cwd fields. Only matters when the two
                      machines have different home paths.
         --force      overwrite non-session files that already exist. Never
                      applies to transcripts.

inspect  Print an archive's manifest and contents without extracting it.

Both commands accept --dry-run, which prints the plan and touches nothing.
USAGE
}

# ---------------------------------------------------------------------------
# Encryption. Optional, and the point of it is transport freedom: an encrypted
# archive can travel by any route you like -- USB stick, AirDrop, a shared
# drive -- without the contents being readable if it goes astray or lingers.
# Symmetric (passphrase) rather than key-based, because the sender and the
# receiver are the same person and key material is one more thing to migrate.

encrypt_file() {
  local src="$1"
  if command -v gpg >/dev/null 2>&1; then
    gpg --symmetric --cipher-algo AES256 --output "$src.gpg" "$src" >&2 || return 1
    printf '%s' "$src.gpg"
  elif command -v openssl >/dev/null 2>&1; then
    openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -salt \
            -in "$src" -out "$src.enc" >&2 || return 1
    printf '%s' "$src.enc"
  else
    return 1
  fi
}

# Import calls this when the archive looks encrypted. The extension records
# which tool wrote it, since the receiving machine has to have the same one.
decrypt_file() {
  local src="$1" out="$2"
  case "$src" in
    *.gpg)
      command -v gpg >/dev/null 2>&1 || die "this archive needs gpg to open, and gpg is not installed"
      gpg --output "$out" --decrypt "$src" >&2 || return 1 ;;
    *.enc)
      command -v openssl >/dev/null 2>&1 || die "this archive needs openssl to open"
      openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 \
              -in "$src" -out "$out" >&2 || return 1 ;;
    *) return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# export

cmd_export() {
  local out=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --out)      out="${2:?--out needs a path}"; shift 2 ;;
      --no-jobs)  WITH_JOBS=0; shift ;;
      --encrypt)  ENCRYPT=1; shift ;;
      --dry-run)  DRY_RUN=1; shift ;;
      -h|--help)  usage; exit 0 ;;
      *)          die "unknown flag for export: $1" ;;
    esac
  done

  [ -d "$CLAUDE_DIR" ] || die "no Claude directory at $CLAUDE_DIR"

  local host date_stamp
  host="$(scutil --get ComputerName 2>/dev/null || hostname -s)"
  host="$(printf '%s' "$host" | tr ' ' '-' | tr -cd '[:alnum:]._-')"
  date_stamp="$(date +%Y%m%d-%H%M%S)"
  : "${out:=$HOME/claude-sessions-${host}-${date_stamp}.tgz}"

  # The archive is unencrypted transcripts. Writing one inside a work tree puts
  # every conversation ever had one `git add .` away from being published, and
  # the repo this script ships in is public. Refuse rather than warn: the whole
  # cost of being wrong is unrecoverable, and the fix is a different --out.
  local out_dir repo_root
  out_dir="$(cd "$(dirname "$out")" 2>/dev/null && pwd)" \
    || die "cannot resolve the directory for --out $out"
  if repo_root="$(git -C "$out_dir" rev-parse --show-toplevel 2>/dev/null)"; then
    die "refusing to write the archive inside the git work tree at $repo_root

  $out

  It contains every transcript in plain text. Pick somewhere outside any
  checkout:  --out \$HOME/$(basename "$out")"
  fi

  local items=("${CARRY[@]}")
  [ "$WITH_JOBS" = 1 ] && items+=("${CARRY_JOBS[@]}")

  # Only pass through what actually exists; tar aborts on a missing member.
  local present=() missing=()
  local i
  for i in "${items[@]}"; do
    if [ -e "$CLAUDE_DIR/$i" ]; then present+=("$i"); else missing+=("$i"); fi
  done
  [ ${#present[@]} -gt 0 ] || die "nothing to export from $CLAUDE_DIR"
  [ ${#missing[@]} -gt 0 ] && say "skip   not present: ${missing[*]}"

  say "== packaging =="
  for i in "${present[@]}"; do
    printf '  %-14s %s\n' "$i" "$(du -sh "$CLAUDE_DIR/$i" 2>/dev/null | cut -f1)"
  done

  local staging manifest
  staging="$(mktemp -d "${TMPDIR:-/tmp}/claude-migrate.XXXXXX")"
  # shellcheck disable=SC2064
  trap "rm -rf '$staging'" EXIT
  manifest="$staging/manifest.json"

  # The manifest is how import knows what to rewrite. Record the layout too:
  # on some machines ~/.claude is itself a symlink into the dotfiles clone.
  local layout="directory"
  [ -L "$CLAUDE_DIR" ] && layout="symlink -> $(readlink "$CLAUDE_DIR")"

  python3 - "$manifest" "$HOME" "$(id -un)" "$host" "$layout" \
           "$(claude --version 2>/dev/null | head -1 || echo unknown)" \
           "${present[@]}" <<'PY'
import json, sys, datetime
path, home, user, host, layout, version, *items = sys.argv[1:]
json.dump({
    "schema": 1,
    "created": datetime.datetime.now().astimezone().isoformat(),
    "source_home": home,
    "source_user": user,
    "source_host": host,
    "source_layout": layout,
    "claude_version": version,
    "items": items,
}, open(path, "w"), indent=2)
PY

  # ~/.claude.json is mostly caches and telemetry. Carry the durable parts:
  # per-project settings and a couple of prefs, with the noise left behind.
  local staged=(manifest.json)
  if [ -f "$HOME/.claude.json" ]; then
    if python3 - "$HOME/.claude.json" "$staging/claude.json" <<'PY'
import json, sys

KEEP_TOP = {"theme", "editorMode", "githubRepoPaths"}
# Per project: settings you chose, not metrics Claude recorded. Everything
# named last* is telemetry from the previous run and is deliberately dropped.
KEEP_PROJECT = {
    "allowedTools", "hasTrustDialogAccepted", "hasCompletedProjectOnboarding",
    "enabledMcpjsonServers", "disabledMcpjsonServers", "mcpServers",
    "mcpContextUris", "hasClaudeMdExternalIncludesApproved",
}

src, dst = sys.argv[1], sys.argv[2]
try:
    data = json.load(open(src))
except (OSError, ValueError):
    sys.exit(1)

out = {k: v for k, v in data.items() if k in KEEP_TOP}
projects = {}
for path, cfg in (data.get("projects") or {}).items():
    if not isinstance(cfg, dict):
        continue
    kept = {k: v for k, v in cfg.items() if k in KEEP_PROJECT and v not in (None, [], {})}
    if kept:
        projects[path] = kept
if projects:
    out["projects"] = projects
json.dump(out, open(dst, "w"), indent=2)
print(f"  claude.json    {len(projects)} projects (trust, tool allowlists, prefs)")
PY
    then staged+=(claude.json); fi
  fi

  # The manifests, not the plugin code -- see the note by CARRY above.
  if [ -f "$CLAUDE_DIR/plugins/installed_plugins.json" ]; then
    mkdir -p "$staging/plugins"
    cp "$CLAUDE_DIR/plugins/installed_plugins.json" "$staging/plugins/" 2>/dev/null || true
    cp "$CLAUDE_DIR/plugins/known_marketplaces.json" "$staging/plugins/" 2>/dev/null || true
    staged+=(plugins)
    say "  plugins        $(python3 -c "import json,sys; print(len(json.load(open(sys.argv[1]))['plugins']))" "$CLAUDE_DIR/plugins/installed_plugins.json" 2>/dev/null || echo '?') installed (manifest only, code re-downloads)"
  fi

  if [ "$DRY_RUN" = 1 ]; then
    say ""
    say "would  write $out"
    say "manifest:"
    sed 's/^/  /' "$manifest"
    return 0
  fi

  # jobs/*/tmp is scratch space for background jobs -- can be large, never useful.
  tar -czf "$out" \
    --exclude='jobs/*/tmp' \
    --exclude='*.sock' \
    --exclude='.DS_Store' \
    -C "$staging" "${staged[@]}" \
    -C "$CLAUDE_DIR" "${present[@]}"

  local artifact="$out"
  if [ "$ENCRYPT" = 1 ]; then
    say ""
    say "== encrypting =="
    artifact="$(encrypt_file "$out")" \
      || die "encryption failed -- the plaintext archive is still at $out"
    rm -f "$out"
  fi

  # Checksum the artifact that actually travels, so the check on the far side
  # catches a truncated copy before anything is unpacked.
  shasum -a 256 "$artifact" > "$artifact.sha256"

  say ""
  say "wrote  $artifact  ($(du -h "$artifact" | cut -f1))"
  say "       $artifact.sha256"
  say ""
  if [ "$ENCRYPT" = 1 ]; then
    say "Encrypted, so move it however is convenient -- AirDrop, a USB stick, a"
    say "shared drive. Keep the passphrase somewhere other than the archive."
  else
    say "NOT encrypted, and transcripts hold whatever you ever pasted into Claude"
    say "-- tokens, internal code, customer data. Keep it to a direct transfer, or"
    say "re-run with --encrypt if it has to sit anywhere in between."
  fi
  say ""
  say "Move both files across, whichever way suits:"
  say ""
  say "  AirDrop      Finder -> select both -> Share -> AirDrop   (Mac to Mac, no setup)"
  say "  USB          cp '$artifact'{,.sha256} /Volumes/YOURSTICK/"
  say "  Local net    rsync -P '$artifact'{,.sha256} NEWMACHINE:~/"
  if [ "$ENCRYPT" = 1 ]; then
    say "  Cloud        fine for this one -- it is encrypted"
  else
    say "  Cloud        not with this archive; re-run with --encrypt first"
  fi
  say ""
  say "Then, on the new machine, from its dotfiles clone:"
  say "  ./claude/migrate-sessions.sh import ~/$(basename "$artifact")"
}

# ---------------------------------------------------------------------------
# inspect

cmd_inspect() {
  local archive="${1:?usage: inspect ARCHIVE}"
  [ -f "$archive" ] || die "no such archive: $archive"

  say "== manifest =="
  tar -xzOf "$archive" manifest.json 2>/dev/null | sed 's/^/  /' \
    || die "no manifest.json -- not an archive from this script"

  say ""
  say "== contents =="
  tar -tzf "$archive" | awk -F/ '$1!="manifest.json"{print $1"/"$2}' \
    | sort | uniq -c | sort -rn | head -25 | sed 's/^/  /'
  say ""
  say "  $(tar -tzf "$archive" | wc -l | tr -d ' ') entries total"
}

# ---------------------------------------------------------------------------
# import

cmd_import() {
  local archive="${1:-}"
  [ -n "$archive" ] || { usage; exit 1; }
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
      --force)   FORCE=1; shift ;;
      --deep)    DEEP=1; shift ;;
      --merge-sessions) MERGE_SESSIONS=1; shift ;;
      --dry-run) DRY_RUN=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *)         die "unknown flag for import: $1" ;;
    esac
  done
  [ -f "$archive" ] || die "no such archive: $archive"

  if [ -f "$archive.sha256" ]; then
    ( cd "$(dirname "$archive")" && shasum -a 256 -c "$(basename "$archive").sha256" >/dev/null ) \
      && say "ok     checksum verified" \
      || die "checksum mismatch -- the archive is corrupt, re-copy it"
  else
    warn "no .sha256 beside the archive; skipping integrity check"
  fi

  local staging
  staging="$(mktemp -d "${TMPDIR:-/tmp}/claude-import.XXXXXX")"
  # shellcheck disable=SC2064
  trap "rm -rf '$staging'" EXIT
  # An encrypted archive is decrypted into the staging directory, which is a
  # mktemp dir removed on exit -- the plaintext never lands anywhere permanent.
  local payload="$archive"
  case "$archive" in
    *.gpg|*.enc)
      say "== decrypting =="
      payload="$staging/archive.tgz"
      decrypt_file "$archive" "$payload" || die "decryption failed -- wrong passphrase?"
      ;;
  esac

  tar -xzf "$payload" -C "$staging"
  [ "$payload" = "$archive" ] || rm -f "$payload"
  [ -f "$staging/manifest.json" ] || die "no manifest.json -- not an archive from this script"

  local src_home src_host
  src_home="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["source_home"])' "$staging/manifest.json")"
  src_host="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["source_host"])' "$staging/manifest.json")"

  say "== importing from $src_host =="
  say "  source home  $src_home"
  say "  this home    $HOME"

  # Claude Code finds a project's transcripts by encoding its cwd into the
  # directory name (/ becomes -). If home differs, every directory name and
  # every cwd field is wrong and the sessions are invisible to /resume.
  if [ "$src_home" != "$HOME" ]; then
    say "  paths        REWRITE (homes differ)"
  else
    say "  paths        unchanged (same home path)"
  fi
  [ "$DEEP" = 1 ] && say "  --deep       message bodies will be rewritten too"
  [ "$FORCE" = 1 ] && say "  --force      existing files WILL be overwritten"
  say ""

  run mkdir -p "$CLAUDE_DIR"

  # Anything we are about to overwrite goes here first. Never delete.
  # Kept inside CLAUDE_DIR: it is the one location guaranteed to be writable,
  # and it travels with the directory it protects.
  local backup="$CLAUDE_DIR/migrate-backups/$(date +%Y%m%d-%H%M%S)"

  python3 - "$staging" "$CLAUDE_DIR" "$src_home" "$HOME" "$backup" \
           "$DRY_RUN" "$FORCE" "$DEEP" "$MERGE_SESSIONS" <<'PY'
import json, os, shutil, sys
from collections import Counter

staging, dest, src_home, dst_home, backup, dry, force, deep, merge_sessions = sys.argv[1:]
dry, force, deep = dry == "1", force == "1", deep == "1"
merge_sessions = merge_sessions == "1"
rewrite = src_home != dst_home

def encoded(p):
    """Claude Code's project-directory encoding: path separators become dashes."""
    return p.replace("/", "-").replace(".", "-")

src_tag, dst_tag = encoded(src_home), encoded(dst_home)

stats = {"copied": 0, "skipped": 0, "overwritten": 0, "rewritten": 0,
         "renamed": 0, "merged": 0, "unchanged": 0, "lines": 0,
         "copied_jsonl": 0}

def backup_of(path):
    rel = os.path.relpath(path, dest)
    target = os.path.join(backup, rel)
    os.makedirs(os.path.dirname(target), exist_ok=True)
    shutil.copy2(path, target)

def transform(path):
    """Read a transcript and return its lines as they should look on THIS machine.

    Pure -- it writes nothing. Merging needs the retargeted text in hand before
    it can compare against what is already here, so the rewrite has to be
    separable from the copy.

    Only `cwd` is structural; paths inside message bodies are the record of what
    actually ran where and are left alone unless --deep is given. A line that
    needs no change is passed through byte-for-byte, which matters for dedup:
    reserialising an untouched line would make it compare unequal to the copy
    already on disk.
    """
    out = []
    with open(path, "r", encoding="utf-8", errors="surrogateescape") as fh:
        for line in fh:
            stripped = line.strip()
            if not rewrite or not stripped:
                out.append(line)
                continue
            if deep and src_home in line:
                out.append(line.replace(src_home, dst_home))
                continue
            try:
                obj = json.loads(stripped)
            except (ValueError, TypeError):
                out.append(line)          # not JSON; pass through untouched
                continue
            if isinstance(obj, dict) and isinstance(obj.get("cwd"), str) \
               and obj["cwd"].startswith(src_home):
                obj["cwd"] = dst_home + obj["cwd"][len(src_home):]
                out.append(json.dumps(obj, ensure_ascii=False) + "\n")
            else:
                out.append(line)
    return out

def line_id(line):
    """Identity of one transcript line, for deduping a merge.

    Returns a (kind, value) pair because the two kinds dedup differently. Most
    lines carry a uuid, which survives reformatting and is a true identity.
    The rest -- mode markers, agent settings -- carry nothing unique and repeat
    verbatim by design, so they are identified by their text and counted rather
    than collapsed. Treating those as a set silently drops the repeats.
    """
    stripped = line.strip()
    if not stripped:
        return None
    try:
        obj = json.loads(stripped)
    except (ValueError, TypeError):
        return ("text", stripped)
    if isinstance(obj, dict) and isinstance(obj.get("uuid"), str):
        return ("uuid", obj["uuid"])
    return ("text", stripped)

def merge_jsonl(src, target):
    """Union an incoming transcript into the one already here.

    A transcript is an append-only log, so the union of both copies is the
    correct merge and neither machine loses anything: keep working on the old
    laptop after a migration, re-export, and the new turns land in the session
    they belong to instead of being skipped as "already there".

    New lines are appended rather than interleaved by timestamp. Claude Code
    reconstructs the conversation from the parentUuid chain, not from file
    order, and reordering an existing log is a far bigger risk than a tail that
    is out of chronological sequence.
    """
    incoming = transform(src)
    with open(target, "r", encoding="utf-8", errors="surrogateescape") as fh:
        existing = fh.readlines()
    ids = [line_id(l) for l in existing]
    seen_uuid = {v for k, v in (i for i in ids if i) if k == "uuid"}
    # Multiset, not a set: keep whichever copy has MORE of an identical
    # repeated line, so nothing is lost in either direction.
    have_text = Counter(v for k, v in (i for i in ids if i) if k == "text")

    added = []
    for line in incoming:
        ident = line_id(line)
        if ident is None:
            continue
        kind, value = ident
        if kind == "uuid":
            if value in seen_uuid:
                continue
            seen_uuid.add(value)
        else:
            if have_text[value] > 0:
                have_text[value] -= 1   # this occurrence is already here
                continue
        added.append(line)
    if not added:
        stats["unchanged"] += 1
        return
    if not dry:
        backup_of(target)
        with open(target, "a", encoding="utf-8", errors="surrogateescape") as fh:
            fh.writelines(added)
    stats["merged"] += 1
    stats["lines"] += len(added)

def rewrite_text(path):
    """--deep only: swap the old home out of a non-transcript sidecar file.

    projects/ holds more than .jsonl -- tool-results/*.txt, memory/*.md,
    workflows/*.json. Left alone these keep pointing at a home that does not
    exist here, which matters most for memory files, since Claude reads them
    back as fact.
    """
    try:
        with open(path, "r", encoding="utf-8", errors="surrogateescape") as fh:
            body = fh.read()
    except (OSError, ValueError):
        return
    if src_home not in body:
        return
    if not dry:
        with open(path, "w", encoding="utf-8", errors="surrogateescape") as fh:
            fh.write(body.replace(src_home, dst_home))
    stats["rewritten"] += 1

def place(src, rel):
    """Land one file in ~/.claude, without ever destroying what is already there."""
    target = os.path.join(dest, rel)
    exists = os.path.exists(target)

    # A session already on this machine is left untouched. Import is a union
    # over sessions: the ones only the source has are added, the ones only this
    # machine has are kept, and the ones both have are not rewritten. --force
    # deliberately does not reach transcripts.
    if exists and target.endswith(".jsonl"):
        if merge_sessions:
            merge_jsonl(src, target)    # opt-in: union the LINES too
        else:
            stats["unchanged"] += 1
        return

    if exists:
        if not force:
            stats["skipped"] += 1
            return
        if not dry:
            backup_of(target)
        stats["overwritten"] += 1
    elif target.endswith(".jsonl"):
        stats["copied_jsonl"] += 1
    else:
        stats["copied"] += 1
    if dry:
        return

    os.makedirs(os.path.dirname(target), exist_ok=True)
    if rewrite and target.endswith(".jsonl"):
        with open(target, "w", encoding="utf-8", errors="surrogateescape") as fh:
            fh.writelines(transform(src))
        shutil.copystat(src, target)
        stats["rewritten"] += 1
    else:
        shutil.copy2(src, target)
        if rewrite and deep:
            rewrite_text(target)

# -- projects/: the transcripts. Directory names encode the old home. ---------
proj_src = os.path.join(staging, "projects")
if os.path.isdir(proj_src):
    for name in sorted(os.listdir(proj_src)):
        path = os.path.join(proj_src, name)
        if not os.path.isdir(path):
            continue
        new_name = name
        if rewrite and name.startswith(src_tag):
            new_name = dst_tag + name[len(src_tag):]
            stats["renamed"] += 1
        for root, _dirs, files in os.walk(path):
            for f in files:
                if f == ".DS_Store":
                    continue
                full = os.path.join(root, f)
                rel = os.path.relpath(full, path)
                place(full, os.path.join("projects", new_name, rel))

# -- history.jsonl: append the source's entries, deduped, order preserved -----
hist_src = os.path.join(staging, "history.jsonl")
hist_dst = os.path.join(dest, "history.jsonl")
if os.path.isfile(hist_src):
    incoming = [l for l in open(hist_src, encoding="utf-8", errors="surrogateescape")]
    if rewrite:
        incoming = [l.replace(src_home, dst_home) for l in incoming]
    existing = []
    if os.path.isfile(hist_dst):
        existing = [l for l in open(hist_dst, encoding="utf-8", errors="surrogateescape")]
    seen = set(existing)
    added = [l for l in incoming if l not in seen and not seen.add(l)]
    if added and not dry:
        if existing:
            backup_of(hist_dst)
        with open(hist_dst, "a", encoding="utf-8", errors="surrogateescape") as fh:
            fh.writelines(added)
    print(f"  history.jsonl  +{len(added)} entries "
          f"({len(incoming) - len(added)} already present)")

# -- ~/.claude.json: the settings that live BESIDE the directory -------------
# Same rule as everywhere else here: fill gaps, never overrule what this
# machine already decided.
cj_src = os.path.join(staging, "claude.json")
cj_dst = os.path.join(os.path.dirname(os.path.abspath(dest)), ".claude.json")

def retarget(path):
    if rewrite and isinstance(path, str) and path.startswith(src_home):
        return dst_home + path[len(src_home):]
    return path

if os.path.isfile(cj_src):
    incoming_cfg = json.load(open(cj_src))
    try:
        current = json.load(open(cj_dst))
    except (OSError, ValueError):
        current = {}

    # Prefs are filled in only if unset -- a machine you have already themed
    # should not be restyled by an import.
    for key in ("theme", "editorMode"):
        if key in incoming_cfg and key not in current:
            current[key] = incoming_cfg[key]

    if incoming_cfg.get("githubRepoPaths"):
        repos = current.setdefault("githubRepoPaths", {})
        for k, v in incoming_cfg["githubRepoPaths"].items():
            repos.setdefault(retarget(k), v)

    projects = current.setdefault("projects", {})
    added = extended = 0
    for path, cfg in (incoming_cfg.get("projects") or {}).items():
        path = retarget(path)
        if path not in projects:
            projects[path] = cfg
            added += 1
            continue
        # Known to both: keep this machine's settings, but union the
        # allowlists, since a permission granted anywhere was still granted.
        here = projects[path]
        for field in ("allowedTools", "enabledMcpjsonServers",
                      "disabledMcpjsonServers"):
            incoming_list = cfg.get(field) or []
            if not incoming_list:
                continue
            have = here.get(field) or []
            fresh = [x for x in incoming_list if x not in have]
            if fresh:
                here[field] = have + fresh
                extended += 1

    if not dry:
        if os.path.isfile(cj_dst):
            shutil.copy2(cj_dst, cj_dst + ".migrate-backup")
        with open(cj_dst, "w") as fh:
            json.dump(current, fh, indent=2)
    print(f"  settings       {added} projects added, {extended} allowlists extended "
          f"(trust + permissions)")

# -- everything else: straight merge ------------------------------------------
for item in sorted(os.listdir(staging)):
    if item in ("manifest.json", "projects", "history.jsonl",
                "claude.json", "plugins"):
        continue
    path = os.path.join(staging, item)
    if os.path.isdir(path):
        for root, _dirs, files in os.walk(path):
            for f in files:
                if f == ".DS_Store":
                    continue
                full = os.path.join(root, f)
                place(full, os.path.join(item, os.path.relpath(full, path)))
    else:
        place(path, item)

if merge_sessions:
    print(f"  sessions       {stats['copied_jsonl']} added, {stats['merged']} line-merged "
          f"(+{stats['lines']} lines), {stats['unchanged']} unchanged")
else:
    print(f"  sessions       {stats['copied_jsonl']} added, "
          f"{stats['unchanged']} already here (left as they are)")
print(f"  other files    {stats['copied']} new, {stats['skipped']} left alone, "
      f"{stats['overwritten']} overwritten")
if rewrite:
    print(f"  retargeted     {stats['renamed']} project dirs, "
          f"{stats['rewritten']} files")
if stats["overwritten"] and not dry:
    print(f"  backup         {backup}")
PY

  # settings.local.json is machine-local by design (see SETUP.md). Never
  # applied automatically -- landed beside the real one for you to diff.
  if [ -f "$staging/settings.local.json" ]; then
    run cp "$staging/settings.local.json" "$CLAUDE_DIR/settings.local.json.imported"
    say "  settings       source copy left at settings.local.json.imported (not applied)"
  fi

  # Plugin code is not carried -- only the list of what to reinstall. Print it
  # as commands rather than writing the manifest, because a manifest pointing
  # at plugin directories that do not exist yet is worse than no manifest.
  if [ -f "$staging/plugins/installed_plugins.json" ]; then
    python3 - "$staging/plugins" "$CLAUDE_DIR/plugins" <<'PY'
import json, os, sys

src, dst = sys.argv[1], sys.argv[2]

def load(base, name):
    try:
        return json.load(open(os.path.join(base, name)))
    except (OSError, ValueError):
        return {}

want_m = load(src, "known_marketplaces.json")
have_m = load(dst, "known_marketplaces.json")
want_p = (load(src, "installed_plugins.json") or {}).get("plugins", {})
have_p = (load(dst, "installed_plugins.json") or {}).get("plugins", {})

cmds = []
for name, cfg in want_m.items():
    if name in have_m:
        continue
    source = cfg.get("source", {})
    ref = source.get("repo") or source.get("url") or source.get("path")
    if ref:
        cmds.append(f"claude plugin marketplace add {ref}")
for name in want_p:
    if name not in have_p:
        cmds.append(f"claude plugin install {name}")

if cmds:
    print("")
    print("  Plugins are not carried (700MB of re-downloadable code). To put the")
    print(f"  same {len(want_p)} back, run:")
    print("")
    for c in cmds:
        print(f"    {c}")
PY
  fi

  say ""
  if [ "$DRY_RUN" = 1 ]; then
    say "dry run -- nothing was written"
  else
    say "One thing no file can carry: your login. Run \`claude\` and sign in --"
    say "the credentials live in the macOS Keychain, not in ~/.claude."
    say ""
    say "Then check /resume, or:  ls $CLAUDE_DIR/projects"
  fi
}

# ---------------------------------------------------------------------------

case "${1:-}" in
  export)   shift; cmd_export "$@" ;;
  import)   shift; cmd_import "$@" ;;
  inspect)  shift; cmd_inspect "$@" ;;
  -h|--help|help|"") usage ;;
  *)        die "unknown command: $1" ;;
esac
