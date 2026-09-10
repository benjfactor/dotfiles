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

## Non-Goals

What this work explicitly does not do, including things a reasonable reader would assume it does.
One line each, with the reason when the reason is not obvious.

- Does not {thing}. {Why, or where it lives instead.}

## Acceptance Criteria

Each one testable — a reader can say pass or fail without asking what was meant.

- [ ] Given {starting state}, when {action}, then {observable result}.
- [ ] Given {error condition}, when {action}, then {observable result}.

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
