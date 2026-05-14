---
name: plan-small
description: Plan a small, single-PR change. Writes a terse technical plan to `.plans/<slug>/plan.md` with a dedicated `## Data model changes` section whenever persistence is touched. Asks only what code can't answer, surfaces assumptions alongside questions, then runs a blind self-review subagent that enforces noise budget, source-checking, and observable done-criteria before presenting. Use when the change fits one PR — bail to `plan-large` at Step 0 if it doesn't.
---

# Plan a Small Feature

Small does not mean shallow. The output is a technical plan concrete enough that an implementer in a fresh session can execute without re-deriving design decisions — but terse enough that a reviewer can scan it in one screen.

Three quality gates:

1. **Right-sizing** — if the change doesn't really fit one PR, bail to `plan-large` at Step 0.
2. **Question gate** — ask only what code can't answer; surface assumptions alongside questions so the user can override them before the plan is written.
3. **Self-improving review** — blind subagent (no `.plans/` access) critiques against the standard dimensions plus a noise budget, source-checking, and done-observability. Findings applied before presenting.

Soft length budget: a typical plan-small fits in ≤ 400 words. If you blow that without good cause, you're probably in `plan-large` territory.

## Process

### Step 0 — Right-size first

Before anything else, sanity-check that this is really a single-PR change. Bail to `plan-large` if any of the following hold:

- Touches persistence schema in a non-trivial way (more than adding a nullable column).
- Touches more than ~5 files, or crosses more than one architectural boundary (e.g. both auth and billing).
- Has sequenced dependencies — must ship A before B can begin.
- Obviously won't fit one PR.

If the user explicitly invoked `plan-small`, default to trusting them — but if a criterion clearly triggers, flag it in one line and hand off. Catching misclassified scope early saves rework downstream.

### Step 1 — Understand intent

Read the user's description carefully. Identify WHAT they want, not HOW to build it. Capture the explicit requirements and the implicit ones (scale, error tolerance, observability).

### Step 2 — Load context

- Relevant standards from `.agents/standards/` (check `index.yml`; narrow long files with `rg` before reading).
- Relevant common-mistakes from `.agents/common-mistakes/` (check `index.yml`).
- The project check command (look it up — do not assume).

### Step 3 — Question gate (two tracks)

Generate the top 3–6 questions whose answers will shape the plan, then sort into two tracks.

**Track A — Product / feature-design.** Ask the user. These are questions only they can answer: MVP scope, real-time vs batch, in-app vs email, which user segment, what counts as success, what failure mode is acceptable. **Default to asking** unless the user's request already pins them down.

**Track B — Code-architecture.** Search the code first. Use grep / Read / Explore. Look for:

- Existing functions, helpers, or utilities that fix the answer.
- Config files, schemas, types, or migrations that fix the answer.
- Patterns in neighbouring features.

For repo-wide searches: `rg -n '<symbol>' . > /tmp/hawk-plan-small-search-<step>.log 2>&1`, then narrow with a second `rg` or `Read` with `offset`/`limit`.

If the code answers, **don't ask the user**. Record under `## Decisions and assumptions` as `Source: code @ <file:line>`. If the code is silent, promote the question to the user.

Then, in **one** `AskUserQuestion` call, present both:

- The Track A questions plus any Track B questions the code didn't answer.
- The **core assumptions and decisions** the skill is currently planning to take, each framed as a confirmable choice.

Example shapes (keep this texture):

- _(Track A — product scope)_ "Should the export include archived items, or only active?"
- _(Track A — behaviour as assumption)_ "On send failure, surface a toast vs silently retry vs block the form — I'm planning a toast, confirm or override."
- _(Track B — code, only if code silent)_ "I'm assuming validation reuses `lib/validators.ts`'s `validate(...)` — confirm or override."
- _(Track B — assumption)_ "I'm planning to put the new endpoint at `/api/v1/widgets` — confirm or override."

If there are no Track A questions, no unanswered Track B questions, and no non-trivial assumptions, skip `AskUserQuestion` and proceed.

**Interpretive note:** in-repo product docs / PRDs / design docs count as "code can answer" by analogy. If the answer is in `docs/PRD-widgets.md`, record it and don't ask.

### Step 4 — Write the plan to file

Slug: kebab-case from the user's request, ≤ 4 words. If `.plans/<slug>/` exists, append `-2`, `-3`, etc. Plan path: `.plans/<slug>/plan.md`.

Template, in this order (Summary first so a reviewer lands on the elevator pitch):

```markdown
# {{Title}}

## Summary

One paragraph: problem, approach, what ships. A reviewer should be able
to read just this section and know whether to dig in.

## Data model changes

(Include this section only when the PR touches persistence. Omit
entirely otherwise.)

- **Change:** <DDL or one-sentence description>
- **Migration:** <online with existing tooling / offline / N/A>
- **Constraints/indexes affected:** <list, or "none">
- **Query patterns affected:** <reads/writes whose plan changes>
- **Backwards compat:** <how old code keeps working during deploy>
- **Backfill:** <required? batched? estimated rows> or "N/A"
- **Rollback:** <one-line undo path>

## Files to touch

### path/to/file.ext

<One to three sentences describing what changes and why. For genuinely
novel files (new module, new API surface, novel error model), add key
signatures or shapes inline — only when they're load-bearing. Otherwise
trust the implementer to read the code.>

### path/to/other.ext

<…>

## Edge cases

- <case>: <expected behaviour>
- …

## Verification

- Run: <check command>
- Tests to add/update: <names + what they assert>
- Manual: <browser steps, API calls, etc.>
- Done when: WHEN <event> THEN <observable outcome>
  (or GIVEN/WHEN/THEN if setup matters)

## Decisions and assumptions

- Decision: <decision>. Source: code @ <file:line> | user-confirmed | default.
- Assumption: <assumption>. Source: …
- … (every non-trivial decision from Step 3 lands here, including
  the ones answered by the code search)

## Standards / common-mistakes referenced

- <path> — why it applies

## Estimated scope

S | M | L

## Open questions (CONSIDER from review)

- … (filled by the self-review pass; empty initially)
```

Notes on the template:

- **`## Data model changes` is conditional but mandatory when applicable.** Even a single-column change deserves the seven-bullet treatment — it forces explicit thinking about migration safety, backwards compat, and rollback. The act of writing "N/A" for backfill is itself a decision.
- **Per-file blocks are prose, not bullet lists.** The old 5-bullet template (What changes / Function(s) / Data shapes / Integration points / Error paths) is noise — the implementer reads the code for signatures. Reserve inline detail for genuinely novel files.
- **"Done when" uses EARS or GIVEN/WHEN/THEN.** The grammar disqualifies weasel words because there's nowhere to put them.

### Step 5 — Self-improving review (mandatory)

Call the `plan-reviewer` subagent. Its system prompt lives in `~/.claude/agents/plan-reviewer.md`. The orchestrator's per-call user prompt contains the plan content, the relevant standards, the relevant common-mistakes, and a small posture block:

```
Agent(subagent_type="plan-reviewer", prompt=<USER PROMPT>)
```

Where `<USER PROMPT>` is:

```
## Plan content

{{paste full plan.md content here}}

## Standards (pasted inline)

{{full content of relevant .agents/standards/ files}}

## Common mistakes (pasted inline)

{{full content of relevant .agents/common-mistakes/ files}}

## Posture: single-PR plan

In addition to the eight standard review dimensions, evaluate:

9.  Noise budget:
    - Flag AI filler: "robust", "appropriate", "best practices",
      "handle gracefully", "ensure correctness", "production-ready".
      Demand a concrete replacement or deletion.
    - Flag any paraphrase of code that already exists in the repo.
    - Flag any per-file block that re-states what the file is
      called without adding intent or rationale.
    - Flag the plan if it exceeds ~400 words without good cause —
      consider whether this should be plan-large.

10. Source-checking:
    - Every "Source: code @ <file:line>" claim must be plausible.
      If a cited file or line doesn't exist, or the line obviously
      contradicts the recorded decision, flag as MUST-FIX.

11. Done-criteria observability:
    - "Done when" must be runnable or visibly testable — a command,
      a query result, an HTTP response, a UI state. Reject prose
      like "the feature works correctly." EARS or GIVEN/WHEN/THEN
      form is required.

12. Data-model section (only if the plan includes one):
    - Are constraints and indexes explicit?
    - Is the rollback path concrete?
    - If backfill is "N/A", does that hold up under the migration described?
```

### Step 6 — Apply review findings to the plan file

- Apply every **MUST-FIX** directly to `.plans/<slug>/plan.md`.
- Apply every **SHOULD-FIX** directly. If a SHOULD-FIX conflicts with a user-confirmed decision from Step 3, downgrade it to a CONSIDER and flag it to the user instead of applying.
- Append every **CONSIDER** under "Open questions (CONSIDER from review)" in the plan file.

### Step 7 — Present to user

Print:

- The plan path.
- The `## Summary` section verbatim from the file (read it back — the file is canonical).
- The `## Data model changes` section verbatim if present (schema decisions deserve front-of-presentation visibility).
- The list of decisions/assumptions surfaced in Step 3 (from the `## Decisions and assumptions` section).
- The CONSIDER items appended in Step 6.

Do not start implementing. The user reviews the plan, then decides whether to invoke `/implement-plan` or `/implement-plan-audited`.

## Surface for human review when

The self-review subagent doesn't gate implementation — only the user does. Before implementation begins, explicitly surface for human review if the change involves:

- Database schema changes.
- Touches 3+ files the user didn't write.
- Affects auth, payments, or security boundaries.
- Public API changes.

## Rules

- Always write the plan to `.plans/<slug>/plan.md`. Even for the smallest changes. The file is the source of truth.
- **Step 0 bail-out is real.** If the work doesn't fit one PR, hand off to `plan-large` immediately. Right-sizing prevents misclassified scope.
- **Schema gets its own section.** When persistence is touched, `## Data model changes` is mandatory with all seven bullets — "N/A — reason" is allowed, omission is not.
- **Per-file blocks are prose, not bullet lists.** Re-explaining code-level detail the implementer will see in the file is noise. Reserve signatures/shapes for genuinely novel files.
- **EARS or GIVEN/WHEN/THEN for done criteria.** Anything else fails the reviewer's observability check.
- **Two-track question gate.** Search code first for architecture questions; ask the user for product questions and unanswered architecture questions. In-repo PRDs/design docs count as "code can answer."
- Always surface assumptions/decisions alongside questions — the user cannot override what they don't see.
- The plan file's `## Summary` comes first so a reviewer lands on the elevator pitch before reference material.
- The review subagent is fresh and blind to `.plans/`. The orchestrator pastes the plan content inline along with the posture block.
- Apply MUST-FIX and SHOULD-FIX before showing the user. The user sees the improved plan, not the first draft.
- **No weasel words.** "Robust", "appropriate", "best practices", "handle gracefully", "ensure correctness", "production-ready" — all noise. Replace with a concrete check or delete.
- **Big-output discipline.** Heavy command output goes to `/tmp/hawk-plan-small-<step>.log`, then `rg -n '<pattern>' /tmp/hawk-plan-small-<step>.log | head -50` extracts what's needed. `Read` the file only with `offset`/`limit`. The self-review subagent prompt includes this rule verbatim; long standards files are narrowed via `rg` before pasting.
