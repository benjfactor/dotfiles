# Claude Code — Global Preferences

## Communication & Output
- Minimize conversational fluff and do not output full code blocks or text diffs in your responses unless explicitly asked.
- Summarize file changes in a single sentence (e.g., "Updated line 12 in server.js") instead of providing text-based diff previews.

## Workflow
- Always use git worktrees for feature branches. Never work directly on master/main.
- Worktree dir naming — **all lowercase**, hyphens: `{repo}-{ticket-lower}-{description}` (e.g. `atlas-kat-1309-simple-templates-nav`)
- Branch naming — **uppercase ticket**, slash before the description: `{TICKET}/{description}` (e.g. `KAT-1309/simple-templates-nav`). The **uppercase** is the part that matters: the global `prepare-commit-msg` hook greps `[A-Z]+-[0-9]+` off the branch name to append the Jira ID, so a lowercase ticket silently gets no ID. The slash is convention, not a hook requirement — a hyphenated branch still gets its ID. See the `git-worktree-jira-branch` skill.
- A new worktree's branch must **not** track `origin/master` (`git worktree add -b` from `origin/master` sets that by default — `git branch --unset-upstream`). `push.default = simple` means a bare `git push` refuses rather than pushing to master, but it then suggests `git push origin HEAD:master` — don't paste that. Create the remote on first push: `git push -u origin '{TICKET}/{description}'`
- Start with a draft PR, mark ready only when explicitly asked.
- Small, focused commits. Use conventional commits (`feat`, `fix`, `docs`, `chore`).
- Commit messages focus on WHY, not what changed.
- **After every `ce:plan` completes:** immediately invoke the `plan-commit-to-worktree` skill without waiting for the user to ask. It moves the plan file into a new worktree and commits it.

## PR Reviews
- Always tag `@vendasta/meerkats` in PR descriptions.
- Use the `pr-ready` skill when marking PRs ready for review.
- Use the `notify-pr-channels` skill for Google Chat notifications.
  - Meerkats team PR channel: `AAAAIj8WMWc` (always @Craig and @Daniel)

## Bash Tool Rules
- For commands that must run inside a specific directory, use the tool's built-in directory flag instead of `cd <dir> && <command>`:
  - **git**: `git -C <path> <subcommand>` (e.g., `git -C /path/to/repo pull`)

## Dev Environment
- Galaxy dev server: `PID=VUNI NODE_OPTIONS=--max_old_space_size=12000 npm run start business-center-client` (run from galaxy worktree)
- Auth tokens: `mscli auth session --env {demo|prod} --skip-version-check`
- **Apple M5 (arm64). Check whether the shell is translated before trusting `brew`:** `uname -m` (`arm64` = native, `x86_64` = Rosetta), or `sysctl -n sysctl.proc_translated` (0/1). **If translated, a bare `brew` reports itself x86_64 and will fetch Intel bottles into `/opt/homebrew`** — use `arch -arm64 brew ...`. When native, plain `brew` is correct and `arch -arm64` is a harmless no-op. Arch is fixed at exec time, so a running process can never change — only a fresh one can.
  - Cause of past translation: a stale **Intel tmux 3.4 server** (pid 2558, running since Aug 25 with Rosetta's `oah` AOT cache) kept spawning x86_64 shells; every descendant, Claude Code included, inherited the preference. That server was killed 2026-09-04 and tmux is now native 3.7c at `/opt/homebrew`. iTerm2 itself is arm64 — it was never an "Open using Rosetta" setting.
- **One Homebrew: arm64 at `/opt/homebrew`** (~77 formulae). The Intel Homebrew at `/usr/local` was removed 2026-09-04 — ~5.2GB of Cellar/Homebrew/Caskroom plus 3168 symlinks. `/usr/local` still holds NON-brew things that must not be deleted: `go/` (the Go toolchain), `mysql/` (standalone MySQL), `remotedesktop/`, `man/`, `n/`, and assorted pip/composer scripts in `bin/`.
  - `/etc/paths` lists `/usr/local/bin` first, so `~/.bash_profile` prepends `$HOME/.local/bin:/opt/homebrew/bin:/opt/homebrew/sbin` to win. Don't add `brew shellenv` — PATH is already handled.
- **Python is uv, not pyenv.** `uv` (brew) owns Python; `python3` = 3.13.15 arm64 via shims in `~/.local/bin`. **pyenv and rbenv are gone, and there is no Ruby toolchain** (system `/usr/bin/ruby` only) — both their runtimes were x86_64 builds linked against Intel brew. Note brew pulls in `python@3.14` as a dependency; it must stay behind `~/.local/bin` on PATH.
- **Container runtime IS installed**: `colima`, `lima`, `docker`, `docker-buildx` at `/opt/homebrew`, with `~/.colima` configured `vmType: vz` (Apple Virtualization, NOT qemu) and `arch: aarch64`. It is usually stopped — run `colima start`; don't assume a daemon is up.
- **gcloud is installed outside Homebrew**: Google Cloud SDK 568.0.0 at `~/google-cloud-sdk`, put on PATH by `~/.bash_profile:76`. `mscli` is a Go binary at `~/go/bin/mscli` (via `GOBIN`). Go itself is a standalone tarball at `/usr/local/go`, not a formula.
- **Benj is in Regina, Saskatchewan: `America/Regina`, CST (UTC-6) year-round — Saskatchewan does not observe DST.** Local time never shifts, so it matches Mountain in summer and Central in winter. **Keep macOS automatic timezone OFF:** geolocation repeatedly guesses `America/Edmonton`, which looks identical all summer and silently becomes a one-hour error from the November rollback until March — it corrupts log-freshness windows and scheduled runs with no visible failure. Verified corrected 2026-08-19.
