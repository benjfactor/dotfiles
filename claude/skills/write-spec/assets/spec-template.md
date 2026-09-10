---
ticket: KAT-0000
title: Short behavior-shaped title
status: draft
created: YYYY-MM-DD
---

# {TICKET} — {Title}

## Problem

Two or three sentences. What is broken or missing today, and who feels it. Describe the current
behavior, not the desired one — the desired behavior has its own section.

## Definition of Success

What is true once this ships, in a sentence or two. How you would know the built thing is right —
not a metric, unless a real one exists and someone will actually look at it.

This is the check that the Acceptance Criteria were worth passing. If every criterion below is met
and this still is not true, the spec was wrong.

## Non-Goals

What this work explicitly does not do, including things a reasonable reader would assume it does.
One line each, with the reason when the reason is not obvious.

- Does not {thing}. {Why, or where it lives instead.}

## Users

Who acts on this, and what each of them is trying to get done. One line each. Name the real
actor (partner admin, SMB user, internal support, a scheduled job), not "the user" — different
actors are the most common source of a missed requirement.

## Behavior

What the system does. One line per statement, present tense, observable from outside.

- When {condition}, the system {does what}.
- When {edge condition}, the system {does what}.
- {Existing behavior} is unchanged.

No library, service, table, or file names here. If a technology genuinely constrains the behavior,
say so in Notes and label it a constraint.

## Acceptance Criteria

Short bullets. Each one testable — a reader can say pass or fail without asking what was meant.

Extend or sharpen the ticket's own acceptance criteria here. Jira AC are often right but too
high-level to build against ("the subject line is visible in the preview" does not say what happens
when there is no subject). Carry the ticket's intent, add the cases it skipped, and say so in Notes
where you went beyond it.

- [ ] {Observable result}, {under what condition}.
- [ ] {What happens in the case the ticket did not cover}.
- [ ] {Existing behavior} still {does what it did}.

## Open Questions

Things that must be answered, and by whom. Delete the section if it is empty; do not pad it.

- [NEEDS CLARIFICATION: {question}] — {who can answer, or what would settle it}

## Notes

Anything that helps the planning session and is not a requirement.

- Related tickets and what they mean for scope: what blocks this, what this lands ahead of, what
  already shipped that this depends on.
- Implementation the ticket asked for, attributed: "The ticket asks for {X}. Recorded as the
  requester's stated approach, not a constraint the plan must accept."
- What exists in the code today, with file paths. Absences you verified, stated as verified.
- Mocks or attachments that could not be opened, named so nobody assumes they were read.
- Work items that are not behavior (a proposal to write, a team to review with), each with an owner.

Delete if empty.
