# iTerm2 settings

Portable iTerm2 configuration, synced across machines through this repo.

`com.googlecode.iterm2.plist` in this folder **is** the settings file — iTerm2
reads and writes it directly via its built-in "load settings from a custom
folder" feature.

---

## Setting up a new machine

```bash
git clone git@github.com:benjvictor/dotfiles.git ~/dotfiles   # if not already there
cd ~/dotfiles/terminal/iterm2

# Quit iTerm2 first (Cmd-Q), then run this from Terminal.app:
./setup.sh
```

Then open iTerm2 and confirm in **Settings → General → Settings tab**:

- ☑︎ *Load settings from a custom folder or URL* → `~/dotfiles/terminal/iterm2`
- *Save changes*: **Automatically**

That second setting is what makes edits flow back into the repo. `setup.sh`
can't set it reliably from the command line (it lives under a `NoSync*` key
that iTerm2 manages itself), so it's a one-time manual click per machine.

### Why quit iTerm2 first?

iTerm2 rewrites its entire preferences domain when it quits. If it's running
while `setup.sh` changes those preferences, the quit will overwrite them and
the setup silently won't stick. `setup.sh` refuses to run if it detects iTerm2
and tells you the same thing.

`setup.sh` backs up the machine's existing local plist to
`~/Library/Preferences/com.googlecode.iterm2.plist.backup-<timestamp>` before
switching, so this is reversible.

---

## Pushing your latest settings before switching machines

On the machine whose settings you want to keep:

```bash
cd ~/dotfiles/terminal/iterm2
./sync.sh          # or ./sync.sh --push
```

It exports the live settings, strips machine-local keys, shows you a diff, and
offers to commit. Run it **before** you go set up or refresh another machine —
otherwise the destination pulls a stale snapshot.

With *Save changes: Automatically* on, iTerm2 usually keeps this file current
on its own and `sync.sh` will just report "no changes". It's the belt-and-braces
path for when auto-save is off, or when you want the commit handled for you.

If iTerm2 is running when you sync, changes made in that session may not have
been flushed to disk yet. `sync.sh` warns and lets you either bail out or
continue. To force a flush without quitting: **Settings → General → Settings →
Save Settings to Folder**.

---

## Do not symlink the plist

The obvious-looking approach — symlinking
`~/Library/Preferences/com.googlecode.iterm2.plist` into this repo — **does not
work on macOS** and is the trap most dotfiles guides fall into.

`cfprefsd` (the system preferences daemon) caches preference domains in memory
and rewrites the backing file on its own schedule. It replaces symlinks with
regular files, serves stale values back to the app, and drops writes made by
`defaults` while the owning app is running. The custom-folder feature exists
precisely so you don't have to fight it: iTerm2 does its own file I/O against
this directory, entirely outside `cfprefsd`.

---

## What is and isn't synced

**Synced:** profiles, colour presets, key mappings, fonts, window/tab
appearance, general behaviour settings.

**Not synced:** any key prefixed `NoSync*` — iTerm2's own marker for
machine-local state (recent directories and hosts, command history flags,
per-window geometry, "don't remind me again" dismissals). `sync.sh` strips
these on export. This is deliberate on iTerm2's part, not a workaround.

## Note on this being a public repo

`benjvictor/dotfiles` is public. iTerm2 profiles can accumulate hostnames,
custom command lines, working directories, and badge text. Nothing sensitive
was present when this was set up, but glance at the `sync.sh` diff before
committing. If something private lands here, move this folder to a private
repo rather than trying to scrub git history.
