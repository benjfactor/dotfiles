---
title: Claude Skill Plugin Packaging - Plan
date: 2026-08-28
type: feat
execution: code
artifact_contract: ce-unified-plan/v1
artifact_readiness: requirements-only
product_contract_source: ce-brainstorm
---

# Claude Skill Plugin Packaging - Plan

## Goal Capsule

**Objective.** Repackage the personal skills in `claude/skills/` as eight `jf-` prefixed Claude Code plugins published from one personal marketplace — parts and providers that do one thing and declare nothing, one policy plugin carrying portable judgement, and one driver assembling them into a development cycle — so someone can take the parts without inheriting the assembly, and a generic subset can be published later.

**Product authority.** This plan owns the packaging structure: how many marketplaces, which plugin owns each skill, what kind each plugin is, how they depend on each other, how org-specific configuration separates from portable skill logic, and the three stages the work is delivered in. It owns skill content only where packaging forces it: script paths, cross-skill references, and hard-coded identifiers.

**Open blockers.** None. Membership is settled at eight plugins over 18 skills, names take the `jf-` prefix and are reversible through a `renames` map, and the marketplace is `benjfactor` served from `benjfactor/dotfiles`. Remaining questions are deferred to planning rather than blocking it.

## Product Contract

### Summary

Publish the personal skills as eight plugins from a single marketplace, sorted by what each is for rather than by topic: parts and providers do one thing and declare nothing, one policy plugin carries portable judgement, and one driver assembles the rest into a development cycle. Others take the parts and get value in isolation; only the driver requires the assembly. Delivered in three stages — regroup the skills, package them, then decompose the policy — so the structure is proven before anything is published and the hardest rewrite happens last. Org identifiers move behind `userConfig` so the parts become publishable without a restructure.

### Problem Frame

The skills currently live in `claude/skills/` and reach Claude Code through a symlink at `~/.claude/skills`. That gives version control and a fast edit loop but distributes nothing: a teammate cannot install a skill, there is no version to pin, and there is no update path. Moving to a new machine made the seams visible.

The skills are densely interlinked — 13 of 23 reference at least one other by name, and `regression-triage` reaches eleven — so any split has to survive that graph rather than cut across it. They are also unevenly opinionated. `send-gchat-message` is a reusable primitive that posts to a Chat space; `notify-pr-channels` is a personal convention about which channels a passing build should reach. Packaging them together forces anyone who wants the primitive to adopt the convention.

### Key Decisions

- **One marketplace, many plugins.** (session-settled: user-approved — chosen over several marketplaces: marketplaces split on trust and ownership, there is one owner, and adding a marketplace is the only friction a consumer ever pays.) Governs R1.
- **Layered plugins using `dependencies`.** (session-settled: user-directed — chosen over a single all-in plugin and over a dependency-free split: the base-and-extension shape is the goal, and the mechanism exists.) Governs R2, R6.
- **Level is the primary split; surface is secondary.** (session-settled: user-directed — chosen over slicing by integration surface alone: surface grouping put opinionated conventions next to the primitives they wrap, and a consumer who wants a primitive should not inherit the convention above it.) Governs R3, R4, R5.
- **Token cost is not a splitting criterion.** Measured always-on cost across all 23 skills is ~1,840 tokens, roughly twice the ecosystem median for one plugin and below its 90th percentile. The split buys selective adoption and publishability, not weight.
- **Optional surfaces stay optional in prose, not in manifests.** Claude Code has no peer or optional dependency, so a hard `dependencies` entry would over-require a consumer whose CI or browser differs. Governs R7.
- **Descriptive plugin names over evocative ones.** Plugin names are the human-facing install decision; the model matches on skill names and descriptions. Governs R8, R15.
- **Names are reversible, so naming does not block.** The marketplace `renames` map migrates an old name to a current one, supports multi-hop chains, and tombstones removals with `null`; the validator rejects dangling targets and cycles. Governs R14, R17.
- **Capability grouping follows the consumer's need, not the vendor's catalog.** A `gcloud` plugin bundling BigQuery and logging would group by billing relationship rather than by anything a consumer wants together. Governs R16.
- **Level is depth, not portability.** Fusing the two pushed org-specific level-2 workflows up to the org level and produced dependencies pointing upward: the PR flow calls `notify-pr-channels`, so that skill sits below it regardless of being Vendasta-specific. Governs R18.
- **Parts, policy, and glue.** The goal is that someone takes the parts they want and writes their own glue, so only glue carries dependencies. Composability is mostly a skill-writing property rather than a packaging one: a skill that names another skill pins an implementation, while one that names an outcome lets any plugin satisfy it. Governs R22, R23.
- **The judgement is the portable asset, not the primitives.** Posting to Chat or opening a browser is trivially reimplemented; the triage decision — ignore, fold into the current work item, or track separately with or without fixing it — is the part worth reusing, and it is reused over someone else's dev flow rather than replaced by their own. It therefore names roles and ends with the fewest dependencies, inverting its current position as the most entangled plugin. Governs R22a.
- **Three stages, with the hardest rewrite last.** Regrouping proves the structure while everything is still local and reversible; packaging is mechanical once the grouping holds; decomposing the policy is the only step that changes what a skill says, so it runs last against a structure that has stopped moving. Governs R27, R28, R29.
- **`plan-commit-to-worktree` is retired, not packaged.** The harness now creates a worktree at session start, which was the skill's distinguishing job; what remains is already covered by `jf-gh-pr` and `jf-arc`.
- **CI is a provider, and the code already says so.** `merge-pr` queries GitHub's status rollup first and escalates to Cloud Build only when a check is still pending, which is a substitutable-provider relationship with a working fallback already in place. Governs R26.
- **Packaging breaks bundled-script paths, independent of grouping.** Five skills invoke scripts through `~/.claude/skills/<name>/`, which exists only because the skills are symlinked; an installed plugin lives under a versioned cache path. Governs R25.
- **Stay below 1.0, and leave dependencies unpinned while there.** A 0.x line makes a breaking change a minor bump instead of a promise the shape cannot yet keep. Pinning under 0.x would be self-defeating: semver's caret excludes minor bumps below 1.0, so `^0.1.0` rejects 0.2.0 and every part release would force a matching bump in each plugin pinning it. Governs R31, R32.
- **The marketplace ships from the existing public dotfiles repo.** That keeps the symlink edit loop and adds no new repository, at the cost of per-plugin release tags landing in it and stage 2 being a public release rather than a private one. Governs R33, R34.
- **Membership is the one decision that hardens at first publish.** Names stay reversible through `renames`; skill moves do not, which is why membership is settled before anything ships rather than after. Governs R19.

Parts, policy and driver, per R22. Parts sit alongside one another and declare nothing; only the driver points at them, and a dashed edge is a capability the part degrades without rather than a dependency it declares:

```mermaid
flowchart TD
    subgraph parts["PARTS - take what you need, declare no dependencies"]
        gchat["jf-gchat"]
        arc["jf-arc"]
        cb["jf-cloud-build"]
        commit["jf-git-commit-flow"]
        ghpr["jf-gh-pr"]
    end
    subgraph policy["POLICY - portable judgement, names roles, declares nothing"]
        triage["jf-triage-flow<br/>ignore / fold in / track / track and fix"]
    end
    subgraph driver["DRIVER - your assembly: sequence, gates, bindings"]
        cycle["jf-dev-cycle"]
    end
    theirs["someone else's driver"]
    merit["jf-feats-of-merit<br/>separate cycle"]

    cycle --> gchat
    cycle --> ghpr
    cycle --> commit
    cycle --> arc
    cycle --> triage
    merit --> ghpr
    ghpr -. degrades .-> cb
    ghpr -. degrades .-> arc
    theirs -.-> triage
    theirs -.-> gchat
    theirs -.-> ghpr
    theirs -.-> commit
```

Levels still record composition depth per R18 — capability, workflow, orchestration — and the diagram's arrows are exactly the downward edges that rule permits. Parts and glue is the sharper cut, so it is the one drawn.

The target end state is one driver over parts anyone can use in isolation. The cycle it drives:

```mermaid
flowchart LR
    T1["create tracking item<br/>optional"]
    BR["brainstorm<br/>optional"]
    G1{{"human gate"}}
    PL["plan"]
    G2{{"human gate<br/>draft PR in Arc"}}
    WK["work"]
    G3{{"human gate<br/>draft PR in Arc"}}
    RDY["open PR, announce,<br/>watch reviews, address feedback"]
    G4{{"2 approvals<br/>ping me"}}
    MRG["human says merge"]
    DEP["deploy watch"]
    TRI["jf-triage-flow<br/>ignore / fold in / track / track and fix"]

    T1 --> BR --> G1 --> PL --> G2 --> WK --> G3 --> RDY --> G4 --> MRG --> DEP --> TRI
    TRI -->|new work| T1
```

### Requirements

**Distribution shape**

- R1. All personal plugins publish from a single marketplace; a second marketplace is added only when a genuinely different trust or ownership boundary appears, such as a public subset under a separate owner.
- R2. Plugins layer through `plugin.json` `dependencies`, so a lower-level plugin installs without pulling in the levels above it.

**Level structure**

- R3. Each plugin sits at exactly one level: capability, workflow, or org orchestration.
- R4. A capability plugin wraps one external tool, carries no workflow opinion, and declares no dependency on another personal plugin.
- R5. A workflow plugin holds personal conventions and depends on the capability plugins whose tools it uses, so a consumer can adopt the capability without the convention built on it.
- R6. Dependency edges point from higher levels to lower levels only; no capability plugin depends on a workflow plugin.
- R7. Where a workflow plugin's use of a capability is optional, it does not declare a hard dependency on that capability's plugin. This covers Cloud Build status for `merge-pr` and `pr-feedback-watcher`, and Arc for `open-pr`.
- R8. Each plugin name describes what it owns, and no name collides with a name in a marketplace already added on this machine. An unprefixed `github` is excluded on that basis.

**Portability**

- R9. The `jf-git-commit-flow` plugin assumes git only and invokes no GitHub tooling, so it is usable on a non-GitHub remote. Skills that shell out to `gh` sit in `jf-gh-pr` instead, including `sync-base` and `worktree-cleanup`.
- R10. Org-specific identifiers move behind `userConfig` rather than remaining literal in skill bodies or bundled scripts. This covers the Chat space ID `AAAAIj8WMWc`, the `@vendasta/meerkats` handle, and the `TEAM_CHANNELS` map.
- R11. Each plugin records which of its skills require org-internal configuration, so a plugin can be published without shipping internal defaults.

**Development workflow**

- R12. Skills stay editable in place during development, with no reinstall step between an edit and the next session using it.
- R13. Marketplace and plugin manifests pass `claude plugin validate --strict` before release.

**Naming and grouping**

- R14. Plugin names are treated as reversible. When a name changes, the marketplace declares the old name in its `renames` map pointing at the current one; a removed plugin is tombstoned with `null` rather than dropped silently.
- R15. Every plugin carries a marketplace-entry `description` stating what a consumer gets and what they must already have installed or authenticated, plus a `displayName` whenever the machine name is not the clearest human label.
- R16. Capability plugins group by the capability a consumer wants, not by the vendor that supplies it. A single vendor's unrelated tools stay in separate plugins.
- R17. Plugin names carry no `-skills` or `-plugin` suffix.
- R17a. Plugin names carry the prefix `jf-`, so a plugin is `jf-gh-pr` rather than `jf-gh-pr`. Skills are not prefixed: invocation is already `plugin:skill`, so `jf-gh-pr:open-pr` needs nothing further. No official marketplace name collides — `jfrog` is the only one sharing the letters.

**Level semantics**

- R18. Level records composition depth only — what builds on what. Publishability is a separate per-plugin property, so an org-specific plugin sits at whatever depth its dependencies put it at rather than being pushed to the org level.
- R19. Skill-to-plugin membership is settled before the first publish. A plugin rename is migratable through `renames`, but a skill moving between plugins has no migration path and silently removes the skill from anyone who installed the old plugin.

**Packaging scope**

- R20. Packaging every skill is not a goal. A skill with no distribution need stays unpackaged as a local skill symlinked from `claude/skills/`, and that is a settled outcome rather than an unfilled gap.
- R21. A skill stays unpackaged only when no packaged skill delegates to it, since a plugin that ships a delegation to a local skill hands consumers a reference they cannot resolve.

**Composability**

- R22. Plugins divide into parts, policy, and glue. A part declares no dependency on another personal plugin and degrades when an adjacent capability is absent. A policy plugin carries portable judgement, names the roles it needs rather than the plugins that fill them, and declares no dependency either. Only glue — the wiring of specific parts into those roles — declares dependencies.
- R22a. A policy plugin's dependency count is the measure of whether it is portable. `jf-triage-flow` carries the reusable judgement, so it ends with the fewest dependencies rather than the most.
- R22b. Exactly one plugin is the driver. It owns the development cycle's sequence, its human gates, and the bindings from roles to specific parts, and it is the one plugin where hard dependencies — including cross-marketplace ones — are correct, because installing it means opting into that assembly.
- R22c. The driver closes a loop rather than ending a chain: triage of what deploy surfaces feeds new work back to the start of the cycle. A design that terminates after deploy has lost the property the cycle exists for.
- R22d. The driver's value is its gates and waits, not its steps. Steps already exist as skills; what exists nowhere is the sequencing, the human review points, and the event transitions between them.
- R23. A skill references outcomes, not other skills by name. `merge-pr` requires that CI is confirmed green rather than that `gcp-ci-watch` is invoked, so any plugin satisfying the outcome composes. Six existing cross-references are rewritten to this form.
- R24. No skill references another skill by relative file path. `notify-pr-channels` and `pr-studio-open-in-arc` currently do, and those paths cannot resolve once the skills sit in different plugins.
- R25. A bundled script is invoked through `${CLAUDE_PLUGIN_ROOT}` with a fallback for when the variable is unresolved, never through `~/.claude/skills/<name>/`. Five skills currently hardcode the symlink path, which does not exist for an installed plugin.
- R26. `jf-gh-pr` names no CI provider. The check context is a `userConfig` value defaulting to all checks, so the plugin works on any CI, and `jf-cloud-build` is a precision upgrade rather than a requirement. `merge-pr` currently hardcodes `.context == "ci/cloudbuild"` in its status query, which is the only thing making the GitHub part provider-specific.

**Delivery stages**

- R27. Stage 1 regroups the existing skills into plugin-shaped directories without publishing anything. It is complete when each skill sits under the plugin that owns it, every coupling that has become internal to a plugin is left alone, every coupling that still crosses a plugin boundary satisfies R23 and R24, and the directories load from `~/.claude/skills/` as `<name>@skills-dir` so the symlink edit loop survives.
- R28. Stage 2 turns those directories into marketplace plugins. It is complete when a `marketplace.json` lists them, each carries a `plugin.json` with a description and any `userConfig` required by R10 and R15, every bundled script resolves through `${CLAUDE_PLUGIN_ROOT}` per R25, and `claude plugin validate --strict` passes per R13.
- R29. Stage 3 decomposes `jf-triage-flow` from one opinionated skill into policy. It is complete when the judgement is expressed over the four roles it needs — inspect recent work, record a finding, fix it, tell someone — and the plugin declares zero dependencies per R22a.
- R30. `jf-triage-flow` is withheld from the stage 2 publish. Stage 3 may split or move its skills, and R19 leaves a skill move no migration path once installed, so it publishes in stage 3 once its shape is settled.

**Release and versioning**

- R31. Plugins release at `0.minor.patch` and stay below 1.0 until the shape has stopped moving, so a breaking change costs a minor bump rather than a major-version promise nothing yet justifies.
- R32. While below 1.0, a dependency string names a plugin and marketplace without a version range. Version resolution is standard semver, where `^0.1.0` means `>=0.1.0 <0.2.0`, so a caret range under 0.x breaks on every minor bump of the dependency and would force a matching bump in each plugin pinning it. Ranges are introduced at 1.0, where caret behaviour stops being a trap.
- R33. The marketplace is named `benjfactor` and is served from the existing `benjfactor/dotfiles` repository, giving ids of the form `jf-gh-pr@benjfactor`. Releases are tagged with `claude plugin tag`, which produces one `{name}--v{version}` tag per plugin release in that repository.
- R34. Because `benjfactor/dotfiles` is a public repository, stage 2 is a public release. R10 is therefore a stage 2 gate: no plugin ships a hard-coded Chat space id, team handle, or channel map, since a plugin that posts to a specific team by default is a different thing from a dotfile that mentions one.

### Key Flows

- **Adopting one capability without the workflow above it.** Trigger: a teammate wants to post to a Chat space from Claude Code but does not want personal PR conventions. Steps: they add the marketplace, install `jf-gchat`, and configure their own space ID via `userConfig`. Outcome: no glue plugin is installed, and `notify-pr-channels` never enters their context. Covers R4, R5, R10.
- **Adopting the whole cycle.** Trigger: a teammate wants the full development loop, gates included. Steps: they add the compound-engineering and Vendasta marketplaces first per R2, then install `jf-dev-cycle`, which auto-installs every part and provider it binds. Outcome: the cycle runs end to end and closes back on itself through triage. Covers R2, R22b, R22c.
- **Reusing the judgement over a different dev flow.** Trigger: someone wants the triage decision — ignore, fold in, track, or track and fix — but runs their own pipeline on a different tracker and CI. Steps: they install `jf-triage-flow` alone, which pulls in nothing, and fill its roles from their own driver. Outcome: the judgement travels without the wiring. Covers R22a, R23.
- **Taking parts without the assembly.** Trigger: someone wants the commit and PR mechanics and nothing else. Steps: they install `jf-git-commit-flow` and `jf-gh-pr`, which pull in nothing, and pair them with their own CI provider. Outcome: no personal convention is inherited, and the PR part degrades gracefully without a CI provider present. Covers R22, R26.

### Scope Boundaries

- Skill bodies are not rewritten. The only content change in scope is moving hard-coded org identifiers behind configuration per R10.
- Nothing is published publicly in this pass. R10 and R11 make publication possible later; they do not perform it.
- Whether `temporal-activities` and `pr-studio-open-in-arc` should instead go upstream into the Vendasta marketplace is not decided here. Both overlap plugins that already exist there.
- Release automation beyond R13's validate step is out of scope.

### Dependencies / Assumptions

- Claude Code 2.1.251 accepts `dependencies` in `plugin.json` as an array of strings, auto-installs them, and prunes orphans via `claude plugin prune`. Verified by schema probe against the installed binary.
- `peerDependencies` is not supported; the validator reports it as an unknown field ignored at load time. This is why R7 exists.
- `renames` in `marketplace.json` maps an old plugin name to a target that must be a name in `plugins[]`, another `renames` key, or `null`. Multi-hop chains and `null` tombstones validate clean; dangling targets fail as `target-missing` and cycles as `cycle`. Verified by schema probe. The official marketplace carries nine live rename entries, most stripping a `-skills` or `-plugin` suffix.
- Verified for renames: schema and validation behavior only. Install-time migration — whether a rename rewrites `enabledPlugins` keys in an existing `settings.json` or migrates an already-installed copy — was not verified and needs a real publish to test. The skill invocation prefix does change with the plugin name.
- `description`, `displayName`, `keywords`, `author`, and `version` are accepted in `plugin.json`; `category` is not and warns as belonging in the marketplace entry. All 291 official marketplace entries set `description`.
- A dependency's marketplace must already be added before install; Claude Code will not add one on the user's behalf.
- `jf-dev-cycle` is the only plugin carrying cross-marketplace dependencies: `compound-engineering` for the brainstorm and plan steps, `vendasta-dev-agent-toolkit` for deploy watching. Installing it therefore requires both marketplaces to be added first, which is the honest reason the driver is personal while the parts are not.
- Assumed but unverified: a bare dependency name without `@marketplace` resolves within the declaring plugin's own marketplace. The schema accepts the bare form; resolution was not confirmed.
- `claude plugin init <name>` scaffolds into `~/.claude/skills/<name>/` and auto-loads as `<name>@skills-dir`, which is the candidate mechanism for R12.
- `benjfactor/dotfiles` is a public repository, and the Chat space ID in R10 is already committed there in six files. R10 is cleanup of a current state, not a precondition for a future one.

### Outstanding Questions

**Resolve Before Planning**

None. Membership, naming, marketplace, repo home, and staging are all settled.

**Deferred to Planning**

- Which of the cross-plugin skill references can be rewritten as outcomes per R23 without losing precision, and which genuinely need to name an implementation. Answered per reference during stage 1.
- The `userConfig` schema shape for R10, which stage 2 needs and stage 1 does not.
- Whether `wsu-note`, which invokes no external system and carries no org coupling, belongs in `jf-feats-of-merit` with `wsu` or as a part of its own.
- Whether a bare dependency name resolves within the declaring plugin's own marketplace. R32 sidesteps this by naming the marketplace explicitly, so it matters only if the shorter form is preferred later.

### Sources / Research

- `claude/skills/README.md` — the existing skill-flow mermaid diagram and the develop/ship/deploy chain it documents.
- Surface matrix, cross-reference graph, and proposed level assignment for all 23 skills: see Appendix.
- `~/.claude/plugins/marketplaces/vendasta-dev-agent-toolkit/.claude-plugin/marketplace.json` — in-house precedent: one marketplace, eleven plugins from subdirectories, `defaultEnabled: false` on six, including a personally-named plugin.
- `~/.claude/plugins/marketplaces/claude-plugins-official/.claude-plugin/marketplace.json` — 290 entries; none declare `dependencies` and none use `defaultEnabled`.
- Ecosystem packaging statistics from the local plugin catalog cache: median 3 skills per plugin, mean 7.6; always-on cost median 832 tokens, p90 4,249.

## Appendix

### Proposed level assignment

Plugin names below are provisional; naming is deferred per Outstanding Questions and reversible per R14. This revision resolves the three upward dependencies produced by treating org-specificity as a level, per R18.

| Plugin | Kind | Skills | ~always-on tokens | Depends on |
|---|---|---|---|---|
| jf-gchat | part — provider (comms) | send-gchat-message | 96 | — |
| jf-arc | part — provider (browser) | open-in-arc | 87 | — |
| jf-cloud-build | part — provider (CI) | gcp-ci-watch | 63 | — |
| jf-git-commit-flow | part | green-commits, commit-preferences, plan-implementation-commits, golang-pre-commit-tests | 340 | — |
| jf-gh-pr | part | open-pr, merge-pr, pr-feedback-watcher, sync-base, worktree-cleanup | 407 | — (degrades without jf-cloud-build, jf-arc) |
| jf-triage-flow | policy | regression-triage | 147 | — (names roles, per R22a) |
| jf-dev-cycle | driver | git-worktree-jira-branch, pr-ready, notify-pr-channels | 182 | jf-git-commit-flow, jf-gh-pr, jf-gchat, jf-arc, jf-triage-flow, compound-engineering, vendasta-dev-agent-toolkit |
| jf-feats-of-merit | separate cycle | wsu, wsu-note | 118 | jf-gh-pr |

Eight plugins covering 18 skills. Parts and providers are usable in isolation and declare nothing; `jf-dev-cycle` is the assembly and carries every dependency, including the two cross-marketplace ones. Verified against the delegation graph: zero upward dependencies and zero unresolvable references.

`jf-triage-flow`'s five dependencies in that graph are today's prose, not the target. Stage 3 takes them to zero per R22a; until then the count is the measure of how far the judgement is from travelling.

**Unpackaged, per R20.** `vim-rest`, `user-preferences`, and `temporal-activities` stay symlinked local skills, and R21 holds for each because none is the target of a delegation from a packaged skill. `pr-studio-open-in-arc` is also unpackaged; it belongs upstream in `vendasta-pr-studio`, and `temporal-activities` similarly duplicates `vendasta-dev-agent-toolkit:temporal-workflows`.

**`plan-commit-to-worktree` is retired rather than packaged.** Its distinguishing job was creating a worktree and moving the plan into it, and the harness now creates a worktree at session start — `ce-worktree` states this directly. What remains is commit, open draft PR, open in Arc, all covered by `jf-gh-pr` and `jf-arc`. The CLAUDE.md rule invoking it after `ce:plan` retires with it.

**Execution risk on the driver.** A skill is a prompt-time instruction and does not durably wait, while the cycle spans days and many sessions. The driver is therefore a set of entry points plus resume logic leaning on `/loop`, background tasks, and push notifications, not one long-running skill. This constrains how the driver is built, not whether the packaging is right.

### Surface matrix

External systems each skill actually invokes, derived by grepping for command and API usage rather than from prose mentions.

| Skill | Surfaces | ~always-on tokens |
|---|---|---|
| commit-preferences | git | 79 |
| gcp-ci-watch | gh, gcloud | 63 |
| git-worktree-jira-branch | git, Jira naming only | 56 |
| golang-pre-commit-tests | git, go | 72 |
| green-commits | git, go | 124 |
| merge-pr | gh, git, gcloud | 60 |
| notify-pr-channels | gh, Chat | 67 |
| open-in-arc | Arc, pr-studio | 87 |
| open-pr | gh, git, Arc, Jira naming | 44 |
| plan-commit-to-worktree | gh, git, Arc, Jira naming, compound-engineering | 143 |
| plan-implementation-commits | git | 65 |
| pr-feedback-watcher | gh, gcloud | 84 |
| pr-ready | gh, git, Chat | 59 |
| pr-studio-open-in-arc | Arc, pr-studio | 85 |
| regression-triage | gh, Arc, Chat, Confluence, go | 147 |
| send-gchat-message | gcloud, Chat | 96 |
| sync-base | gh, git, go | 173 |
| temporal-activities | Temporal | 54 |
| user-preferences | go | 55 |
| vim-rest | vim / rest.nvim | 58 |
| worktree-cleanup | gh, git | 46 |
| wsu | gh, git, Confluence | 68 |
| wsu-note | none | 50 |

### Cross-reference graph

Directed edges are real delegations; backward mentions such as "X delegates here" are excluded. `send-gchat-message` and `open-in-arc` are pure sinks, which is what makes them clean capability plugins.

- Depends on nothing: commit-preferences, green-commits, user-preferences, golang-pre-commit-tests, git-worktree-jira-branch, worktree-cleanup, sync-base, open-in-arc, send-gchat-message, gcp-ci-watch, vim-rest, temporal-activities, wsu-note
- Composes the above: plan-implementation-commits, notify-pr-channels, pr-studio-open-in-arc, open-pr, merge-pr, pr-ready, wsu
- Composes those: plan-commit-to-worktree, pr-feedback-watcher
- Orchestrates across everything: regression-triage
