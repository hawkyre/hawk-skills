---
name: plan-large
description: Plan a large feature spanning multiple PRs or requiring architectural decisions. Writes a small set of purpose-built files to `.plans/<slug>/` — a 1-page `overview.md` for human review, a mandatory `data-model.md` that locks the schema before anything else, a terse `plan.md` of dependency-ordered increments, an ADR-style `decisions.md`, and a `verification.md` acceptance script. A blind self-review subagent enforces schema completeness, length budgets, and a noise check before presenting. Use when the work spans multiple PRs, requires a migration, or has sequenced dependencies — bail to `plan-small` otherwise.
---

# Plan a Large Feature

A large plan is a DAG of increments, each the size of a `plan-small` plan. The output is a `.plans/<slug>/` directory whose files have clearly separated jobs:

- `overview.md` — one page. What a human reviewer reads first.
- `data-model.md` — schema, migrations, rollback. Mandatory when persistence is touched.
- `plan.md` — tight increment list with explicit dependencies and acceptance checks.
- `decisions.md` — ADR-lite log of architectural decisions and assumptions.
- `verification.md` — end-to-end acceptance scenarios a human runs to confirm "done."
- `contracts.md` — optional; only when the feature exposes new or changed APIs.

Why split: a single fat plan file forces reviewers to scan past unrelated concerns to answer one question. With files specialised by purpose, a reviewer asking "is the schema right?" opens `data-model.md` and is done in 30 seconds.

## Quality gates

1. **Right-sizing** — if the work realistically fits one PR, hand off to `plan-small`. Multi-PR scope is the criterion, not feature size.
2. **Schema before architecture** — `data-model.md` is written and locked before the increment DAG is drawn. Schema decisions constrain everything downstream.
3. **Question gate** — search code first; ask only what code can't answer. Three tracks, ordered schema → product → architecture, capped at 5 questions total.
4. **Length budgets** — `overview.md` ≤ 1 page. Each increment in `plan.md` ≤ ~10 lines. Files exceeding the budget must justify it or split.
5. **Self-improving review** — blind subagent (no `.plans/` access) critiques against schema completeness, DAG validity, per-increment observability, noise budget, and review experience. Findings applied before presenting.

## Process

### Step 0 — Right-size first

Before anything else, decide whether this is really a `plan-large` problem. Check:

- Does it require a database migration?
- Will it ship as more than one PR?
- Are there sequenced dependencies between increments?
- Is there architectural surface a future engineer needs to understand without reading the diff?

If the answer to all four is "no," this is `plan-small` material — hand off and stop. Right-sizing prevents the sledgehammer-for-a-nut failure mode where a small change generates dozens of acceptance criteria nobody reads. If at least two are "yes," continue.

### Step 1 — Gather the design

Extract from the user (or the description) the minimum viable inputs:

- The problem this solves and for whom.
- The high-level approach they're leaning toward.
- Known constraints (stack, timeline, team, deploy story).
- **Data model intuition** — what entities, what relationships, what data already lives where. This is the highest-leverage input; don't skim it.
- Open questions they already know about.

For initial codebase investigation, dispatch up to 3 `Explore` subagents in parallel (existing patterns, related components, testing patterns) to keep planning context clean. Each Explore brief includes the Big-output discipline rule verbatim and writes repo-wide captures to `/tmp/hawk-plan-large-explore-<n>.log`, returning only narrowed findings.

### Step 2 — Load context

- Standards from `.agents/standards/` (read `index.yml`, then relevant files; narrow long files with `rg` before pasting).
- Common-mistakes from `.agents/common-mistakes/`.
- Project check command.

### Step 3 — Question gate (three tracks, schema first)

One `AskUserQuestion` call, capped at **5 questions total**, drawing from three tracks. Order matters: schema first, because it constrains everything below.

**Track 1 — Data model.** Ask the user. The schema determines what's possible at every layer above it. Examples:

- "Each user belongs to multiple teams, or exactly one?"
- "When a workflow is deleted, do its historical runs cascade or stay?"
- "Is `customer_id` a UUID, or do we keep the legacy bigint?"
- "I'm assuming sample row for `subscriptions` looks like { … } — confirm or correct."

**Track 2 — Product / scope.** Ask the user. Examples:

- "Per-team or per-org metrics by default?"
- "Behind a feature flag for internal users first, or straight to GA?"
- "What's MVP vs follow-up for v1?"

**Track 3 — Code architecture.** Search code first. If the code answers, record under `decisions.md` as `Source: code @ <file:line>`. Promote to the user only what code can't resolve. Examples that genuinely need asking:

- "I'm planning a new `billing/` module rather than extending `payments/` — confirm or override."
- "Migration runs online with the existing `pgmigrate` setup — confirm or override."

If there are no Track 1 questions and the architectural assumptions are trivial, skip the call and proceed. **In-repo PRDs, design docs, and product specs count as "code can answer" by analogy** — search them before asking Track 2 questions whose answer might already be written down.

### Step 4 — Adversarial pre-write pass

Stress-test the design before writing anything:

- Top 3 risks or failure modes.
- One alternative architecture worth considering, and the strongest argument for it.
- Gaps: migration, backwards compat, observability, rollback, backfill, feature flag, telemetry.
- What to prototype first to de-risk the rest.

You don't commit alternatives to the plan file. You **do** record the chosen approach's rationale and the risks it accepts — these will land in `decisions.md`.

### Step 5 — Lock the data model

Before drawing the increment DAG, write `data-model.md`. If the feature touches persistence at all, this file is mandatory. Stub a section explicitly as "N/A — <one-sentence reason>" rather than omitting it; the act of writing "N/A" forces the decision instead of leaving it forgotten.

Required sections:

1. **Entities & relationships** — either a small Mermaid ER diagram or actual DDL. Pick one and commit.
2. **Constraints & indexes** — uniqueness, foreign keys, NOT NULL, check constraints, indexes that exist. Most schema bugs from AI-generated code are missing constraints or wrong indexes — be explicit.
3. **Query patterns** — list the reads and writes the feature needs. This justifies the design and lets a reviewer say "you didn't index for X." If you can't list 3–5 specific queries, the schema isn't ready.
4. **Sample rows** — one realistic row per table. Makes ambiguity obvious.
5. **Migration plan** — ordered DDL, online vs offline, expected lock implications, estimated duration on production-scale data.
6. **Backwards-compatibility window** — dual-write? read-then-write? view shim? what's the rollback path _during_ migration?
7. **Backfill** — required? batched? idempotent? ordering constraints? estimated duration?
8. **Rollback** — what does undoing this look like at each migration step?

If Step 6 later reveals a schema gap, return here and update — `data-model.md` is canonical for schema decisions throughout.

### Step 6 — Decompose into ordered increments

Each increment must:

- Be a single PR that passes CI independently.
- Move the feature measurably forward.
- Have explicit dependencies and what it unblocks.
- Have an observable done criterion (a command, query, or visible behaviour — not "the code is correct").
- Be estimated S / M / L.

No file-by-file specs unless the increment introduces genuinely novel architecture. For 9 increments out of 10, the implementer in a fresh session needs only: dependencies, file list, and a testable done check. They open the actual code for signatures. Re-explaining code in prose makes the plan harder to review without helping the implementer.

For the rare increment that does need a deep spec (new module structure, non-obvious integration, novel error model), drop the detail in a sibling `inc-<N>-notes.md` and reference it from the increment block. Keeps `plan.md` scannable.

### Step 7 — Write the files

Slug rule: kebab-case from the user's request, ≤ 4 words. If `.plans/<slug>/` exists, append `-2`, `-3`, etc.

**`overview.md`** (≤ 1 page, ~500 words):

```markdown
# {{Title}}

## What & why

One paragraph: problem, approach, scope. A non-implementer should
finish this paragraph knowing whether to dig further.

## Increment DAG

- Inc 1 — Foundation (S) — depends on: none — unblocks: 2, 3
- Inc 2 — Schema (M) — depends on: 1 — unblocks: 4, 5
- Inc 3 — API (M) — depends on: 1 — unblocks: 5
- ...

(Optional ASCII diagram if the DAG isn't linear.)

## Top 3 risks

- <risk, one sentence, with mitigation or "accept">
- <risk, one sentence, with mitigation or "accept">
- <risk, one sentence, with mitigation or "accept">

## Files

- [data-model.md](data-model.md) — schema & migrations
- [plan.md](plan.md) — increment list
- [decisions.md](decisions.md) — architectural choices
- [verification.md](verification.md) — acceptance scenarios
- (contracts.md if APIs change)
```

**`plan.md`** — one tight block per increment, ≤ 10 lines each:

```markdown
# Implementation plan

## Inc 1 — <title> (S|M|L)

**Depends on:** … (or `none`)
**Unblocks:** …
**Files:** path/a, path/b, path/c
**Done when:** <observable: a command, a behaviour, a query result>
**Risks:** <one sentence; or "none beyond global">

## Inc 2 — …
```

**`decisions.md`** — ADR-lite plus a sourced assumption log:

```markdown
# Decisions & assumptions

## D1: <title>

- **Context:** what made this decision necessary.
- **Decision:** what we chose.
- **Consequences:** what this implies, including accepted risks.
- **Alternatives rejected:** the strongest alternative and why it lost.

## D2: ...

## Assumptions resolved from code

- <decision>. Source: code @ <file:line>.
- <decision>. Source: user-confirmed.
- <decision>. Source: default; revisit if X.
```

**`verification.md`** — concrete acceptance scenarios, written GIVEN/WHEN/THEN or EARS:

```markdown
# Acceptance scenarios

## Scenario 1: <name>

GIVEN <setup>
WHEN <action>
THEN <observable outcome>

## Scenario 2: ...

## Cross-cutting checks

- e.g. "after Inc 5, manually walk /widgets and confirm…"
- e.g. "rollback from Inc 3 returns DB to pre-migration state"
```

Use EARS (`WHEN <event> THE SYSTEM SHALL <behaviour>`) or GIVEN/WHEN/THEN — both force concreteness and disqualify weasel words.

**`contracts.md`** (optional) — only when the feature exposes new or changed APIs. Endpoint signatures, request/response shapes, error codes, auth and rate-limit constraints.

### Step 8 — Self-improving review (mandatory)

Call `plan-reviewer` with the same standard prompt as `plan-small` Step 5, but append this **plan-large posture**:

```
## Posture: multi-increment plan with separated artifacts

In addition to the eight standard review dimensions, evaluate:

9.  Schema completeness (data-model.md):
    - Does it cover entities, constraints, indexes, query patterns,
      sample rows, migration, backwards compat, backfill, and rollback?
    - Are constraints explicit (uniqueness, FKs, NOT NULL)?
    - Do the listed query patterns actually justify the schema design?
    - Could a reviewer spot a missing index from this file alone?

10. Increment DAG correctness (plan.md + overview.md):
    - Does Inc N depend on something Inc N-1 didn't produce?
    - Could increments run in parallel that the DAG serializes?
    - Does any increment do too much (split candidate)?

11. Per-increment observability:
    - Is every "Done when" actually observable (command, query,
      visible behaviour) — not "the code is correct"?

12. Noise budget (all files):
    - Flag any AI filler: "robust", "appropriate", "best practices",
      "handle edge cases gracefully", "ensure correctness",
      "production-ready". Demand a concrete replacement or deletion.
    - Flag any prose that paraphrases code already in the repo.
    - Flag any increment block over 10 lines without a sibling
      inc-<N>-notes.md.

13. Review experience (overview.md):
    - Could a reviewer who only reads overview.md understand what's
      shipping and the top risks? If not, condense.

If MUST-FIX changes the DAG, mark it explicitly so the DAG block
in overview.md can be updated to match plan.md.
```

The reviewer is blind to `.plans/` — paste file contents inline in the prompt.

### Step 9 — Apply review findings

Apply MUST-FIX directly. Apply SHOULD-FIX unless it conflicts with a Step 3 decision. Append CONSIDER items to a new section at the bottom of `decisions.md` titled `## Open questions (from review)`.

If any MUST-FIX changes the DAG, update both `plan.md` and the DAG block in `overview.md` — they must stay consistent.

### Step 10 — Present to user

Print, in this order:

- The plan directory path.
- The contents of `overview.md` verbatim, read back from the file (the file is canonical, don't regenerate).
- A one-line pointer to each other file with what it contains.
- The CONSIDER items appended in Step 9.

Do not start implementing. Suggest `/implement-plan` (or `/implement-plan-audited mode=auto` for hours-long unattended runs) when the user is ready.

## Rules

- The plan directory is mandatory. Large features without persistent plans always degrade across sessions.
- **Schema first.** `data-model.md` is locked before the increment DAG. If the feature touches persistence, this file is required; stub unused sections as "N/A — reason" rather than omitting them.
- **One file, one job.** Don't merge `decisions.md` into `plan.md` to save files; the separation is the point of the redesign.
- **Length budgets are hard.** `overview.md` ≤ 1 page; each increment ≤ 10 lines unless a sibling notes file exists. The self-review enforces these.
- **No weasel words.** "Robust", "appropriate", "best practices", "handle gracefully", "ensure correctness", "production-ready" — all noise. Replace with a concrete check or delete.
- **Three-track question gate, schema first.** Search code for architecture; ask the user for schema and product. In-repo PRDs/design docs count as "code can answer."
- The DAG block in `overview.md` and the increments in `plan.md` must stay consistent through every edit pass.
- The self-review subagent is blind to `.plans/` and is mandatory. The orchestrator pastes file contents inline.
- Apply MUST-FIX and SHOULD-FIX before presenting. The user sees the improved plan, not the draft.
- **Bail to `plan-small`** the moment Step 0 reveals the work doesn't span multiple PRs.
- **Big-output discipline.** Heavy command output (project check, full `git diff`, repo-wide search, long log, large fetch) goes to `/tmp/hawk-plan-large-<step>.log`, then `rg -n '<pattern>' /tmp/hawk-plan-large-<step>.log | head -50` extracts what's needed. `Read` the file with `offset`/`limit`. Explore subagent briefs and the self-review prompt include this rule verbatim; long standards files are narrowed via `rg` before pasting.
