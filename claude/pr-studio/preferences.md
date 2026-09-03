## Review skill

review

Use Claude Code's built-in `review` skill as the primary reviewer — it runs an
adversarial verify pass and reports calibrated severities, which feed the
decoration guidance below.

Additionally layer the repo's own `.claude/review.md` agents when the repo has one
(the `local` flavor), then dedup findings across both before pushing. The repo
agents catch project-specific concerns the general reviewer won't — for the
`conversation` service that's Go over-engineering plus CLAUDE.md's deploy-time
risk check (new VStore Kinds, Temporal registrations, eager singleton network
calls).

## Comment style

Based on [Conventional Comments](https://conventionalcomments.org/), with a
smaller label set and an extra part in the body.

Every comment opens `**label (decoration):**` followed by what I'm looking at.
No emoji, no severity dots — the decoration carries the urgency.

**One label per comment.** If a line or block deserves two labels, that's two
comments, not one comment carrying both.

### Labels

- **problem** — something is wrong.
- **suggest** — a specific alternative exists and I'm naming it.
- **consider** — worth weighing, but I'm not proposing a specific answer.
- **question** — I need to understand something before I can judge it.
- **thought** — an idea worth floating, offered collaboratively.
- **fyi** — information offered without assuming the author doesn't already have it.
- **nit** — cosmetic. Rare; often better folded into a `suggest` so it reads like
  a person rather than a linter.

Praise has no fixed label. Write the short phrase that genuinely fits —
`**nice:**`, `**didn't expect this:**`, `**this is the good version:**`. Keep it
rare: reserve it for something that actually stands out and is worth the author's
attention. Routine praise ("nice tests", "good description") is noise; leave it out.

`todo` and `chore` from the standard are not used.

### Decorations

- **(blocking)** — I want to sync on this before it merges. Not "go fix this" — I
  want to be sure I've understood it, or that what I'm raising has been taken into
  account.
- **(non-blocking)** — worth saying, but it's the author's call.
- **(minor)** — only if it's cheap; skip it otherwise.

### Body

Up to three parts. Split only when splitting makes the comment clearer — most
comments don't need all three, and a one-part comment is often the right answer.

1. **What I'm looking at** — the label line itself. Always present.
2. **Why it matters** — what happens if this is or isn't addressed. Include it when
   the consequence isn't already obvious from the first part.
3. **What to do** — the next step. Often a question rather than an instruction.

Parts after the first open with a short bolded phrase that runs into the sentence
— a signpost, not a field name, so no colon. There is no fixed vocabulary: write
the phrase that fits the finding (`**Which means**`, `**Worth hoisting**`,
`**What do you think about**`, `**If you're already in there,**`). When there's
nothing to do, say so naturally or say nothing at all — never stamp a boilerplate
closer on the end.

### Voice

The label stays a short token; the warmth lives in the sentence. A `thought` reads
like "what do you think about…". An `fyi` offers information without assuming the
author doesn't know it — "in case it's useful…" — and without assuming they do.

Keep each comment as tight as the finding allows. Never say "LGTM" in any comment
or review body.

PR-level comments must not just summarize what the PR does. The author knows what
they wrote, and the description already covers it. A PR-level comment earns its
place only if it says something the diff and description don't: a cross-cutting
concern, a risk that spans files, a decision worth revisiting, or a question that
isn't anchored to one line.

### Examples

One part — nothing to add:

> **question (non-blocking):** is the 30s timeout deliberate here, or inherited
> from the old client?

Two parts — the impact is obvious, the action isn't:

> **suggest (non-blocking):** three callers now build the same header map.
>
> **Worth hoisting** into `internal/http/headers.go` before they drift.

Three parts — the why is doing real work:

> **problem (blocking):** `retryCount` is never reset after a successful call.
>
> **Which means** the next failure starts at the cap, so one transient error
> degrades the retry budget for the life of the process.
>
> **What do you think about** resetting it in the success branch? I'd want to
> confirm the cap isn't intentional first.

A nit, kept cheap:

> **nit (minor):** `usrCnt` reads as a count of `usr`.
>
> **If you're already in there,** `userCount` matches the other fields.

Praise, with no fixed label:

> **this is the good version:** wrapping with `context.Cause` keeps the cancel
> reason alive all the way to the log line.

## Severity → decoration

The review tool assigns LOW / MEDIUM / HIGH. Treat it as a starting point, not a
mapping. The decoration says how much I want to talk about a finding, which isn't
the same thing as how severe the finding is.

As a rough guide: HIGH is usually `(blocking)`, MEDIUM is usually
`(non-blocking)`, LOW is usually `(minor)` or `(non-blocking)`.

Override it whenever the finding warrants. A LOW-severity design question I
genuinely want to discuss is `(blocking)`; a HIGH-severity issue the author has
clearly already weighed may not be.

## Verdict meaning

- **Approve** — All comments are suggestions only, regardless of label. The PR is
  ready to merge as-is; findings are offered for the author's consideration.
- **Comment** — One or more findings feel important enough that I'm not comfortable
  saying the PR is merge-ready, but I don't need a discussion before the author
  proceeds.
- **Request Changes** — I'd like to discuss one or more findings before this merges.

## Discovery sources

chat: tagged
github: teams

## Watched chat spaces

# Meerkats team PR channel
AAAAIj8WMWc
