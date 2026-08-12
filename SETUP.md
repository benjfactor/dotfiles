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
vim +PlugInstall +qall                 # 1. vim plugins
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
| `~/.gitconfig` | `gitfiles/.gitconfig` |
| `~/.githooks` | `gitfiles/.githooks` |
| `~/.git-templates` | `gitfiles/.git-templates` |
| `~/.gitmux.conf` | `gitfiles/.gitmux.conf` |
| `~/.tmux.conf` | `.tmux.conf` |
| `~/.tmux` | `.tmux` |
| `~/tmux_battery_charge_indicator.sh` | `tmux_battery_charge_indicator.sh` |
| `~/.vimrc` | `vimide/.vimrc` |
| `~/.vim` | `vimide/.vim` |
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
  └── sessions/ jobs/ projects/ history.jsonl ...   (runtime state)
```

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

## Plugins

**vim** — vim-plug is vendored in this repo at `vimide/.vim/autoload/plug.vim`,
so it needs no install. The plugins themselves are not tracked; run
`vim +PlugInstall +qall` and vim-plug fetches them into `vimide/.vim/plugged/`.

**tmux** — TPM is *not* tracked. `bootstrap.sh` clones it into
`.tmux/plugins/tpm`, after which `prefix + I` inside tmux installs the rest
(resurrect, continuum, window-name).

Neither plugin set belongs in git: they are third-party repos with their own
history, and committing them is what produced the phantom-submodule problem
this setup previously had.

## iTerm2

Covered separately in [`terminal/iterm2/README.md`](terminal/iterm2/README.md).
Short version: iTerm2 loads its settings directly from `terminal/iterm2/`, and
you must quit iTerm2 before running that setup script. Never symlink a macOS
preference plist — `cfprefsd` will clobber it.

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
