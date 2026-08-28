#!/usr/bin/env bash
# Set up this machine from the dotfiles repo.
#
# Idempotent and safe to re-run: anything it would overwrite is moved into a
# timestamped backup directory first, and links that are already correct are
# left alone. Run with --dry-run to see the plan without touching anything.
#
# See SETUP.md for what this does and why the .claude layer is unusual.

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

created=0 skipped=0 backed_up=0

# Refuse to run from a git worktree unless forced. Every link this script makes
# is absolute, so bootstrapping from a throwaway worktree would silently point
# ~/.vimrc, ~/.claude and friends at a directory that gets deleted when the
# branch is cleaned up -- leaving a machine full of dangling symlinks.
if [[ -f "$DOTFILES/.git" ]] && [[ "${FORCE_WORKTREE:-}" != "1" ]]; then
  printf '%s\n' \
    "refusing to run: $DOTFILES is a git worktree, not the main checkout." \
    "Links would point here and break when the worktree is removed." \
    "" \
    "Run this from your real clone (e.g. ~/dotfiles), or set FORCE_WORKTREE=1" \
    "if you genuinely mean to bootstrap against this worktree." >&2
  exit 1
fi

say()  { printf '%s\n' "$*"; }
run()  { if $DRY_RUN; then say "    would: $*"; else "$@"; fi; }

# link <path-relative-to-repo> <absolute-link-path>
# Creates link -> $DOTFILES/<relative>, preserving anything already there.
link() {
  local target="$DOTFILES/$1" link_path="$2" label="~${2#$HOME}"

  if [[ ! -e "$target" ]]; then
    say "SKIP  $label  (target missing in repo: $1)"
    skipped=$((skipped + 1))
    return
  fi

  # Already correct? readlink -f resolves both sides so a trailing slash or a
  # relative link that happens to point at the same place still counts.
  if [[ -L "$link_path" ]] && [[ "$(readlink -f "$link_path" 2>/dev/null)" == "$(readlink -f "$target")" ]]; then
    say "ok    $label"
    skipped=$((skipped + 1))
    return
  fi

  if [[ -e "$link_path" || -L "$link_path" ]]; then
    run mkdir -p "$BACKUP_DIR"
    run mv "$link_path" "$BACKUP_DIR/"
    say "MOVED $label -> backup"
    backed_up=$((backed_up + 1))
  fi

  [[ -d "$(dirname "$link_path")" ]] || run mkdir -p "$(dirname "$link_path")"
  run ln -s "$target" "$link_path"
  say "LINK  $label -> $1"
  created=$((created + 1))
}

say "dotfiles: $DOTFILES"
$DRY_RUN && say "(dry run -- nothing will be changed)"
say

# ---------------------------------------------------------------------------
say "== shell, git, tmux, vim =="
link .bash_profile                     "$HOME/.bash_profile"
# readline config: case-insensitive completion and arrow-key history search.
# Small file, easy to forget, and its absence is felt immediately.
link .inputrc                          "$HOME/.inputrc"
link gitfiles/.gitconfig               "$HOME/.gitconfig"
link gitfiles/.githooks                "$HOME/.githooks"
link gitfiles/.git-templates           "$HOME/.git-templates"
link gitfiles/.gitmux.conf             "$HOME/.gitmux.conf"
link .tmux.conf                        "$HOME/.tmux.conf"
link .tmux                             "$HOME/.tmux"
link tmux_battery_charge_indicator.sh  "$HOME/tmux_battery_charge_indicator.sh"
link vimide/.vimrc                     "$HOME/.vimrc"
link vimide/.vim                       "$HOME/.vim"
link vimide/.ctags                     "$HOME/.ctags"

# Neovim is the real editor here (see SETUP.md) and reads its runtimepath from
# the XDG config dir, not ~/.vim. Without this link nvim cannot find
# autoload/plug.vim, so `plug#begin` is undefined and every single Plug line in
# .vimrc errors out -- vim-plug never loads and no plugin works at all.
#
# .vimrc itself is found separately, via VIMINIT/MYVIMRC exported by
# .bash_profile, so a broken editor here still *looks* configured.
link vimide/.vim                       "$HOME/.config/nvim"

# ---------------------------------------------------------------------------
# ~/.claude is Claude Code's own runtime directory: sessions, jobs, history,
# daemon state. This script never moves or replaces it. Doing so would tear a
# live session's state out from under it -- and you are quite likely running
# this script from inside exactly such a session.
#
# Only the five tracked config entries get linked in. It does not matter
# whether ~/.claude is a real directory (new machines) or itself a symlink into
# this repo (the older layout, see SETUP.md): the links resolve to the same
# place either way, so this is correct and idempotent on both.
say
say "== claude =="
CLAUDE_DIR="$HOME/.claude"
if [[ -e "$CLAUDE_DIR" ]]; then
  say "ok    ~/.claude exists (left alone)"
else
  say "MKDIR ~/.claude"
  run mkdir -p "$CLAUDE_DIR"
fi
link claude/CLAUDE.md             "$CLAUDE_DIR/CLAUDE.md"
link claude/settings.json         "$CLAUDE_DIR/settings.json"
link claude/hooks                 "$CLAUDE_DIR/hooks"
link claude/skills                "$CLAUDE_DIR/skills"
link claude/statusline-command.sh "$CLAUDE_DIR/statusline-command.sh"

# PR Studio reads its global review preferences from a nested path, so the
# directory has to exist before the link can go in. Everything else under
# ~/.claude/pr-studio is per-review runtime state and stays local.
if [[ ! -d "$CLAUDE_DIR/pr-studio" ]]; then
  say "MKDIR ~/.claude/pr-studio"
  run mkdir -p "$CLAUDE_DIR/pr-studio"
fi
link claude/pr-studio/preferences.md "$CLAUDE_DIR/pr-studio/preferences.md"

# ---------------------------------------------------------------------------
# Which directory Sublime reads cannot be derived from the installed version.
# Sublime 4 uses the un-suffixed "Sublime Text" path on a clean install, but
# when it finds a Sublime 3 data directory it adopts it and keeps writing
# there -- verified on this machine, where build 4200 runs entirely out of
# "Sublime Text 3". So probe for the legacy directory first and only fall back
# to the modern path. Hardcoding either one silently links into a directory
# Sublime never opens, and settings simply do not take effect.
say
say "== sublime text =="
ST_SUPPORT="$HOME/Library/Application Support"
if [[ -d "$ST_SUPPORT/Sublime Text 3" ]]; then
  ST_PACKAGES="$ST_SUPPORT/Sublime Text 3/Packages"
  say "ok    using legacy data dir (Sublime Text 3)"
else
  ST_PACKAGES="$ST_SUPPORT/Sublime Text/Packages"
  say "ok    using current data dir (Sublime Text)"
fi

# The whole User directory is linked rather than the settings files inside it.
# Sublime writes every new keymap, snippet and per-plugin setting into that
# directory, so linking files one by one would leave each new one untracked --
# and settings would appear to sync right up until the day you add one.
link sublime/User "$ST_PACKAGES/User"

# Package Control restores the Colorsublime *plugin* from installed_packages,
# but not the themes that plugin downloaded: those land loose in this directory
# and exist nowhere else. Preferences.sublime-settings points color_scheme
# straight at FireCode.tmTheme, so without this the restore looks complete and
# Sublime still opens on the default colours. Tracking the .tmTheme also means
# the scheme survives Colorsublime itself going unmaintained -- Sublime loads
# any directory under Packages/ whether or not a plugin manages it.
link "sublime/themes/FireCode.tmTheme" "$ST_PACKAGES/Colorsublime - Themes/FireCode.tmTheme"

# ---------------------------------------------------------------------------
# tmux plugins are managed by TPM, which is itself a plugin fetched by git.
# It is deliberately not tracked in this repo, so a fresh clone has no TPM and
# .tmux.conf's `run '~/.tmux/plugins/tpm/tpm'` silently does nothing.
say
say "== tmux plugin manager =="
TPM_DIR="$DOTFILES/.tmux/plugins/tpm"
if [[ -d "$TPM_DIR/.git" ]]; then
  say "ok    tpm already installed"
else
  say "CLONE tpm"
  run git clone -q https://github.com/tmux-plugins/tpm "$TPM_DIR"
fi

# ---------------------------------------------------------------------------
say
say "== external tools =="
missing=()
check() {
  if command -v "$1" >/dev/null 2>&1; then
    say "ok    $1"
  else
    say "MISS  $1  ($2)"
    missing+=("$1")
  fi
}
# nvm is a shell function sourced by .bash_profile, never a binary on PATH,
# so `command -v nvm` reports missing even on a machine where it works fine.
# Check for the script .bash_profile actually sources instead.
check_file() {
  if [[ -s "$2" ]]; then
    say "ok    $1"
  else
    say "MISS  $1  ($3)"
    missing+=("$1")
  fi
}

# The two programs this whole setup exists to configure. Checked first and
# explicitly: the manual steps below tell you to run `nvim` and `tmux`, so
# failing to verify them means the script can report success on a machine where
# neither is installed.
say "-- editors and shell --"
check      nvim   "brew install neovim  -- THE editor; .vim naming is historical"
check      tmux   "brew install tmux"
check      brew   "https://brew.sh"
check      go     "brew install go"

say "-- version managers --"
check      fzf    "brew install fzf"
check      pyenv  "brew install pyenv"
check      rbenv  "brew install rbenv"
check_file nvm    "${NVM_DIR:-$HOME/.nvm}/nvm.sh" "brew install nvm"

# Plugins shell out to these at runtime. Each fails quietly when absent -- the
# plugin loads, then simply does nothing.
say "-- plugin runtime deps --"
check      gitmux       "go install github.com/arl/gitmux@latest  -- tmux status line git section"
check      node         "brew install node  -- coc.nvim runtime"
check      ctags        "brew install universal-ctags  -- vim-autotag; ~/.ctags is linked"
check      rg           "brew install ripgrep  -- vim-ripgrep"
check      code-minimap "brew install code-minimap  -- minimap.vim"
check      dig          "ships with macOS  -- tmux status line"
# Claude Code plugins install themselves from settings.json (enabledPlugins +
# extraKnownMarketplaces), but LSP plugins do not install their language server.
# gopls-lsp loads fine without gopls and then silently provides no diagnostics.
check      gopls        "go install golang.org/x/tools/gopls@latest  -- gopls-lsp plugin"
# No reattach-to-user-namespace check: .tmux.conf no longer uses it. tmux has
# reached the macOS pasteboard directly since 2.6.

# Needed BEFORE :PlugInstall, not after. Three plugins compile on install and
# fail partway through if the toolchain is absent, leaving a half-installed
# plugin set that looks like a network problem.
say "-- build toolchain (needed before :PlugInstall) --"
check      make   "xcode-select --install  -- vim-hexokinase"
check      cc     "xcode-select --install  -- nvim-treesitter :TSUpdate"
check      cargo  "brew install rust  -- codesnap.nvim"

say "-- python packages --"
# tmux-window-name is a Python plugin: without libtmux it fails silently and
# windows just never get renamed, which reads as "the plugin didn't install"
# rather than "a dependency is missing".
if python3 -c 'import libtmux' >/dev/null 2>&1; then
  say "ok    libtmux"
else
  say "MISS  libtmux  (pip3 install --user libtmux  -- needed by tmux-window-name)"
  missing+=("libtmux")
fi

say "-- fonts --"
# The three fonts the terminals reference, matched on PostScript name (which is
# not the filename: FiraMonoNF-Regular lives in FiraMonoNerdFont-Regular.otf).
# Missing ones fall back silently to a default face, so powerline separators and
# glyphs render as boxes rather than erroring.
#
# Collected once into a variable and matched with bash rather than piping into
# `grep -q`: under `set -o pipefail`, grep exits on the first match and SIGPIPEs
# fc-list, so the pipeline reports failure for any font found early in the list.
if command -v fc-list >/dev/null 2>&1; then
  font_names="$(fc-list --format='%{postscriptname}\n' 2>/dev/null || true)"
  for f in DejaVuSansMonoPowerline FiraMonoNF-Regular LiterationMonoPowerline; do
    if [[ $'\n'"$font_names"$'\n' == *$'\n'"$f"$'\n'* ]]; then
      say "ok    font $f"
    else
      say "MISS  font $f  (see SETUP.md -- Fonts)"
      missing+=("font:$f")
    fi
  done
else
  say "?     fonts  (cannot verify -- fc-list not installed; brew install fontconfig)"
fi

say "-- macos defaults --"
# AppKit keys that iTerm2 keeps in its preference domain but refuses to write
# into its own settings file, so they cannot be tracked in the plist at all.
# appkit-defaults.sh explains why; the sharp one is ApplePressAndHoldEnabled,
# without which holding a key in vim opens the accent picker instead of
# repeating. Deliberately not added to `missing`: these are not installable
# tools, they are settings, and they have their own script.
appkit_missing=false
if "$DOTFILES/terminal/iterm2/appkit-defaults.sh" --check >/dev/null 2>&1; then
  say "ok    iterm2 appkit defaults"
else
  say "MISS  iterm2 appkit defaults  (terminal/iterm2/appkit-defaults.sh)"
  appkit_missing=true
fi

# ---------------------------------------------------------------------------
say
say "-------------------------------------------------------------"
say "linked: $created   already ok: $skipped   backed up: $backed_up"
[[ $backed_up -gt 0 ]] && say "backups: $BACKUP_DIR"
say
say "Remaining manual steps:"
# Counted rather than hardcoded: the font and missing-tools steps are
# conditional, so fixed numbers skip a digit whenever one does not apply.
step=0
next_step() { step=$((step + 1)); say "  $step. $1"; }

next_step "nvim +PlugInstall +qall         # install neovim plugins"
next_step "tmux, then prefix + I           # install tmux plugins via TPM"
next_step "terminal/iterm2/setup.sh        # iTerm2 settings (quit iTerm2 first)"

# Fonts have their own installer; everything else is left to you deliberately.
fonts_missing=false
for m in ${missing[@]+"${missing[@]}"}; do
  case "$m" in font:*) fonts_missing=true;; esac
done
$fonts_missing && next_step "./install-fonts.sh              # install the missing fonts"
$appkit_missing && next_step "terminal/iterm2/appkit-defaults.sh  # AppKit keys iTerm2 will not store"
[[ ${#missing[@]} -gt 0 ]] && next_step "install missing tools: ${missing[*]}"
say
say "See SETUP.md for details."
