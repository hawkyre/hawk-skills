---
name: plan-large
description: Plan a large feature spanning multiple PRs or requiring architectural decisions. Writes a technical, increment-by-increment plan to .plans/<slug>/plan.md (with optional sibling files), runs the same code-search-first question gate as plan-small, then runs an independent self-review subagent (blind to .plans/) that critiques and improves the plan before presenting it. Use when the user describes multi-day work, cross-system changes, or sequencing dependencies.
---

# Plan a Large Feature

A large plan is a DAG of increments, each of which is the size of a
`plan-small` plan. The output of this skill is a `.plans/<slug>/`
directory whose `plan.md` is technical enough that an implementer in a
fresh session can execute any increment without re-deriving design
decisions.

Quality gates (same shape as `plan-small`, scaled up):

1. **Question gate** — search code first, then ask only what code can't
   answer. Surface core architectural assumptions/decisions alongside
   questions.
2. **File output** — `.plans/<slug>/plan.md` is mandatory. Sibling files
   are optional and produced when their content exists.
3. **Self-improving review** — fresh, blind review subagent critiques
   the plan, with explicit attention to increment ordering and
   dependency correctness. Findings are applied before presenting.

The legacy "consider running /review-plan" suggestion is gone — the
self-review pass is mandatory and built in.

## Process

### Step 1 — Gather the design

Ask the user (or extract from the description) for:

- The problem this solves and for whom.
- High-level approach they're leaning toward.
- Known constraints (tech stack, timeline, team, deploy story).
- Open questions they already know about.

For initial codebase investigation, dispatch up to 3 `Explore`
subagents in parallel (one for existing patterns, one for related
components, one for testing patterns) to keep planning context
clean. Each Explore brief includes the canonical Big-output discipline Rules bullet verbatim, and instructs the subagent to capture repo-wide searches to `/tmp/hawk-plan-large-explore-<n>.log` and return narrowed findings, not raw captures.

### Step 2 — Load context

- Standards from `.agents/standards/` (read `index.yml`, then
  relevant files).
- Common-mistakes from `.agents/common-mistakes/`.
- Project check command.

### Step 3 — Question gate (search code, then ask)

Identical mechanism to `plan-small` Step 3:

1. Generate the questions that will shape architecture, increment
   order, and integration points.
2. **Search the code first** for each. If the answer is in the code,
   record it as `Answered from code: … — see <file:line>` and don't
   ask.
3. In **one** `AskUserQuestion` call, surface:
   - The remaining questions.
   - The **core architectural assumptions and decisions** the skill
     is planning to take. Examples relevant at this scale:
     - "I'm planning to keep the new feature behind a feature flag —
       confirm or override."
     - "I'm assuming the migration runs online (no downtime) using
       the existing `pgmigrate` setup — confirm or override."
     - "I'm planning to add a new `billing/` module rather than
       extend `payments/` — confirm or override."

### Step 4 — Adversarial pre-write pass (in your head)

Before writing the plan, stress-test the design:

- Top 5 risks or failure modes.
- At least one alternative architecture and the strongest argument
  for it.
- Gaps: migrations, backwards compat, observability, rollback,
  data backfill, feature flags, deprecations.
- What to prototype first to de-risk the rest.

You do not commit alternatives to the plan file (the plan should
contain only the chosen approach). You **do** record the chosen
approach's rationale and the risks it accepts.

### Step 5 — Decompose into ordered increments

Each increment must:

- Be a single PR that passes CI independently.
- Move the feature measurably forward.
- Have explicit dependencies (which prior increments it needs) and
  what it unblocks.
- Have done criteria observable from outside the code.
- Be estimated S / M / L.
- For non-trivial increments: include concrete file specs (signatures,
  data shapes, integration points, error paths) — see the file-spec
  shape in `plan-small/SKILL.md`.

### Step 6 — Write the plan to file

Slug rule: kebab-case from the user's request, ≤4 words. If
`.plans/<slug>/` exists, append `-2`, `-3`, etc.

```
.plans/<slug>/
├── plan.md          # mandatory
├── shape.md         # optional — shaping decisions, alternatives considered
├── standards.md     # optional — which standards apply, with pointers
├── references.md    # optional — similar code in repo to learn from
└── visuals/         # optional — mockups, diagrams, screenshots
```

`plan.md` structure:

```markdown
# {{Title}}

## Context
The problem, the constraints, the intended outcome.

## Architectural decisions
- Decision: <decision>. Rationale: …. Alternatives rejected: …
- … (the chosen approach's load-bearing decisions, briefly justified)

## Assumptions and answers from code
- Decision: <decision>. Source: code @ <file:line> | user-confirmed | default.
- … (output of Step 3's code search and user-answer round)

## Risks accepted
- <risk>: <mitigation or "accept; revisit if X">

## Increment DAG
A short list of increments and their dependency edges. Example:

- Inc 1 — Foundation (S) — depends on: none — unblocks: 2, 3
- Inc 2 — Schema (M) — depends on: 1 — unblocks: 4, 5
- Inc 3 — API (M) — depends on: 1 — unblocks: 5
- ...

## Increments

### Inc 1 — <title> (S|M|L)
**Depends on:** …
**Unblocks:** …
**Done criteria:** observable, one-line.

#### Files to touch
For each file (mandatory for non-trivial increments):

##### path/to/file.ext
- What changes: <one line>
- Function(s): <signatures>
- Data shapes: <input/output types or pseudo-schema>
- Integration points: <callers / callees>
- Error paths: <failures and handling>

#### Edge cases
- …

#### Verification
- Run: <check command>
- Tests to add/update: …
- Done: …

### Inc 2 — …
…

## Cross-cutting verification
Any end-to-end checks that span multiple increments (e.g. "after Inc 5,
manually walk through the user flow at /widgets and confirm…").

## Standards / common-mistakes referenced
- <path> — applies to: …

## Open questions (CONSIDER from review)
- … (filled by the self-review pass; empty initially)

## Out of scope
- Explicit non-goals. Future work that isn't this plan.
```

### Step 7 — Self-improving review (mandatory)

Launch **one** independent review subagent. Same anti-bias contract
as `plan-small`'s reviewer. The orchestrator pastes the plan content
**inline**; the subagent must not read `.plans/*`.

**Prompt template** (substitute `{{...}}`):

```
You are an independent reviewer of a large, multi-increment plan. You
did not write this plan. You do not know what the user said, what the
broader codebase does, or which feature this is.

## Anti-bias contract — non-negotiable

- DO NOT read any file under `.plans/`. The full plan content is
  pasted in this prompt. Reading the file would also expose sibling
  plans and skew you.
- DO NOT search the codebase for the user's intent. You may read
  specific source files to verify a technical claim in the plan
  (e.g. "this function exists at file.ts:42").
- DO NOT defend the plan. Argue against it.

## Review dimensions

For each, mark MUST-FIX / SHOULD-FIX / CONSIDER:

1. Technical soundness: signatures, data shapes, integration points.
2. Convention compliance vs the standards pasted below.
3. Increment ordering and dependency correctness:
   - Does Inc N depend on something Inc N-1 didn't produce?
   - Are any dependencies missing or wrong?
   - Does any increment do too much (split candidate)?
   - Could increments run in parallel that the DAG serializes?
4. Completeness: missing increments, missing files within increments,
   missing edge cases, missing verification.
5. Implementability: is each increment scoped tightly enough to be
   one PR? Are done criteria observable?
6. Risk coverage: are the listed risks adequate? Any unlisted ones?
7. Architectural decisions: are the chosen approaches the right
   ones? Are the rejected alternatives rejected for the right reason?
8. Backwards compat / migration / rollback / observability gaps.

## Plan content

{{paste full plan.md content here}}

## Standards (pasted inline)

{{full content of relevant .agents/standards/ files}}

## Common mistakes (pasted inline)

{{full content of relevant .agents/common-mistakes/ files}}

## Output format

## MUST-FIX
1. <issue> — <concrete change to make in the plan>

## SHOULD-FIX
1. …

## CONSIDER
1. …

If the plan is solid, return empty sections. Do not pad.
```

### Step 8 — Apply review findings

Same as `plan-small` Step 6:

- Apply every **MUST-FIX** directly to `.plans/<slug>/plan.md`.
- Apply every **SHOULD-FIX** directly unless it conflicts with a
  user-confirmed Step-3 decision (in which case demote to CONSIDER).
- Append every **CONSIDER** under "Open questions (CONSIDER from
  review)" in the plan file.

If MUST-FIX changes the increment DAG, update the "Increment DAG"
section to match — the DAG and the increments must stay consistent.

### Step 9 — Present to user

Print:

- The plan directory path.
- A short summary (one paragraph).
- The increment DAG.
- The architectural decisions and assumptions list.
- The CONSIDER items.

Do not start implementing. Suggest `/implement-plan` (or
`/implement-plan-audited mode=auto` for hours-long unattended runs)
when the user is ready.

## Rules

- The plan directory is mandatory — large features without persistent
  plans always degrade across sessions.
- Question gate first; never ask the user something the code already
  answers.
- Surface architectural assumptions alongside questions. The user
  cannot override what they don't see.
- The self-review subagent is mandatory and blind to `.plans/`. The
  orchestrator pastes the plan inline.
- Apply MUST-FIX and SHOULD-FIX before presenting. The user sees the
  improved plan, not the draft.
- The DAG and the increment list must stay consistent through any
  edit pass.
- Resist building everything at once. Increments are reviewable
  units; if an increment grows past one PR, split it.
- **Big-output discipline.** Heavy command output (project check, full `git diff`, repo-wide search, long log, large fetch) goes to `/tmp/hawk-plan-large-<step>.log`, then `rg -n '<pattern>' /tmp/hawk-plan-large-<step>.log | head -50` extracts what you need. `Read` the file only with `offset`/`limit`. See README → Big-output discipline. Explore subagent briefs and the self-review subagent prompt include this bullet verbatim, and long standards files are narrowed via `rg` before being pasted in.
