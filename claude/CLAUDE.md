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
- **Two Homebrews on this M1 Pro** — Intel at `/usr/local` (~162 formulae, the main one) and native arm64 at `/opt/homebrew` (colima, lima, docker, docker-buildx only).
  - Claude Code's bash runs under Rosetta, so a bare `brew install X` silently installs the **x86_64** build. To target the arm64 brew: `arch -arm64 /bin/bash -c '/opt/homebrew/bin/brew install <formula>'`
  - Verify with `brew config` — the arm64 one reports `macOS: <ver>-arm64` and `Rosetta 2: false`.
  - `/etc/paths` puts `/usr/local/bin` first, so Intel wins ties. Don't add `brew shellenv` to `~/.bash_profile` — it symlinks into `~/dotfiles` and PATH is already handled by `/etc/paths.d/homebrew`.
- Container runtime is **colima**, not Docker Desktop. Start with `colima start --vm-type vz --vz-rosetta --cpu 4 --memory 8`. Health-check the full Docker surface mscli needs with `bash ~/Projects/colima-doctor.sh`.
