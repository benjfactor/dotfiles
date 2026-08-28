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
| `~/Library/Application Support/Sublime Text 3/Packages/User` | `sublime/User` |
| `…/Packages/Colorsublime - Themes/FireCode.tmTheme` | `sublime/themes/FireCode.tmTheme` |

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

## Sublime Text

The installed build is **3200**, so the live data directory is the
version-suffixed one:

```
~/Library/Application Support/Sublime Text 3/Packages/
```

Sublime 4 dropped that suffix (`…/Sublime Text/Packages/`) while the app bundle
kept the name `Sublime Text.app` in both versions. The app name tells you
nothing about which directory is in use — check `Sublime Text → About` or the
bundle's `CFBundleVersion` before editing anything. There are stale
`Sublime Text 2` and `Sublime Text 3/Cache` directories on this machine that
look plausible and are not read.

`bootstrap.sh` links the whole `Packages/User` directory rather than the
individual settings files in it. Sublime writes every new keymap, snippet and
per-plugin settings file into that directory, so file-by-file links would leave
each new one untracked — settings would look synced until the first time you
added one.

### The colour scheme has to be tracked

`Package Control.sublime-settings` lists the installed packages, and Package
Control reinstalls them from that list on a new machine. That covers plugins.
It does **not** cover the themes those plugins downloaded.

`Preferences.sublime-settings` sets:

```json
"color_scheme": "Packages/Colorsublime - Themes/FireCode.tmTheme"
```

Colorsublime fetched `FireCode.tmTheme` on demand and dropped it loose in its
package directory. Nothing reinstalls it — restore only the two settings files
and Package Control reports success while Sublime opens on default colours,
which reads as "the theme package broke" rather than "a file is missing". So
the `.tmTheme` itself is committed to `sublime/themes/` and linked into place.

Not tracked, deliberately: `Packages/Colorsublime - Themes/cache/` (5.7 MB
clone of the upstream themes repo, re-fetched on demand),
`Installed Packages/*.sublime-package` (Package Control reinstalls these),
`Local/Session.sublime_session` (open files and window layout),
`Cache/`, and `Index/`.

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
