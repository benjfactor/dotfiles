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

## What's worth surfacing at all

Before any comment style applies, filter hard. The goal of review is a safe
merge, not a correct diff — a mistake is exactly as easy to fix after merge as
before it, so being *wrong* is not by itself a reason to comment. Being *unsafe*
is.

Surface a finding only when it's near the top on **both**:

- **Confidence** — I traced it, not "this looks off."
- **Risk of impact**, read across three axes:
  - **User impact** — does someone outside the team see broken, lost, or wrong
    behavior?
  - **System impact** — does it degrade, cascade, or take down something beyond
    the immediate code path?
  - **Data integrity** — if it fires, how hard is it to undo? Cheaply-reversed
    (a bad log line, a stale cache entry) sits far below destroyed, corrupted,
    or permanently-lost data.

Pure style or naming with no consequence still isn't worth a comment. But a
real defect, a missing test around changed behavior, a misleading comment, or a
spot where a future reader will trip is worth a short `suggest` or `question`
even when it's cheap to fix later. Err toward saying it; the author can
ignore it. If nothing clears this bar, zero comments is still fine.

## How many, and how sure

This refines the bar above. Where the two disagree, this section wins.

**The filter is impact, then fix cost.** Ask what happens if it fires: an
outage, data corruption, or a feature regression? Then ask how hard it is to
fix after merge (a one-line follow-up versus a migration or backfill). Low
impact and easy to fix can still ship as a short `suggest` or `question` when
the issue is real; only cosmetic noise stays dropped.

**Confidence is reported, not a gate.** Every finding carries one of three
levels, and the level never decides whether the finding ships:

- **traced**: I followed it end to end and can name the input that triggers it.
- **likely**: the mechanism is real but one link is unverified, for example
  whether any caller passes that value in production.
- **unverified**: a suspicion with no trace. Ships only when the impact is
  severe.

State the level as a plain word at the start of the comment body, with a short
basis (what I traced, or which link I did not check). The label still says
what I want done (`problem`, `question`, and so on); the level says how sure
I am. The level word is for me, and I strip it before posting.

**Count.** No quota. The filter decides, and the usual result is 1 to 5 per
PR. If more than 8 clear the bar, show the 8 worst and fold the rest into one
`fyi` line with a count.

**Zero findings.** Say so, and add a 2 to 3 line note at PR level on what I
checked, so silence reads as "reviewed and fine" rather than "skipped". The
note stays in the Studio and is never posted to GitHub unless I approve it.

**Where to look.** When something needs human judgment (an undocumented
behavior change, a design call), add one line naming the 1 to 2 spots. Skip
it when nothing is non-obvious.

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

**Shorter and clearer wins over complete.** Prefer trimming a comment to its
essential claim over keeping every trace step that got me there. If the finding
survives without a sentence, cut the sentence.

Most findings land somewhere around 40–80 words. That's an observation, not a
target — an eight-word comment that says everything is better than a padded one,
and nothing is gained by writing up to a number.

Treat 80 as a prompt to re-read rather than a limit. Past it, ask honestly whether
this still reads well, or whether the opening is carrying evidence that would land
better a paragraph down. Sometimes the answer is that the trace really does need
the room — that's fine. The point is to have asked.

### Format

The footnote already says the comment came from my agent, so no attribution
line and no blockquote. Post the body as plain text, wherever it's posted
(chat, PR-level, or a rewritten card):

```
**label (decoration):** what I'm looking at.

**Which means** the consequence.

**What do you think about** the next step.
```

The examples below are shown as blockquotes for readability only; post them
without the `>` prefix.

Never say "LGTM" in any comment or review body.

No em-dashes. Use a semicolon to join two independent clauses; use parentheses
for an aside (interchange with commas when they read more naturally).

### Impact, not just mechanism

The second part — **why it matters** — should be the concrete consequence, not
the mechanism that produces it. "X reads stale for up to 60s" lands faster than
a paragraph on *why* X goes stale; the mechanism can follow in the same part or
get its own sentence, but the consequence comes first within that part, right
after the label line.

When a finding's impact is real today, say so plainly. When it's hypothetical —
it only bites if some other change lands first — say that plainly too, and name
the trigger. Don't let a "this could matter" finding read the same as a "this is
broken now" one; the reader needs to know which one they're looking at to decide
how much attention it deserves.

If tracing the actual impact turns up nothing — no code path exercises it, no
future change is likely to need it — that's a reason to downgrade the label
(often to `fyi`) or drop the finding, not to keep it as a `problem` on the
strength of the mechanism alone. A defect nobody can reach isn't a defect;
naming the theoretical mechanism without an impact is what makes a comment feel
like a wall of text nobody asked for.

For an enumerable set (states, cases, call sites), a short bulleted list reads
faster than the same items joined into prose. Reserve inline `file:line` citations
for the one or two most load-bearing ones; collect the rest in a trailing
`Refs:` line rather than interrupting the sentence repeatedly.

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

## Watch behavior

auto_rereview: off
review_model: opus
cover_human_approvals: 2
