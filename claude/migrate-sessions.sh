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
  migrate-sessions.sh export [--out FILE] [--no-jobs] [--dry-run]
  migrate-sessions.sh import ARCHIVE [--force] [--deep] [--dry-run]
  migrate-sessions.sh inspect ARCHIVE

export   Package this machine's Claude session state into a .tgz + .sha256.
         --out FILE   archive path (default ~/claude-sessions-<host>-<date>.tgz)
         --no-jobs    skip jobs/ (background job transcripts, usually the bulk)

import   Merge an archive into this machine's ~/.claude.
         --force      overwrite files that already exist (default: skip them)
         --deep       also rewrite home paths inside message bodies, not just
                      the structural cwd fields. Changes the historical record;
                      only useful if you want old transcripts to read as if
                      they had always run on this machine.

inspect  Print an archive's manifest and contents without extracting it.

Both commands accept --dry-run, which prints the plan and touches nothing.
USAGE
}

# ---------------------------------------------------------------------------
# export

cmd_export() {
  local out=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --out)      out="${2:?--out needs a path}"; shift 2 ;;
      --no-jobs)  WITH_JOBS=0; shift ;;
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
    -C "$staging" manifest.json \
    -C "$CLAUDE_DIR" "${present[@]}"

  shasum -a 256 "$out" > "$out.sha256"

  say ""
  say "wrote  $out  ($(du -h "$out" | cut -f1))"
  say "       $out.sha256"
  say ""
  say "These transcripts contain whatever you pasted into Claude -- tokens,"
  say "internal code, customer data. Move the file directly; do not put it in"
  say "cloud storage or a bucket."
  say ""
  say "  scp '$out'{,.sha256} NEWMACHINE:~/"
  say "  # then, on the new machine, from its dotfiles clone:"
  say "  ./claude/migrate-sessions.sh import ~/$(basename "$out")"
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
  tar -xzf "$archive" -C "$staging"
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
           "$DRY_RUN" "$FORCE" "$DEEP" <<'PY'
import json, os, shutil, sys

staging, dest, src_home, dst_home, backup, dry, force, deep = sys.argv[1:]
dry, force, deep = dry == "1", force == "1", deep == "1"
rewrite = src_home != dst_home

def encoded(p):
    """Claude Code's project-directory encoding: path separators become dashes."""
    return p.replace("/", "-").replace(".", "-")

src_tag, dst_tag = encoded(src_home), encoded(dst_home)

stats = {"copied": 0, "skipped": 0, "overwritten": 0, "rewritten": 0, "renamed": 0}

def backup_of(path):
    rel = os.path.relpath(path, dest)
    target = os.path.join(backup, rel)
    os.makedirs(os.path.dirname(target), exist_ok=True)
    shutil.copy2(path, target)

def rewrite_jsonl(path):
    """Retarget a transcript at this machine.

    Only `cwd` is structural -- it is what Claude Code reads back. Paths inside
    message bodies are a record of what actually happened on the old machine
    and are left alone unless --deep is given.
    """
    out, changed = [], False
    with open(path, "r", encoding="utf-8", errors="surrogateescape") as fh:
        for line in fh:
            stripped = line.strip()
            if not stripped:
                out.append(line)
                continue
            if deep and src_home in line:
                line = line.replace(src_home, dst_home)
                changed = True
                out.append(line)
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
                changed = True
            else:
                out.append(line)
    if changed and not dry:
        with open(path, "w", encoding="utf-8", errors="surrogateescape") as fh:
            fh.writelines(out)
    if changed:
        stats["rewritten"] += 1

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
    """Copy one file into ~/.claude at `rel`, honouring the no-clobber rule."""
    target = os.path.join(dest, rel)
    if os.path.exists(target):
        if not force:
            stats["skipped"] += 1
            return
        if not dry:
            backup_of(target)
        stats["overwritten"] += 1
    else:
        stats["copied"] += 1
    if dry:
        return
    os.makedirs(os.path.dirname(target), exist_ok=True)
    shutil.copy2(src, target)
    if rewrite:
        if target.endswith(".jsonl"):
            rewrite_jsonl(target)
        elif deep:
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

# -- everything else: straight merge ------------------------------------------
for item in sorted(os.listdir(staging)):
    if item in ("manifest.json", "projects", "history.jsonl"):
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

print(f"  files          {stats['copied']} new, {stats['skipped']} already there, "
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

  say ""
  if [ "$DRY_RUN" = 1 ]; then
    say "dry run -- nothing was written"
  else
    say "done. Start Claude Code and check /resume, or:"
    say "  ls $CLAUDE_DIR/projects"
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
