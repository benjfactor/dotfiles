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
- **question** — I'm not sure I've understood. Ask the author to supply what I
  can't see rather than asserting a defect: "am I reading this right — if
  `retryCount` isn't reset on success, wouldn't the next failure start at the
  cap?" The wording is mine to pick; the point is to invite the explanation
  instead of making them disprove an accusation.
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

**Most comments carry none.** A bare label is a real finding that doesn't stop the
merge — that's the default, and the default needs no marker. Two decorations
exist, because each says something its label can't infer.

**(blocking)** — only ever on `problem`, and only when **both** hold:

1. **I'm near-certain.** I traced it. Not "this looks wrong."
2. **It's severe.** Crashes, corrupts or erases data, breaks the user, or exposes
   something that can't be un-exposed.

Name the concrete failure. If I can't name it, it isn't blocking. Something done
the wrong way, something that doesn't quite fully fix the problem, or something
fixable in a follow-up is a plain `problem` — not a blocker.

`blocking` still means *let's sync before this merges*, not "go fix it" — the
author decides what to do either way. What's tightened is the bar for claiming it,
not the meaning.

**A false blocking costs more than a late one.** It teaches the author to discount
every future one, and that discount is the whole value of the review. When unsure,
drop the decoration.

**(minor)** — only if it's cheap; skip it otherwise.

`question` and `thought` never take `(blocking)`: a question is uncertain by
definition, a thought is optional by definition.

### Body

Up to three parts. Split only when splitting makes the comment clearer — most
comments don't need all three, and a one-part comment is often the right answer.

1. **What I'm looking at** — the label line itself. Always present.
2. **Why it matters** — a consequence the first part doesn't already imply. If it
   only rephrases the finding in other words, drop it and go straight to the action.
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

**Write it so a human wants to read it.** These comments are mostly read by bots,
but a comment only a bot will read teaches the author to stop reading and let their
bot handle it — and then nothing I said actually lands. Shorter is usually easier
to read, but the goal is readability, not brevity: never cut something the author
or a bot needs to act on it.

Most findings fit comfortably under 100 words. Longer is fine when the trace
genuinely needs it. If most comments are running long, it's usually the opening
carrying evidence that would read better a paragraph down.

Never say "LGTM" in any comment or review body.

PR-level comments must not just summarize what the PR does. The author knows what
they wrote, and the description already covers it. A PR-level comment earns its
place only if it says something the diff and description don't: a cross-cutting
concern, a risk that spans files, a decision worth revisiting, or a question that
isn't anchored to one line.

### Examples

One part — nothing to add, no decoration:

> **question:** is the 30s timeout deliberate here, or inherited from the old
> client?

Two parts — the impact is obvious, the action isn't:

> **suggest:** three callers now build the same header map.
>
> **Worth hoisting** into `internal/http/headers.go` before they drift.

Three parts — a real defect, but nothing critical breaks, so no decoration:

> **problem:** `retryCount` is never reset after a successful call.
>
> **Which means** the next failure starts at the cap, so one transient error
> degrades the retry budget for the life of the process.
>
> **What do you think about** resetting it in the success branch?

The rare `(blocking)` — data is destroyed, and I traced it:

> **problem (blocking):** the five-key whitelist rebuilds the entry from
> `build_entry`'s nine keys plus these five.
>
> **Which means** every other field the desktop app stored on that entry is
> gone after an install — silently, on data the app owns and we don't.
>
> **Can we sync** before this merges? I want to be sure I've read the ownership
> boundary right.

Not sure I've understood — ask, don't accuse:

> **question:** am I reading the cadence right? `last_bumped` is written to
> `pr-aging.json` but I can't find where it's read back — does something else
> gate on it?

A nit, kept cheap:

> **nit (minor):** `usrCnt` reads as a count of `usr`.
>
> **If you're already in there,** `userCount` matches the other fields.

Praise, with no fixed label:

> **this is the good version:** wrapping with `context.Cause` keeps the cancel
> reason alive all the way to the log line.

## Severity → decoration

The review tool assigns LOW / MEDIUM / HIGH. It does not map onto decorations,
because most comments carry no decoration at all.

Let severity inform the label, then apply the `(blocking)` test on its own terms:
near-certain **and** severe. A HIGH-severity finding I haven't actually traced is
a `question`, not a blocker. A HIGH-severity finding that's real but breaks
nothing critical is a plain `problem`. `(minor)` is for cosmetic findings not
worth a detour, usually LOW.

Expect `(blocking)` to be **rare** — a handful per hundred comments. If it's
showing up on a fifth of them, the bar has slipped.

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
