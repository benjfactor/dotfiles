## Review skill

review

Use Claude Code's built-in `review` skill as the primary reviewer — it runs an
adversarial verify pass and reports calibrated severities, which map onto the
dot + label comment style below.

Additionally layer the repo's own `.claude/review.md` agents when the repo has one
(the `local` flavor), then dedup findings across both before pushing. The repo
agents catch project-specific concerns the general reviewer won't — for the
`conversation` service that's Go over-engineering plus CLAUDE.md's deploy-time
risk check (new VStore Kinds, Temporal registrations, eager singleton network
calls).

## Comment style

Keep findings as tight as possible — one or two sentences max, no preamble. Never say "LGTM" in any comment or review body.

Compliments and appraisals are allowed but should be **rare** — reserve them for something that genuinely stands out and is worth the author's attention. Routine praise ("nice tests", "good description") is noise; leave it out.

PR-level comments must not just summarize what the PR does. The author knows what they wrote, and the description already covers it. A PR-level comment earns its place only if it says something the diff and description don't: a cross-cutting concern, a risk that spans files, a decision worth revisiting, or a question that isn't anchored to one line.

Lead every comment with a colored severity dot, then the label, so the author can triage at a glance. The dot matches PR Studio's own severity colors: 🔵 low, 🟡 medium, 🔴 high (e.g. `🔵 [NIT] …`, `🟡 [CONSIDER] …`, `🔴 [PLEASE ADDRESS] …`). Use the label that best fits the nature of the finding:

- **[NIT]** — Cosmetic or stylistic; the author can ignore without consequence.
- **[FYI]** — Informational, opinion, or future suggestion; no action expected.
- **[CONSIDER]** — A real concern worth thinking through; author's judgment call on whether to act.
- **[SUGGEST]** — A concrete alternative the author should weigh; still their call.
- **[PLEASE ADDRESS]** — I'd like to see this resolved before merge; a specific change is being requested.
- **[CAUTION]** — Flags a risk or concern rather than prescribing a fix; tread carefully here.

## Severity → prefix mapping

When the review tool assigns a severity, map it to the closest-fit prefix:

| Tool severity | Dot | Preferred prefix |
|---|---|---|
| LOW | 🔵 | **[NIT]** or **[FYI]** |
| MEDIUM | 🟡 | **[CONSIDER]** or **[SUGGEST]** |
| HIGH | 🔴 | **[PLEASE ADDRESS]** or **[CAUTION]** |

Use judgment within each tier — NIT for stylistic, FYI for informational; CONSIDER when open-ended, SUGGEST when a specific alternative exists; PLEASE ADDRESS when a change is clearly needed, CAUTION when surfacing a risk without a prescribed fix.

## Verdict meaning

- **Approve** — All comments are suggestions only, regardless of prefix. The PR is ready to merge as-is; findings are offered for the author's consideration.
- **Comment** — One or more findings feel important enough that I'm not comfortable saying the PR is merge-ready, but I don't need a discussion before the author proceeds.
- **Request Changes** — I'd like to discuss one or more findings before this merges.
