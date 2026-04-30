---
name: review-plan
description: Stress-test a plan file before committing to implementation. Catches architectural mistakes, convention violations, and missing dependencies while changes are still cheap. Invoked directly, not routed from coding-process.
---

# Review a Plan

## Process

1. **Load the plan and its context**: Read the plan file and any sibling files (shape.md, standards.md, references.md). Read the relevant `.agents/standards/` files that apply to the planned work.

2. **Review for technical soundness**:
   - Are the architectural decisions correct given the codebase?
   - Are the dependencies between increments properly ordered?
   - Are there missing increments or gaps in the sequence?
   - Will each increment actually pass CI independently?

3. **Review for convention compliance**:
   - Does the plan follow the project's standards?
   - Are files placed in the right directories?
   - Does the naming follow conventions?
   - Are there patterns in `.agents/common-mistakes/` that the plan risks repeating?

4. **Review for conversation fidelity**: If reviewing a plan produced during an active conversation, check whether all decisions, constraints, and answered questions from the discussion are captured in the plan. A correct plan that doesn't match what was agreed is worse than a slightly imperfect plan that does. Skip this step if reviewing a plan file without conversation context.

5. **Review for implementability**:
   - Is each increment scoped tightly enough to implement in one session?
   - Are the "done criteria" specific and verifiable?
   - Are there ambiguities that will force the implementer to make undocumented decisions?

6. **Summarize findings**:
   - **MUST FIX** — Issues that would cause implementation failure or architectural problems
   - **SHOULD FIX** — Issues that would cause friction or technical debt
   - **CONSIDER** — Suggestions for improvement

## Rules

- Reviewing a plan is 10x cheaper than fixing a bad implementation
- The best time to catch a missing dependency is before any code exists
- Convention compliance in the plan prevents convention violations in the code
- An adversarial reviewer should argue _against_ the plan — not just validate it
- **Big-output discipline.** Heavy command output (project check, full `git diff`, repo-wide search, long log, large fetch) goes to `/tmp/hawk-<skill>-<step>.log`, then `rg -n '<pattern>' /tmp/hawk-<skill>-<step>.log | head -50` extracts what you need. `Read` the file only with `offset`/`limit`. See README → Big-output discipline.
