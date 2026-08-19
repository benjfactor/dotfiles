# Claude Code — Global Preferences

## Communication & Output
- Minimize conversational fluff and do not output full code blocks or text diffs in your responses unless explicitly asked.
- Summarize file changes in a single sentence (e.g., "Updated line 12 in server.js") instead of providing text-based diff previews.

## Workflow
- Always use git worktrees for feature branches. Never work directly on master/main.
- Worktree dir naming: `{repo}-{ticket}-{description}` (e.g. `atlas-kat-1309-simple-templates-nav`)
- Branch naming: `{ticket}-{description}` (e.g. `kat-1309-simple-templates-nav`)
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
- **This machine is an Apple M5 Pro (arm64) and Claude Code's bash runs natively arm64** — `uname -m`, `arch`, and `sysctl sysctl.proc_translated` (=0) all confirm no Rosetta. Earlier notes describing an Intel-cloned M1 Pro under Rosetta were stale; do not add `arch -arm64` wrappers.
- **One Homebrew: native arm64 at `/opt/homebrew`** (~34 formulae, incl. bash, go, git, gh, neovim, tmux, python@3.12, nvm, fzf). The old Intel Homebrew at `/usr/local` is **fully gone** — no `/usr/local/Homebrew`, no `/usr/local/Cellar`. A bare `brew install X` is correct and installs an arm64 build.
  - `/etc/paths` still lists `/usr/local/bin` first, but nothing Homebrew-related lives there anymore, so it no longer shadows brew. `/opt/homebrew/bin` comes from `/etc/paths.d/homebrew`. Don't add `brew shellenv` to `~/.bash_profile` — it symlinks into `~/dotfiles` and PATH is already handled.
- **No container runtime is installed.** colima, lima, docker, and docker-buildx are all absent (not in Cellar, not on PATH), there is no Docker Desktop/OrbStack/Rancher app, and no `~/.colima`/`~/.lima`/`~/.docker`. The old `~/Projects/colima-doctor.sh` no longer exists. If a task genuinely needs Docker, install a runtime first and tell Benj — don't assume one is running.
- **gcloud is installed outside Homebrew**: Google Cloud SDK 581.0.0 at `~/google-cloud-sdk`, put on PATH by `~/.bash_profile:76`. `mscli` is a Go binary at `~/go/bin/mscli` (via `GOBIN`).
- **Benj is in Regina, Saskatchewan: `America/Regina`, CST (UTC-6) year-round — Saskatchewan does not observe DST.** The system clock is set to `America/Edmonton`, so `date` reports MDT/MST. Wall time matches Regina in summer but is **one hour behind** from the November DST rollback until March. Use `TZ=America/Regina` whenever a timestamp's accuracy matters (log freshness windows, schedules, cron). Drop this caveat once the system zone is corrected.
