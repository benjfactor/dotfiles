#!/usr/bin/env bash
# Install the three fonts the terminals here reference, into ~/Library/Fonts.
#
# Idempotent: a family already registered under the right PostScript name is
# skipped. Run with --force to reinstall anyway.
#
# Fonts are matched on PostScript name, not filename -- FiraMonoNF-Regular
# ships inside a file called FiraMonoNerdFont-Regular.otf. See SETUP.md.

set -euo pipefail

DEST="$HOME/Library/Fonts"
FORCE=false
[[ "${1:-}" == "--force" ]] && FORCE=true

POWERLINE_RAW="https://github.com/powerline/fonts/raw/master"
NERD_LATEST="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"

installed=0 skipped=0

have_font() {
  command -v fc-list >/dev/null 2>&1 || return 1
  local names
  names="$(fc-list --format='%{postscriptname}\n' 2>/dev/null || true)"
  [[ $'\n'"$names"$'\n' == *$'\n'"$1"$'\n'* ]]
}

# install_powerline <postscript-name> <repo-subdir> <file>...
#
# Deliberately not the font-dejavu-sans-mono-nerd-font cask: that is the Nerd
# Font build and registers a different PostScript name, so it does not satisfy
# the iTerm2 setting even though the name looks right.
install_powerline() {
  local ps="$1" dir="$2"
  shift 2

  if ! $FORCE && have_font "$ps"; then
    echo "skip     $ps (already installed)"
    skipped=$((skipped + 1))
    return
  fi

  echo "fetch    $ps"
  local file
  for file in "$@"; do
    # %20 rather than literal spaces: every one of these filenames has them.
    curl -fsSL -o "$TMP/$file" "$POWERLINE_RAW/$dir/${file// /%20}"
    cp "$TMP/$file" "$DEST/$file"
    echo "install  $file"
  done
  installed=$((installed + 1))
}

mkdir -p "$DEST"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

install_powerline DejaVuSansMonoPowerline DejaVuSansMono \
  "DejaVu Sans Mono for Powerline.ttf" \
  "DejaVu Sans Mono Bold for Powerline.ttf" \
  "DejaVu Sans Mono Oblique for Powerline.ttf" \
  "DejaVu Sans Mono Bold Oblique for Powerline.ttf"

install_powerline LiterationMonoPowerline LiberationMono \
  "Literation Mono Powerline.ttf" \
  "Literation Mono Powerline Bold.ttf" \
  "Literation Mono Powerline Italic.ttf" \
  "Literation Mono Powerline Bold Italic.ttf"

if ! $FORCE && have_font FiraMonoNF-Regular; then
  echo "skip     FiraMonoNF-Regular (already installed)"
  skipped=$((skipped + 1))
else
  echo "fetch    FiraMonoNF-Regular (FiraMono.zip, ~13MB)"
  curl -fsSL -o "$TMP/FiraMono.zip" "$NERD_LATEST/FiraMono.zip"
  unzip -o -q "$TMP/FiraMono.zip" -d "$TMP/fira"
  # The plain FiraMonoNerdFont-* build is what iTerm2 references. The Mono and
  # Propo builds in the same zip carry different PostScript names (NFM-, NFP-)
  # and would not satisfy the setting.
  find "$TMP/fira" -name 'FiraMonoNerdFont-*.otf' -exec cp {} "$DEST/" \;
  echo "install  FiraMonoNerdFont-*.otf"
  installed=$((installed + 1))
fi

echo
echo "installed: $installed   skipped: $skipped"
echo
echo "Verify (PostScript names, not filenames):"
echo "  fc-list --format='%{postscriptname}\\n' | grep -E 'Powerline|NF-'"
echo
echo "Restart the terminal app to pick up newly installed fonts."
