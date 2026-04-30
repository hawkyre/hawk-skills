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

### Step 3 — Question gate (search code, then ask)

Generate the top 3–6 questions whose answers will shape the plan. For
**each** question:

1. **Search the code first**. Use grep / Read / Explore. Look for:
   - Existing functions, helpers, or utilities that the answer would
     dictate.
   - Config files, schemas, types, or migrations that fix the answer.
   - Existing patterns in neighboring features.

   For repo-wide searches that may return many hits, capture and narrow: `rg -n '<symbol>' . > /tmp/hawk-plan-small-search-<step>.log 2>&1`, then a second `rg` over the file or `Read` with `offset`/`limit`.
2. If the answer is in the code, **do not ask the user**. Record it in
   the plan as `Answered from code: <answer> — see <file:line>`.
3. If the answer is not in the code, hold the question for the user.

Then, in **one** `AskUserQuestion` call, present **both**:

- The remaining questions.
- The **core assumptions and decisions** the skill is currently
  planning to take. Frame each assumption as a confirmable choice. The
  user can override any of them. Examples:
  - "I'm planning to add the new field as nullable for backward compat
    — confirm or override."
  - "I'm assuming validation should reuse `lib/validators.ts`'s
    `validate(...)` — confirm or override."
  - "I'm planning to put the new endpoint under `/api/v1/widgets` —
    confirm or override."

If there are no questions and no non-trivial assumptions, skip
`AskUserQuestion` and proceed.

### Step 4 — Write the plan to file

Slug rule: derive a kebab-case slug from the user's request, ≤4 words.
If `.plans/<slug>/` already exists, append `-2`, `-3`, etc.

Plan path: `.plans/<slug>/plan.md`. Create the directory first.

The plan file must contain, in this order:

```markdown
# {{Title}}

## Context
Why this change. What problem it solves. Intended outcome.

## Assumptions and decisions
- Decision: <decision>. Source: code @ <file:line> | user-confirmed | default.
- Assumption: <assumption>. Source: …
- … (every non-trivial assumption from Step 3 ends up here, including the
  ones that came back from the code search)

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

## Standards / common-mistakes referenced
- <path> — why it applies

## Estimated scope
S | M | L

## Open questions (CONSIDER from review)
- … (filled in by the self-review pass; empty initially)
```

### Step 5 — Self-improving review (mandatory)

After the plan file is written, launch **one** independent review
subagent. The subagent is fresh — no chat history, no plan file
access. The orchestrator pastes the plan content **inline** in the
prompt.

**Subagent prompt template** (substitute `{{...}}`):

```
You are an independent plan reviewer. You did not write this plan. You
do not know what feature it is part of, what the user said, or what
the broader codebase does. Your only context is the plan content
pasted below and the standards/common-mistakes pasted below.

## Anti-bias contract — non-negotiable

- DO NOT read any file under `.plans/`. The plan content is in this
  prompt. Reading the file directly would also expose sibling plans
  and skew your review.
- DO NOT search the codebase for the user's intent or feature
  description. Limit codebase reads to verifying technical claims in
  the plan (e.g. "this function exists at file.ts:42") if needed.
- DO NOT defend the plan. Argue against it.

## Review dimensions

For each, mark MUST-FIX / SHOULD-FIX / CONSIDER:

1. Technical soundness: are the signatures, data shapes, integration
   points correct?
2. Convention compliance: does the plan respect the standards pasted
   below? Where it deviates, is the deviation justified?
3. Completeness: are edge cases covered? Are there missing files
   the plan should touch but doesn't?
4. Implementability: is each file's spec concrete enough to execute
   without further design work?
5. Verification: is the verification section specific and observable?
6. Assumptions: are the listed assumptions all reasonable, and are
   any unlisted assumptions hidden in the file specs?

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
- A short summary (one paragraph).
- The list of assumptions/decisions surfaced in Step 3.
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
- Never ask a question whose answer is in the code. Search first.
- Always surface assumptions/decisions alongside questions — the user
  cannot override what they don't see.
- The review subagent is fresh and blind to `.plans/`. The orchestrator
  pastes the plan content inline.
- Apply MUST-FIX and SHOULD-FIX before showing the user. The user sees
  the improved plan, not the first draft.
- If the plan reveals scope >1 PR, stop and suggest `/plan-large`.
- **Big-output discipline.** Heavy command output (project check, full `git diff`, repo-wide search, long log, large fetch) goes to `/tmp/hawk-plan-small-<step>.log`, then `rg -n '<pattern>' /tmp/hawk-plan-small-<step>.log | head -50` extracts what you need. `Read` the file only with `offset`/`limit`. See README → Big-output discipline. The self-review subagent prompt includes this bullet verbatim; long standards files are narrowed via `rg` before being pasted into the prompt.
