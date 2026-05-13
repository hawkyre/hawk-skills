---
name: plan-small
description: Plan a small, single-PR change. Writes a technical plan to .plans/<slug>/plan.md, asks only the questions whose answers are not in the code, surfaces core assumptions and decisions alongside questions, then runs an independent self-review subagent (blind to the plan file) that improves the plan before showing it to the user. Use when the user wants to add a feature, endpoint, component, or config change that fits in one PR.
---

# Plan a Small Feature

Small does not mean shallow. The output of this skill is a technical plan
with concrete signatures, data shapes, and verification steps — detailed
enough that an implementer in a fresh session can execute without
re-deriving design decisions.

The skill enforces three quality gates:

1. **Question gate** — the skill asks only what the code can't answer, and
   bundles core assumptions/decisions alongside its questions so the user
   can override them before the plan is written.
2. **File output** — the plan is always written to `.plans/<slug>/plan.md`.
3. **Self-improving review** — after writing the plan, a fresh, blind
   review subagent critiques it. The skill applies its MUST-FIX/SHOULD-FIX
   findings to the file, then presents the improved plan to the user.

## Process

### Step 1 — Understand intent

Read the user's description carefully. Identify WHAT they want, not HOW
to build it. Capture in your head the explicit requirements and the
implicit ones (scale, error tolerance, observability, etc.).

### Step 2 — Load context

- Relevant standards from `.agents/standards/` (check `index.yml`).
- Relevant common-mistakes from `.agents/common-mistakes/`
  (check `index.yml`).
- The project check command (look it up — do not assume).

### Step 3 — Question gate (two-track: ask product, search code)

Generate the top 3–6 questions whose answers will shape the plan, then
sort them into two tracks:

**Track A — Product / feature-design questions.** Ask the user. These
are questions where the user has direct input the code can't answer:
scope of the MVP, real-time vs batch, in-app vs email, which user
segment, what counts as success, what failure mode is acceptable.
**Default to asking** unless the user's request already pins them down.

**Track B — Code-architecture questions.** Search the code first. Use
grep / Read / Explore. Look for:

- Existing functions, helpers, or utilities that the answer would
  dictate.
- Config files, schemas, types, or migrations that fix the answer.
- Existing patterns in neighboring features.

For repo-wide searches that may return many hits, capture and narrow: `rg -n '<symbol>' . > /tmp/hawk-plan-small-search-<step>.log 2>&1`, then a second `rg` over the file or `Read` with `offset`/`limit`.

If the code answers the question, **do not ask the user**. Record the
answer in the plan as `Decision: <decision>. Source: code @ <file:line>`
under `## Decisions and assumptions`. If the code is silent on a
Track B question, promote it to ask the user.

Then, in **one** `AskUserQuestion` call, present **both**:

- The Track A questions plus any Track B questions the code didn't
  answer.
- The **core assumptions and decisions** the skill is currently
  planning to take. Frame each assumption as a confirmable choice. The
  user can override any of them.

Example questions covering both shapes:

- *(Track A — product scope)* "Should the new export include archived
  items, or only active ones?"
- *(Track A — product behavior, framed as assumption)* "On send
  failure, should we silently retry, surface a toast, or block the
  form? — I'm planning to surface a toast, confirm or override."
- *(Track B — code-architecture, only if code is silent)* "I'm
  assuming validation should reuse `lib/validators.ts`'s `validate(...)`
  — confirm or override."
- *(Track B — code-architecture assumption)* "I'm planning to put the
  new endpoint under `/api/v1/widgets` — confirm or override."

If there are no Track A questions, no unanswered Track B questions,
and no non-trivial assumptions, skip `AskUserQuestion` and proceed.

**Interpretive note:** in-repo product docs / PRDs / design docs count
as "code can answer" by analogy. If a question's answer is in
`docs/PRD-widgets.md`, record it and don't ask. The "search first" rule
applies to product-domain text the repo carries, not only to source
code.

### Step 4 — Write the plan to file

Slug rule: derive a kebab-case slug from the user's request, ≤4 words.
If `.plans/<slug>/` already exists, append `-2`, `-3`, etc.

Plan path: `.plans/<slug>/plan.md`. Create the directory first.

The plan file must contain, in this order (Summary first — see Rules):

```markdown
# {{Title}}

## Summary
One paragraph: problem, approach, what ships. This is the elevator
pitch — what the change does and why, in plain prose. A reviewer
should be able to read just this section and know whether to dig in.

## Files to touch
For each file, with concrete signatures and shapes:

### path/to/file.ext
- What changes: <one line>
- Function(s): <signatures being added or modified>
- Data shapes: <input/output types or pseudo-schema>
- Integration points: <what calls this / what this calls>
- Error paths: <what can fail and how it's handled>

## Edge cases
- <case>: <expected behavior>
- …

## Verification
- Run: <check command>
- Tests to add/update: <names + what they assert>
- Manual: <browser steps, API calls, etc.>
- Done criteria: <one-line, observable>

## Decisions and assumptions
- Decision: <decision>. Source: code @ <file:line> | user-confirmed | default.
- Assumption: <assumption>. Source: …
- … (every non-trivial assumption from Step 3 ends up here, including the
  ones that came back from the code search)

## Standards / common-mistakes referenced
- <path> — why it applies

## Estimated scope
S | M | L

## Open questions (CONSIDER from review)
- … (filled in by the self-review pass; empty initially)
```


### Step 5 — Self-improving review (mandatory)

After the plan file is written, call the `plan-reviewer` subagent.
Its system prompt — anti-bias contract, the eight review dimensions,
severity rules, and output format — lives in
`~/.claude/agents/plan-reviewer.md`. The orchestrator's per-call
user prompt contains only the plan content and the relevant
standards/common-mistakes:

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
```

Single-PR plans don't need the multi-increment DAG check, so no
extra Posture block is needed here.

### Step 6 — Apply review findings to the plan file

When the review subagent returns:

- Apply every **MUST-FIX** directly to `.plans/<slug>/plan.md`.
- Apply every **SHOULD-FIX** directly. If a SHOULD-FIX conflicts with a
  user-confirmed decision from Step 3, downgrade it to a CONSIDER and
  flag it to the user instead of applying.
- Append every **CONSIDER** under "Open questions (CONSIDER from
  review)" in the plan file.

### Step 7 — Present to user

Print:

- The plan path.
- The `## Summary` section verbatim from the file (read it back; do
  not regenerate). The file's summary is canonical.
- The list of decisions/assumptions surfaced in Step 3 (from the
  `## Decisions and assumptions` section).
- The list of CONSIDER items appended in Step 6.

Do not start implementing. The user reviews the plan, then decides
whether to invoke `/implement-plan` or `/implement-plan-audited`.

## Triggers for review beyond the self-review subagent

Before implementation begins, surface for human review if the change
involves:

- Database schema changes.
- Touches 3+ files the user didn't write.
- Affects auth/payments/security boundaries.
- Public API changes.

The self-review subagent does not gate implementation — only the user
does.

## Rules

- Always write the plan to `.plans/<slug>/plan.md`. Even for the
  smallest changes. The file is the source of truth.
- **Two-track question gate.** For code-architecture questions, search
  the code first — never ask the user something the code answers. For
  product / feature-design questions, ask the user — they have input
  the code can't provide. In-repo product docs / PRDs count as "code
  can answer" by analogy.
- Always surface assumptions/decisions alongside questions — the user
  cannot override what they don't see.
- The plan file's `## Summary` section comes first so a reviewer can
  land on the elevator pitch before any reference-style content.
  Decisions, assumptions, risks sit lower as reference material.
- The review subagent is fresh and blind to `.plans/`. The orchestrator
  pastes the plan content inline.
- Apply MUST-FIX and SHOULD-FIX before showing the user. The user sees
  the improved plan, not the first draft.
- If the plan reveals scope >1 PR, stop and suggest `/plan-large`.
- **Big-output discipline.** Heavy command output (project check, full `git diff`, repo-wide search, long log, large fetch) goes to `/tmp/hawk-plan-small-<step>.log`, then `rg -n '<pattern>' /tmp/hawk-plan-small-<step>.log | head -50` extracts what you need. `Read` the file only with `offset`/`limit`. See README → Big-output discipline. The self-review subagent prompt includes this bullet verbatim; long standards files are narrowed via `rg` before being pasted into the prompt.
