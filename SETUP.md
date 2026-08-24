# Setting up a machine from this repo

Written to be followed cold — by a human on a new laptop, or by an agent with
shell access and no prior knowledge of this setup.

## Quick start

```bash
git clone git@github.com:benjfactor/dotfiles.git ~/dotfiles
cd ~/dotfiles
./bootstrap.sh --dry-run     # read the plan first
./bootstrap.sh               # create the symlinks
```

Then the four things `bootstrap.sh` deliberately does not do for you:

```bash
nvim +PlugInstall +qall                # 1. neovim plugins
tmux                                   # 2. then press: prefix + I  (capital i)
./terminal/iterm2/setup.sh             # 3. iTerm2 settings -- QUIT iTerm2 first
                                       # 4. install anything it reported as MISS
```

Restart your shell. Done.

## What bootstrap.sh does

It is **idempotent** — re-running is safe and does nothing when already set up.
Anything it would overwrite is moved to `~/.dotfiles-backup-<timestamp>/`
first; it never deletes. `--dry-run` prints the plan and touches nothing.

### The symlinks it creates

| Link | Target in repo |
|---|---|
| `~/.bash_profile` | `.bash_profile` |
| `~/.inputrc` | `.inputrc` (readline: case-insensitive completion, history search) |
| `~/.gitconfig` | `gitfiles/.gitconfig` |
| `~/.githooks` | `gitfiles/.githooks` |
| `~/.git-templates` | `gitfiles/.git-templates` |
| `~/.gitmux.conf` | `gitfiles/.gitmux.conf` |
| `~/.tmux.conf` | `.tmux.conf` |
| `~/.tmux` | `.tmux` |
| `~/tmux_battery_charge_indicator.sh` | `tmux_battery_charge_indicator.sh` |
| `~/.vimrc` | `vimide/.vimrc` |
| `~/.vim` | `vimide/.vim` |
| `~/.config/nvim` | `vimide/.vim` (Neovim runtimepath — see Plugins) |
| `~/.ctags` | `vimide/.ctags` |
| `~/.claude` | `.claude` (see below) |

## The `.claude` layer — read this before touching it

This is the one genuinely non-obvious part of the repo, and it is invisible
from a fresh clone.

`~/.claude` is a **live runtime directory**: logs, history, caches, daemon
state, hundreds of megabytes that change constantly. It is gitignored, so a
clone does not contain it at all.

What *is* tracked is `claude/` (no dot). Five entries inside `~/.claude` are
symlinks out to it:

```
~/.claude/                                 (runtime dir -- NOT tracked)
  ├── CLAUDE.md             -> dotfiles/claude/CLAUDE.md
  ├── settings.json         -> dotfiles/claude/settings.json
  ├── hooks                 -> dotfiles/claude/hooks
  ├── skills                -> dotfiles/claude/skills
  ├── statusline-command.sh -> dotfiles/claude/statusline-command.sh
  ├── pr-studio/
  │     └── preferences.md  -> dotfiles/claude/pr-studio/preferences.md
  └── sessions/ jobs/ projects/ history.jsonl ...   (runtime state)
```

`pr-studio/preferences.md` is PR Studio's **global** review config — reviewer
choice, comment style, severity labels. Everything else under `pr-studio/`, and
every `<repo>/.pr-studio/` directory, is per-review runtime state (diffs,
sessions, fetched comments) and deliberately stays local.

Permissions live in the tracked `claude/settings.json`. A separate
`~/.claude/settings.local.json` may exist for machine-local overrides; it is
Claude Code's own local-override file and is intentionally not tracked, so
check it if a permission seems missing after a rebuild.

Config is version-controlled; runtime noise is not. Note the exceptions are
**not** gitignore negations — nothing under the runtime directory is tracked at
all. Versioning comes entirely from those five children pointing at a sibling
directory that differs by one dot.

**`bootstrap.sh` never moves or replaces `~/.claude`.** It only links the five
entries into whatever is already there. That directory holds live session
state — `sessions/`, `jobs/`, `history.jsonl`, `daemon/` — and you are quite
likely running the script from inside a Claude Code session, so moving it would
pull the floor out from under yourself.

It *will* replace `~/.claude/settings.json` if Claude Code auto-created one,
backing the original up first.

### Two layouts exist, both fine

This machine's original setup has an extra hop: `~/.claude` is itself a symlink
to `dotfiles/.claude`, a gitignored directory holding the runtime state inside
the repo. New machines skip that — `~/.claude` is simply the real directory
Claude Code made.

Both end up identical where it matters: the same five links resolve to the same
tracked files. The indirection bought nothing, since `dotfiles/.claude` was
never tracked, so new machines do without it. `bootstrap.sh` handles either.

### Moving your sessions to a new machine

`bootstrap.sh` gets you the *config*. It deliberately does nothing about the
runtime directory, so a freshly bootstrapped machine has your settings and
skills but no memory of any work you have ever done — no transcripts, no
`/resume`, no prompt history, no `memory/` files, no WSU notes.

`claude/migrate-sessions.sh` moves that across:

```bash
./claude/migrate-sessions.sh export --encrypt   # on the old machine
#   ...move the two files across, any way you like...
./claude/migrate-sessions.sh import ~/claude-sessions-<...>.tgz.enc
```

It writes a file and reads a file; **how the file travels is up to you.** For
two Macs, AirDrop is the least-friction option and needs no setup at all —
select the archive and its `.sha256` in Finder, Share, AirDrop. A USB stick or
`rsync` over the local network work equally well, and `--encrypt` makes even a
shared drive fine, since the contents are unreadable without the passphrase.
`export` prints these options with the paths filled in when it finishes.

Encryption is passphrase-based (`gpg` if installed, otherwise `openssl`, which
every Mac has). Import spots an encrypted archive by its extension and asks for
the passphrase on the way in.

Run `import` *after* `bootstrap.sh`, and with Claude Code closed — it is
writing to the same files while it runs.

#### What is actually covered

Not just transcripts — the aim is a machine that behaves like the one you left.

| | Where it lives | Carried |
|---|---|---|
| Transcripts, `/resume` | `~/.claude/projects/` | yes |
| Per-project memory | `projects/*/memory/` | yes |
| Prompt history | `history.jsonl` | yes, appended + deduped |
| WSU notes | `~/.claude/wsu/` | yes |
| File edit history | `file-history/` | yes |
| Background jobs | `jobs/` | yes (`--no-jobs` to skip) |
| Trust + tool allowlists | **`~/.claude.json`** | yes, merged |
| Theme, editor mode | `~/.claude.json` | yes, only if unset here |
| CLAUDE.md, settings, hooks, skills | this repo | via `bootstrap.sh` |
| Which plugins you use | `plugins/*.json` | commands printed to reinstall |
| Plugin code (700MB) | `plugins/cache/` | no — re-downloads |
| Login | macOS Keychain | **no — sign in once** |

The one that is easy to miss is `~/.claude.json`. It sits *beside* the
directory rather than in it, so anything that copies `~/.claude` misses it
entirely — and it holds the per-project trust decisions and tool allowlists.
Without it every project re-prompts for trust and forgets its permissions,
which feels like nothing migrated even though every session is there.

Plugin *code* is not carried, because 700MB that re-downloads itself is not
worth moving. What is carried is the list, and import prints the exact
`claude plugin marketplace add` / `claude plugin install` commands to restore
it. Writing the manifest directly would be worse: it would claim plugins are
installed at paths that do not exist yet.

**Deliberately left behind:** `worktrees/` holds live git worktrees whose
gitdir pointers are absolute; `sessions/`, `daemon*`, `session-env/` and
`shell-snapshots/` are bound to the machine that made them. The five tracked
symlinks are excluded too — `bootstrap.sh` recreates them, and copying them
would carry over links into the old machine's clone path.
`settings.local.json` lands as `settings.local.json.imported` for you to diff,
never applied, because machine-local overrides are the one thing that
genuinely should not follow you.

#### The part that is easy to get wrong

Claude Code locates a project's transcripts by **encoding the working
directory into the directory name** — `~/Projects/galaxy` is stored as
`projects/-Users-bhingston-Projects-galaxy` — and it stamps a `cwd` on every
line inside. So a plain `rsync ~/.claude` only works if the new machine's home
path is character-for-character identical. Different username, and every
session is still on disk but invisible to `/resume`.

`import` reads the source home out of the archive manifest, compares it to
`$HOME`, and renames the project directories and rewrites the `cwd` fields when
they differ. Same home path, and it skips all of that and plain merges.

By default it rewrites *only* those structural fields, leaving paths inside
message bodies as the historical record of what actually ran where. Pass
`--deep` to rewrite everything, including `memory/*.md` — worth doing when the
homes differ, since Claude reads memory files back as current fact and stale
paths in them are actively misleading.

#### Sessions are unioned, never clobbered

The destination is not assumed to be empty, because after the first migration
it usually is not. Import takes the **union of the two machines' sessions**:

> machine 1 has `a b c d`, machine 2 has `b d e` → after importing 1 into 2,
> machine 2 has `a b c d e`

Sessions only the archive has are added. Sessions only this machine has are
left completely alone. Sessions both have are kept **as they are here** — the
incoming copy does not overwrite yours. Re-running is a no-op, and interrupting
it costs nothing.

`--force` exists for the non-session files (memory notes, tool results) and
snapshots anything it replaces into `~/.claude/migrate-backups/<timestamp>/`
first. It deliberately has no effect on transcripts at all.

If you genuinely work on *both* machines, the same session can gain new turns
in two places. `--merge-sessions` handles that: it unions the transcripts
line-by-line, deduping on each line's uuid, so neither machine's turns are
lost. It is off by default because it rewrites transcripts you already have,
which is not worth doing unless that situation is real for you.

`history.jsonl` is appended and deduped rather than replaced. Both commands
take `--dry-run`; `inspect ARCHIVE` prints the manifest without extracting.

#### The archive never goes through git

Worth being explicit, because this repo is public: **nothing about this syncs
through the repo.** The archive is written to `$HOME` by default, travels
by whatever means you choose, and is deleted afterwards. Git is not involved at
any point, and the runtime directory it reads from is gitignored even on the
layout where it physically sits inside the clone.

Two rails keep it that way. `export` refuses outright to write an archive
anywhere inside a git work tree — one `git add .` is all it would take — and
`claude-sessions-*.tgz` is gitignored as a second layer. On the symlink layout
that refusal also covers `~/.claude/...`, since it resolves inside the clone;
write to `$HOME` or anywhere outside a checkout instead.

Transcripts contain everything you ever pasted into Claude — tokens, internal
source, customer data. Without `--encrypt` the archive is plaintext, so keep it
to a direct transfer and delete it afterwards; with `--encrypt` it is safe to
let it sit somewhere in between. Either way, do not be tempted to "just commit
it somewhere private" — a private repo is still a copy you have to remember to
delete.

## Plugins

**The editor is Neovim**, despite everything being named `.vim`. That matters
more than it looks:

- `~/.config/nvim` → `vimide/.vim` supplies the **runtimepath**. Without it
  nvim cannot find `autoload/plug.vim`, so `plug#begin` is undefined and every
  `Plug` line in `.vimrc` errors — no plugin loads at all.
- `.vimrc` is found by a different route entirely: `.bash_profile` exports
  `VIMINIT='source $MYVIMRC'` and `MYVIMRC='~/dotfiles/vimide/.vimrc'`.

Because those two paths are independent, a machine missing the `~/.config/nvim`
link still *looks* configured — the vimrc loads and then throws 30+ errors.
`bootstrap.sh` creates both links.

`MYVIMRC` hardcodes `~/dotfiles`, so the clone must live there.

vim-plug itself is vendored at `vimide/.vim/autoload/plug.vim` and needs no
install. Plugins are not tracked; run `nvim +PlugInstall +qall` to fetch them
into `vimide/.vim/plugged/`.

Five plugins compile or download on install, so a fresh machine needs a
toolchain before `PlugInstall`:

| Plugin | Hook | Needs |
|---|---|---|
| `fatih/vim-go` | `:GoUpdateBinaries` | `go` |
| `rrethy/vim-hexokinase` | `make hexokinase` | `make`, `go` |
| `mistricky/codesnap.nvim` | `make` | `cargo` (Rust) |
| `nvim-treesitter` | `:TSUpdate` | C compiler (Xcode CLT) |
| `junegunn/fzf` | `fzf#install()` | downloads its own binary |

`coc.nvim` pins `{'branch': 'release'}`, which is prebuilt — no Node build step,
though Node is needed at runtime.

**`vim-wakatime` needs `~/.wakatime.cfg`**, which is deliberately *not* in this
repo because it holds an API key. Copy it across by hand or re-authenticate, or
the plugin nags on every startup.

**tmux** — TPM is *not* tracked. `bootstrap.sh` clones it into
`.tmux/plugins/tpm`, after which `prefix + I` inside tmux installs the rest
(resurrect, continuum, window-name).

Neither plugin set belongs in git: they are third-party repos with their own
history, and committing them is what produced the phantom-submodule problem
this setup previously had.

## Fonts

Font *files* are not in this repo, but the font *names* are — they live in the
iTerm2 settings that `terminal/iterm2/` tracks. Extract them any time with:

```bash
plutil -convert binary1 -o /tmp/i.plist terminal/iterm2/com.googlecode.iterm2.plist
python3 -c "import plistlib;[print(b.get('Name'),'|',b.get('Normal Font'),'|',b.get('Non Ascii Font')) for b in plistlib.load(open('/tmp/i.plist','rb'))['New Bookmarks']]"
```

What is currently set:

| Where | Font | Size |
|---|---|---|
| iTerm2 *Default* — main | `DejaVuSansMonoPowerline` | 14 |
| iTerm2 *quickie* — main | `DejaVuSansMonoPowerline` | 12 |
| iTerm2 both — non-ASCII | `FiraMonoNF-Regular` | 14 |
| Terminal.app *Homebrew* | `LiterationMonoPowerline` | — |

The non-ASCII font is the one drawing powerline separators, git symbols in the
tmux status line, and NERDTree/airline glyphs. If it is missing you get boxes
and tofu, not an error.

Those are **PostScript** names, not filenames — `FiraMonoNF-Regular` ships in a
file called `FiraMonoNerdFont-Regular.otf`. Match on the PostScript name:

```bash
fc-list --format='%{postscriptname}\n' | sort -u | grep -E 'Powerline|NF-'
```

### Installing them

```bash
./install-fonts.sh
```

Downloads exactly these three families into `~/Library/Fonts`. Idempotent —
families already registered under the right PostScript name are skipped; pass
`--force` to reinstall. Restart the terminal app afterwards.

`bootstrap.sh` verifies all three by PostScript name and reports any missing,
but does not install them.

#### Where they come from

Direct links, if you would rather fetch them by hand:

| Font | Source |
|---|---|
| `DejaVuSansMonoPowerline` | [DejaVu Sans Mono for Powerline.ttf](https://github.com/powerline/fonts/raw/master/DejaVuSansMono/DejaVu%20Sans%20Mono%20for%20Powerline.ttf) — [folder](https://github.com/powerline/fonts/tree/master/DejaVuSansMono) |
| `LiterationMonoPowerline` | [Literation Mono Powerline.ttf](https://github.com/powerline/fonts/raw/master/LiberationMono/Literation%20Mono%20Powerline.ttf) — [folder](https://github.com/powerline/fonts/tree/master/LiberationMono) |
| `FiraMonoNF-Regular` | [FiraMono.zip](https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraMono.zip) (~13MB) — [Nerd Fonts downloads](https://www.nerdfonts.com/font-downloads) |

Note *Literation* lives in the **`LiberationMono`** folder — powerline renamed
the faces but not the directory, so searching for "Literation" in the repo tree
finds nothing.

Two traps worth knowing:

- `brew install --cask font-fira-mono-nerd-font` works for Fira, but there is
  **no cask for the powerline faces**. The similarly-named
  `font-dejavu-sans-mono-nerd-font` is the Nerd Font build and registers a
  *different* PostScript name, so it will not satisfy the iTerm2 setting even
  though it looks like the right thing.
- `FiraMono.zip` contains three builds. Only `FiraMonoNerdFont-*.otf` carries
  the `FiraMonoNF-` PostScript prefix; the Mono and Propo builds register as
  `FiraMonoNFM-` and `FiraMonoNFP-` and will not match.

## Terminal multiplexer and shell

`.bash_profile` sources exactly one file from this repo,
`bin/session-sauce.plugin.zsh`, and is otherwise self-contained. It hardcodes
`$HOME/dotfiles`, so the clone must live there. Its one absolute path,
`/usr/local/mysql/bin`, is a PATH entry that is harmless when absent.

`.tmux.conf` uses only `~`-relative paths. Its status line shells out to
`gitmux`, `curl`, `dig`, `ifconfig`, the bundled
`tmux_battery_charge_indicator.sh`, and macOS's `airport` binary — the last of
which Apple has deprecated, so expect that segment to stop working on some
future macOS.

**`reattach-to-user-namespace` is no longer used.** tmux has reached the macOS
pasteboard directly since 2.6, so the wrapper was removed along with the
`default-command` line that required it. `default-command` is now unset, which
makes tmux start `default-shell` as a login shell — the same result the wrapper
produced. Nothing to install; if you see it referenced anywhere, it is stale.

**`tmux-window-name` needs the `libtmux` Python package.** Without it the
plugin fails quietly and windows simply never get renamed, which looks like a
failed install rather than a missing dependency:

```bash
pip3 install --user libtmux
```

`bootstrap.sh` checks for it.

## iTerm2

Covered separately in [`terminal/iterm2/README.md`](terminal/iterm2/README.md).
Short version: iTerm2 loads its settings directly from `terminal/iterm2/`, and
you must quit iTerm2 before running that setup script. Never symlink a macOS
preference plist — `cfprefsd` will clobber it.

### Five settings the plist cannot carry

```bash
./terminal/iterm2/appkit-defaults.sh          # apply
./terminal/iterm2/appkit-defaults.sh --check  # report only
```

`AppleAntiAliasingThreshold`, `ApplePressAndHoldEnabled`,
`AppleScrollAnimationEnabled`, `AppleSmoothFixedFontsSizeThreshold` and
`AppleWindowTabbingMode` are **AppKit** keys. They sit in iTerm2's preference
domain, but they are not iTerm2's settings, and in managed mode iTerm2 writes
back only the keys it owns — so every time it saves, it deletes all five from
`com.googlecode.iterm2.plist`.

That makes the plist the wrong home for them. Tracked there they provision a new
machine exactly once, then disappear on the first save, leaving a phantom
deletion in the diff that `sync.sh` will eventually commit away for good. This
script applies them with `defaults write` instead, where iTerm2 leaves them
alone — demonstrably, since the tracked plist no longer contains them while
`defaults read` still returns every one.

The one worth caring about is **`ApplePressAndHoldEnabled = false`**: without it,
holding a key opens the accent picker instead of repeating the character, which
is immediately obvious in vim.

`bootstrap.sh` verifies all five. A running iTerm2 gets a cached copy of its
domain from `cfprefsd`, so changes land on disk immediately but only take effect
after you quit and reopen it.

## ObinsKit (Anne Pro keyboard)

`obinskit/` is the one directory here that `bootstrap.sh` does **not** touch,
because there is nothing to link. Your keymap and lighting live in the
keyboard's own firmware, not on the computer — plug the board into a new
machine and they are already there. ObinsKit is only an editor that flashes to
it.

What the repo keeps is therefore a manual backup, in two parts.

**Exports** (`obinskit/*.json`) — re-import through the ObinsKit UI when you
want to edit a profile, or to rebuild after a firmware reset:

| File | Type |
|---|---|
| `VimBoard.json` | keymap layout |
| `F1.json`, `F2.json`, `Split.json`, `Subtle Cyan.json`, `mod+arrows.json` | lighting effects |
| `BenjsColours.json`, `DefaultColours.json` | colour palettes |

**App preferences** (`obinskit/preferences/*.json`) — the app's own settings,
which do live on disk. Restore by copying them back:

```bash
cp obinskit/preferences/*.json ~/Library/Application\ Support/ObinsKit/storage/
```

Quit ObinsKit first. This is a copy rather than a symlink or a bootstrap step
on purpose: it is an Electron app that rewrites these files on exit, so linking
them invites the same clobbering problem as symlinking a macOS plist, and
overwriting them while the app runs just loses the change.

To refresh the backup after changing settings, copy in the other direction.

Note `~/Library/Application Support/ObinsKit` and `.../obinskit` are the same
directory — macOS is case-insensitive, and it is easy to think there are two.

## Gotchas

**Do not run `bootstrap.sh` from a git worktree.** Every link it creates is
absolute, so bootstrapping from a throwaway worktree points `~/.vimrc` and
`~/.claude` at a directory that disappears when the branch is cleaned up. The
script refuses to run from a worktree; override with `FORCE_WORKTREE=1` only
if you really mean it.

**`nvm` is a shell function, not a binary.** `command -v nvm` reports it
missing even when it works. The tool check looks for `$NVM_DIR/nvm.sh`.

**Three vim configs exist.** `vimide/.vimrc` is the live one. `.vimrc` and
`portable/.vimrc` at the repo root are older copies kept for reference — the
symlink is what settles which is real.

## What is not covered

Machine-level setup that this repo does not attempt: Homebrew itself, macOS
system preferences, SSH keys, GPG keys, app installs. `bootstrap.sh` reports
missing command-line tools but does not install them, on purpose — installing
toolchains behind your back on a fresh machine is not a thing a setup script
should decide for you.
