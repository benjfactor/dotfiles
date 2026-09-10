---
name: write-spec
description: >
  Turn a Jira ticket and rough intent into a reviewable spec file at docs/specs/{TICKET}-{slug}.md
  — problem, users, what the system does, non-goals, acceptance criteria, open questions — by
  interviewing the user one question at a time until the acceptance criteria are testable. Creates
  the worktree and branch first so the spec lands on the feature branch. Use this whenever work is
  starting from a Jira ticket and no plan exists yet: "spec this out", "write a spec for KAT-1234",
  "let's align before planning", "I want to agree on scope first", or any request to plan a ticket
  where the WHAT has not been pinned down. Prefer this over jumping straight to a planning skill
  when the ticket describes a want rather than a behavior — the spec becomes the input you hand to
  /ce-plan by file path.
---

# Write a Spec

## Why this exists

Planning skills read a richly-described ticket and classify it as low-ambiguity, then start
planning. The classification is reasonable and usually wrong in the same way: a Jira ticket says
what someone **wants**. It rarely says what the system **does** — at the empty case, the error
case, the already-exists case, or the boundary where this feature meets the one next to it.

Those gaps are cheapest to close now. Closing them during plan review costs a plan rewrite.
Closing them during `ce-work` costs a branch. Closing them in PR review costs the team's time.

So the deliverable here is not really the file. It is the conversation that produces it — the file
is what makes that conversation durable and reviewable. A spec that was written without asking the
user anything has skipped the part that mattered.

**Weight:** heavier than a user story plus acceptance criteria; much lighter than an RFC. An RFC
argues for a direction to an audience. A spec states agreed behavior to a planning session. If the
spec is arguing, it wants to be an RFC.

## Step 1: Set up the branch first

The spec belongs on the feature branch with the work, not on master. Follow the conventions in the
`git-worktree-jira-branch` skill — read it rather than reconstructing the rules, because the
uppercase-ticket branch name is load-bearing for the `prepare-commit-msg` hook.

Short version: worktree path all lowercase (`{repo}-{ticket-lower}-{description}`), branch
uppercase ticket with a slash (`{TICKET}/{description}`), branched from `origin/master`, then
`git branch --unset-upstream`.

Skip this step when already on a feature branch — check with `git rev-parse --abbrev-ref HEAD`
against the default branch. Write the spec into the current checkout instead.

The payoff comes later: because the spec put you on a feature branch, when `ce-plan` finishes the
`plan-commit-to-worktree` skill short-circuits and commits the plan in place next to the spec.

## Step 2: Read before you ask

Every question you ask that the repo or the ticket could have answered spends the user's patience
on something they are paying you to find out. Before the interview:

- Read the Jira ticket with the Atlassian tools if available; otherwise ask for the text.
- **Read the comments, not just the description.** A ticket's description is written once and goes
  stale. Comments carry refinement notes, PBR outcomes, and decisions made weeks later. When a
  comment postdates the description and contradicts it, the comment is the current state — say so
  in the spec rather than silently picking one.
- **Follow referenced tickets.** Real tickets cite siblings: one that blocks this, one this should
  land ahead of, one already done whose fix this depends on. Look up each referenced key and use it
  for scope boundaries. "Lands independently of KAT-1624" is a Non-Goal you get for free.
- Search the repo for the feature area, the nouns in the ticket, and anything that looks like a
  prior attempt. If the user named several repos, look across all of them. When the ticket names a
  file or a resolution path, read that file — it is usually the most load-bearing context available.
- Note what exists already, and note specifically what **does not** exist — an absence you assert
  without checking is the most expensive kind of wrong, because the plan will build on it.

Come to the interview with a draft in your head and holes you cannot fill. Ask about the holes.

### What the ticket already settled

Harvest these instead of asking about them. Re-asking something the ticket states in plain text is
the fastest way to make the interview feel like a tax:

- An explicit scope statement ("Going forward only — no backfill required") is a **Non-Goal**, done.
- A stated constraint or a decision recorded in a comment is **Behavior**, not an open question.
- A named person who still has to weigh in ("get Brendan's input on the designs") is an **Open
  Question with an owner**. Record the name — an open question nobody owns does not get closed.

### Mocks, screenshots, and links you cannot open

Tickets routinely point at a mock URL or paste a screenshot. If you cannot actually see it, you do
not know what it shows, and a spec that describes an imagined mock is worse than one that admits
the gap — the plan would inherit invented UI behavior as a requirement.

Say what you could not open, and either ask the user to describe the parts that decide behavior or
record it as `[NEEDS CLARIFICATION]`. Never describe a screen you have not seen.

## Step 3: Interview, one question at a time

Use `AskUserQuestion` (load its schema with `ToolSearch` first if needed). One question per turn.
Stacking questions gets you diluted answers to all of them — the user answers the last one properly
and waves at the rest.

**Budget 3-7 questions.** This is a real constraint, not a suggestion. An interview that turns into
a fifteen-question gauntlet gets skipped next time, and a skill that gets skipped is worth nothing.
If you have more than seven, you have not done Step 2 properly, or you are asking about the HOW.

Choose questions by which gaps actually exist in this ticket. Common ones worth probing:

- **Who is the actor, and is it only one?** Partner, SMB, internal admin, and a background job all
  want different behavior from the same feature.
- **The boundary cases the ticket skipped** — empty state, permission denied, the record already
  exists, two people doing it at once, the upstream service being down.
- **What is explicitly out of scope.** This is the highest-value answer in the whole interview.
  Non-goals are what stop an implementation session from helpfully building three adjacent things.
- **How anyone would know it worked** — the observable behavior, not the implementation.
- **What existing behavior changes.** The regression surface is rarely in the ticket.
- **Existing data** — does anything need backfill or migration to make the new rule true?

Skip any of these the ticket already answers. Add others the ticket makes obvious.

**When a question is genuinely open, ask it open-ended.** If you would be padding to reach three
plausible options, options are the wrong shape and will steer the answer.

### When to stop

Stop when two things are true: the **Definition of Success** is a sentence you could hold the built thing against,
and every **acceptance criterion is testable** — someone could read it and say whether the built
thing passes, without asking you what you meant.

Not "handles errors gracefully." That is a feeling. "The row keeps its previous status when the
upstream call fails, and the error is logged with the account ID" is a test. Short bullets, no
required Given/When/Then ceremony — the test is whether it can be judged, not what shape it takes.

### When the user hands the decision back to you

"I don't know, pick something sane and flag it" is a delegation, not an open question. Take it:
choose a specific value, put it in Behavior and Acceptance Criteria as a real testable statement,
and record it under Notes as `Chosen by me, not by the requester: {value}. {One line of why.}`

Leaving it in Open Questions instead looks careful and is actually a failure — the planner now has
no value to build against, so it invents one silently, and the flag you were being careful with buys
nothing. Prefer a specific number the user can reject over a gap they have to fill twice. The one
thing not to do is split the difference: "length capped" satisfies nobody, because it cannot be
tested and it did not settle anything.

Reserve `[NEEDS CLARIFICATION]` for what the user genuinely cannot settle yet, or what is not yours
to settle — a precedence rule between two subsystems, a policy legal has to weigh in on.

If a criterion resists that treatment after one clarifying question, do not keep grinding — write
it as `[NEEDS CLARIFICATION: ...]` in the spec and move on. A visible gap in a file the user reviews
is worth more than a confident guess, and it is the whole reason the marker exists.

## Step 4: Write the spec

Write to `docs/specs/{TICKET}-{slug}.md`, creating `docs/specs/` if needed. Not `docs/plans/` —
that directory is scanned by planning skills, and a spec sitting there gets picked up as something
it is not.

Use `assets/spec-template.md` as the structure: Problem, Definition of Success, Non-Goals, Users, Behavior,
Acceptance Criteria, Open Questions, Notes.

**Definition of Success is the section people skip, and it is the one that catches a wasted feature.** Acceptance
Criteria ask whether each piece behaves correctly; the Definition of Success asks whether building it accomplished
anything. Every criterion can pass while the Definition of Success fails — a subject column that renders perfectly
and always reads "Re: (no subject)" satisfies its criteria and helps nobody. Write it as the
observable end state, not a metric; invent a percentage only where a real one exists and someone
will look at it.

**The ticket's acceptance criteria are a starting point, not a ceiling.** Jira AC are usually
correct and too high-level to build against. Carry their intent, sharpen them into bullets that can
be judged, and add the cases the ticket skipped — the empty value, the permission failure, the
thing that must keep working. Where you went beyond the ticket, say so in Notes so the requester
can see what you added on their behalf.

Two rules about content:

**When the ticket's own acceptance criteria contain implementation, split them.** Real tickets do
this constantly — "implement the necessary API endpoints", "update the wizard UI to hook into the
new backend storage". That is a solution someone already has in mind, and it may well be right, but
it is not behavior and it was never reviewed as a decision. Put the observable behavior in Behavior
and Acceptance Criteria; put the implementation directive in Notes, attributed: "The ticket asks for
X. Recorded as the requester's stated approach, not as a constraint the plan must accept." That
sentence is what lets the planning session weigh it instead of inheriting it.

**An acceptance criterion that is a task, not a behavior, is not an acceptance criterion.** "Draft
a one-page proposal and review it with the Conversations team" is real work and it belongs in the
spec — under Notes or Open Questions, as a step with an owner. Do not dress it up as a criterion;
a criterion that cannot be tested by looking at the built system is a plan item wearing the wrong hat.

**No technology names in Problem, Users, Behavior, or Acceptance Criteria.** Not a library, not a
table name, not a service. The moment a spec says "store it in Redis," the HOW is settled and
nobody reviewed that decision — it just arrives in the plan wearing a requirement's clothes. Push
those into Notes as a preference if the user actually holds one, clearly labeled as a preference
rather than a constraint.

**Keep it short.** Behavior statements are one line each. If a section is three paragraphs, it is
carrying explanation that belongs in the ticket or argument that belongs in an RFC. A spec long
enough to skim badly gets skimmed badly.

### Write it to be read

The goal is legibility, not a particular voice. A reader should be able to scan the file in about
thirty seconds and come away knowing what gets built, what does not, and what is still undecided.
Everything that does not serve that is cut.

What that means in practice:

- One idea per line. Short declarative statements beat a paragraph carrying the same content.
- Bullets over prose in every section except Problem, which gets two or three sentences.
- No connective tissue between bullets. A list does not need "Additionally," or "Furthermore,".
- No preamble that announces the document or the section: "This specification outlines...", "The
  purpose of this section is to...". Start at the content.
- Do not restate the heading in the first line under it.
- No closing sentence that summarizes the bullets above it.
- Concrete nouns over abstractions: "the retry limit", not "the relevant configuration value".
- Cut hedges and filler: "may potentially", "simply", "essentially", "it is important to note
  that", "in order to".

Information density is the target. A short vague line is not better than a longer specific one —
"handles the empty case" is fluff, "an account with no contacts renders the empty state, not an
error" is dense. Cut words, not facts.

Before you finish, scan the file the way the user will. If you cannot answer "what does this build
and what does it leave out" from a quick pass, the structure is wrong, not the wording.

Do not commit the spec. The user reviews it first — that review is the point.

## Step 5: Hand off

Report three things:

1. The spec path, relative to the repo.
2. Any `[NEEDS CLARIFICATION]` markers left, quoted — these are what the user is looking for when
   they open the file.
3. The next command, with the path filled in:
   `/ce-plan confirm:ask docs/specs/{TICKET}-{slug}.md`

`confirm:ask` forces the planning scoping gate on regardless of how it classifies the depth. A good
spec makes work look bounded, which is exactly what makes a planner skip its own confirmation step.

## Non-Vendasta and no-ticket use

Works without Jira. Skip the ticket lookup, name the file `docs/specs/{slug}.md`, and use a branch
name the local repo would expect. Everything else is unchanged — the interview does not depend on
where the request came from.
