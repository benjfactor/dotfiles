---
name: wsu
description: Create and fill a new Weekly Status Update (WSU) Confluence page. Use when the user wants to create a new WSU or update the current week's status. Gathers data from GitHub, GChat, and git commits, then runs a short questionnaire for contributions not visible in tooling.
---

# Weekly Status Update (WSU)

Creates or fills a WSU page for the current week. Gathers data from multiple sources, runs a questionnaire for off-system contributions, and writes the page.

## Confluence config

| Field | Value |
|-------|-------|
| Cloud ID | `77fcf126-19b9-4276-9a8f-9d9fa1efe60f` |
| Space ID | `1518010429` |
| Space key | `~106705950` |

Quarter parent pages (add new ones as quarters roll over):

| Quarter | Page ID | Title |
|---------|---------|-------|
| Q2 2026 | `4046848046` | WSU 2026 Q2 |
| Q3 2026 | `4344840197` | WSU 2026 Q3 |

To find the parent for a future quarter, search Confluence for a page titled "WSU YYYY QN" in the space.

## Title convention

`Benj Hingston - YYYY-MM-DD QJWK`

- **YYYY-MM-DD** — the Friday of the **previous** work week (the skill is run on Monday)
- **J** — quarter number (1 = Jan–Mar, 2 = Apr–Jun, 3 = Jul–Sep, 4 = Oct–Dec)
- **K** — week number within the quarter; find the most recent child page under the quarter parent and increment K by 1. Note: K can jump by more than 1 if Benj was on vacation.

## Steps

### 1. Determine the title and target page

1. Get today's date. The skill is run on **Monday** — compute the Friday of the **previous** ISO work week (i.e. 3 days ago if today is Monday).
2. Derive the quarter from that Friday's month.
3. List children of the quarter parent page (ordered by `created DESC`) and read the last K used — increment by 1.
4. Construct the title: `Benj Hingston - YYYY-MM-DD QJWK`
5. **Check if the page already exists** (it may have been pre-created). If so, use `updateConfluencePage`. If not, use `createConfluencePage` at the end.

### 2. Read the previous week's WSU

Fetch the most recent existing page to see the **Plan** section. Progress this week should reflect it.

### 3. Read weekly notes

Check for in-the-moment notes captured throughout the week. Since the skill runs on Monday, read the **previous** ISO week's file:
```bash
cat ~/.claude/wsu/$(date -v-7d +%G-W%V 2>/dev/null || date -d "7 days ago" +%G-W%V).md 2>/dev/null
```
If the file exists, these notes are high-confidence inputs — Benj captured them deliberately. Treat them as primary source material, not hints.

### 4. Gather data (run in parallel)

**GitHub — PRs opened/merged:**
```bash
gh search prs --author=bhingston-va --created="MON..SUN" --limit 20
gh search prs --author=bhingston-va --merged="MON..SUN" --limit 20
```

**GitHub — PRs reviewed:**
```bash
gh search prs --reviewed-by=bhingston-va --updated="MON..SUN" --limit 20
```

Date range is the previous **Monday through Sunday** (7 days). Run on Monday, so SUN = yesterday.

**Git commits** — lead with worktrees, which is where active work lives:
```bash
# Find all active worktrees across key repos
git -C /Users/bhingston/Projects/crm-integrations worktree list 2>/dev/null
git -C /Users/bhingston/Projects/all-mail worktree list 2>/dev/null
# Check any galaxy* directories found under /Users/bhingston/Projects
```
Then for each worktree path found, run:
```bash
git -C <worktree-path> log --author="bhingston\|Benj" --after="YYYY-MM-DD" --before="YYYY-MM-DD" \
  --format="%ad %s" --date=short 2>/dev/null
```
Also check base repos directly (commits on master). Skip anything with zero output.

**GChat** — the notes file (step 3) is the primary source for chat signals, since Benj flags high-signal threads in the moment via `wsu-note`. **Prefer fetching the specific thread URLs from the notes file** — fetching a whole space downloads years of attachments and is slow/expensive.

Resolve the fetcher script path dynamically (the plugin version changes, and the path moved to `skills/google-chat-fetcher/scripts/` in 0.13.0+):
```bash
FETCH=$(find ~/.claude/plugins/cache -name fetch_chat.py 2>/dev/null | sort -V | tail -1)
python3 "$FETCH" fetch "<thread-url-from-notes>"
```
Then read the saved file under `~/Projects/.claude/fetcher/google-chat/<space-id>/` (a thread URL writes `thread.md`; a bare space URL writes `messages.md`).

Only fetch a whole space if the user explicitly asks and there are no flagged threads — then grep the resulting `messages.md` to the Mon–Sun window before reading. GChat surfaces decisions and cross-team context not visible in code.

### 5. Questionnaire

Ask these conversationally — not as a rigid form. The goal is to surface contributions that don't show up in GitHub, git, or the weekly notes file. If the notes file already covers a question, skip it or use it as a prompt: *"Your notes mention X — anything to add?"*

1. **Meetings** — Any meetings this week that led to a notable decision, changed direction, or unblocked something? *If yes: did you initiate the meeting, or were you pulled in?*
2. **Cross-team / stakeholder** — Any collaboration outside the immediate team (other squads, PMs, staff eng, other programs)?
3. **Helping teammates** — Significant mentoring, pairing, or unblocking beyond formal PR reviews?
4. **Blockers** — Anything stuck that needs help from others (for Problems section)?
5. **Next week** — Top 2–4 priorities?

### 6. Synthesise and write

Combine GitHub, GChat, git, and questionnaire answers into concise PPP content.

**Writing guidelines:**
- **Less is more.** Notable achievements only — not a ticket dump.
- **Progress** should reflect last week's Plan. Focus on senior-dev-level signals: shipped features, validated technical hypotheses before building, architectural decisions, cross-team impact, unblocking others.
- **Proactivity matters.** If Benj initiated a meeting, reached out to another team, or flagged a problem unprompted — write it that way. "Reached out to…" and "Initiated a conversation with…" read very differently from "consulted by" or "met with." Don't flatten that signal.
- Don't echo ticket titles — capture *what mattered and why*.
- **Plan**: top 2–4 priorities from in-progress work and questionnaire.
- **Problems**: only genuine blockers needing outside help. Leave blank if none.
- **No boilerplate** — no instructions or filler text in the page body.

Page structure:
```
**Progress**

* <item>

‌

**Plan**

* <item>

‌

**Problems**

* <item or blank>
```

### 7. Create or update the page

**If the page already exists** (found in step 1):
```
updateConfluencePage:
  cloudId:       77fcf126-19b9-4276-9a8f-9d9fa1efe60f
  pageId:        <existing page ID>
  contentFormat: markdown
  body:          <filled PPP content>
```

**If the page does not exist:**
```
createConfluencePage:
  cloudId:       77fcf126-19b9-4276-9a8f-9d9fa1efe60f
  spaceId:       1518010429
  parentId:      <quarter parent page ID>
  title:         <derived title>
  contentFormat: markdown
  body:          <filled PPP content>
```

Return the page URL. If the page was newly created, remind the user to drag it to the top of the parent in the Confluence sidebar — the API cannot reorder pages.

## Notes

- The skill runs on **Monday**. The title date is the previous Friday. Don't use today's date as the title.
- Week numbers can skip (vacation); always derive K from the last existing page, not by counting from quarter start.
- The spaceId must be a numeric Long (`1518010429`), not the space key (`~106705950`) — the API rejects the key.
