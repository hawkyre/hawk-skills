---
name: code-audit-hardcore
description: Aggressive cleanup audit scoped to the user's specified changes. Same blind audit-* specialists as code-audit, plus a maximum-improvement posture — any code tangibly relevant to the changes (setup, wiring, sibling files, dependencies) that can be made cleaner WILL be made cleaner. Always improve over preserve. Refactors too large for an inline patch get routed through /plan-small or /plan-large.
---

# Code Audit (Hardcore)

Run `code-audit`'s entire process (read `code-audit/SKILL.md`), with
the deltas below. Don't restate the shared shape — the orchestrator
follows code-audit, then applies these overrides.

## Deltas vs `code-audit`

| Aspect | code-audit | hardcore |
|---|---|---|
| `tier=` default | `auto` | `deep` (run all five specialists) |
| Modes | `report` or `cleanup` | always cleanup — no `report` |
| Scope | the user-specified diff | core scope **expanded** to tangibly-relevant code (rule below) |
| Specialist user prompt | standard template | standard template **+ "Posture: hardcore" block** (below) |
| Merge step | dedupe and verify | additionally **promote NOTE→FIX** when the NOTE describes a concrete improvement |
| Apply step | apply every FIX | **classify each FIX small/big** (below); apply small inline; route big through `/plan-small` or `/plan-large` |
| Output | code-audit report template | hardcore template (below) |

## When to use

- "Audit this and clean it up properly."
- "I'm reviewing this endpoint — if the API setup is wrong, fix the
  whole API setup."
- "Don't just check the diff, look at everything related and make it
  spotless."
- After landing a feature where the diff was minimal but the
  surrounding code rotted around it.

For a strict diff-only review, use `code-audit`.

## Args

- `scope=<files|diff|HEAD~N>` — same shape as `code-audit`. The
  **initial** core scope; the skill expands from here per the rule
  below.
- `tier=auto|light|standard|deep` — passed through to code-audit's
  triage. Default `deep`. Pass `tier=auto` to let `audit-triage`
  right-size on the **expanded** review scope.

There is no `mode=` arg — hardcore always cleans up. For a
report-only hardcore-style review, use `code-audit mode=report` and
read it as a punch list.

## The scope expansion rule

The user's specified changes are the **core scope**. They are a
starting point, not a fence. Before the audit, identify the
**tangibly-relevant** surrounding code and add it to the review:

- Files the core scope imports from where the import is load-bearing
  (not just a utility re-export).
- Setup / wiring code the core scope depends on: router config,
  middleware stack, DI container, schema definitions, base classes,
  shared types.
- Sibling files in the same module that share types, helpers, or
  conventions with the core scope.
- Tests for any of the above.

The union of the core scope and the tangibly-relevant set is the
**review scope**. Show this expansion to the user before fixing —
they should know what code the skill is touching.

The **always-improve rule** then applies across the entire review
scope:

> When evaluating any line in the review scope, if there is a choice
> between leaving it as it is and improving it, choose to improve.
> Always. Conventions in the surrounding code are not a defense.

"Improvement" means the same dimensions the specialists already
cover: cleaner naming, simpler control flow, fewer abstractions, no
dead code, consistent layering, correct types, no duplication,
proper error paths, modern API usage.

## Specialist user prompt — Posture: hardcore

When fanning out to the `audit-*` specialists, append this block to
the standard `code-audit` user prompt:

```
## Posture: hardcore — always improve

You are reviewing the user's diff PLUS the tangibly-relevant
surrounding code (setup, wiring, sibling files in the same module,
files the diff depends on). The full review scope is in the
"Files / diff in scope" section above.

When deciding between flagging an improvement to relevant
surrounding code and letting it go because "it's not in the strict
diff" — flag it. Always. The user's intent for this audit is
maximum cleanup of everything tangibly related to their changes.

Conventions in the surrounding code are not a defense. If the
existing pattern is bad, change it. If a routing setup is wrong,
fix the routing setup, not just the new endpoint. If a duplicated
utility exists next to the changes, replace the duplicate with a
call to the canonical version — and clean the canonical version
too if it needs it.

You may flag improvements that exceed the scope of an inline patch
(rename a public API, redesign a module, change a schema). Mark
them clearly in your `Why:` — the orchestrator will route them
through a plan skill.

Promote NOTEs to FIXes whenever the note describes a concrete
improvement to code in scope. NOTE is for "interesting but no
action" only.
```

## Small-vs-big classifier

After merge, each FIX is **big** if any of these are true:

- Touches >5 files.
- Changes a database schema or migration.
- Changes a public API (exported function signature, HTTP route
  shape, CLI argument).
- Refactors a module's external surface (rename, split, merge).
- Requires user-facing behavior change.
- The specialist's `Fix:` is "redesign X" / "extract Y into a new
  module" rather than a concrete patch.

Otherwise: **small**.

When in doubt, classify big. Plans are cheap; bad refactors are not.

Apply small fixes inline (cleanup mode). Cluster related big fixes by
module/theme; for each cluster, invoke `/plan-small` (single-PR
refactor) or `/plan-large` (spans modules or PRs). The plan skills
handle questions, file output, self-review. Hardcore stops at "plan
written" and surfaces the plan paths. Public API changes are always
big — route through a plan even if the patch itself is small.

Run the project check command after each batch of small fixes:

```
<check-cmd> > /tmp/hawk-code-audit-hardcore-check-<batch>.log 2>&1
rg -n 'error|warning|fail|FAIL' /tmp/hawk-code-audit-hardcore-check-<batch>.log | head -50
```

If it fails, fix or revert before moving on (max 3 attempts).

## Output template

```markdown
# Hardcore Audit: {{core scope}}

## Scope
- Core: {{user-specified scope}}
- Expanded (tangibly relevant):
  - {{path}} — {{one-line reason}}
  - ...

## Applied (small fixes)
- [path:line] — issue (source: logic / security / simplification / research / architecture)
- ...

## Routed to plans (big fixes)
- {{cluster name}} → `.plans/{{slug}}/plan.md` (plan-small | plan-large)
  Why this needs a plan: {{summary}}
  Specialists involved: ...

## Notes (no concrete fix)
- ...

## Open questions
- ...

## Check command
- {{result}} ({{n}} retries if any)
```

## Rules

- Scope starts at the user's changes; expand to tangibly-relevant
  surrounding code; do **not** expand to the whole repo.
- Always improve over preserve. Conventions are not a defense.
- Promote NOTEs to FIXes whenever they describe a concrete
  improvement.
- Big fixes go through plan skills. Hardcore does not implement
  them inline.
- Specialists run as `audit-*` subagents with their built-in
  anti-bias contract. The hardcore posture is added per-call in the
  user prompt; do not duplicate it inside the agent's system prompt.
- The check command must pass after every batch of small fixes.
- **Big-output discipline.** Heavy command output goes to
  `/tmp/hawk-code-audit-hardcore-<step>.log`, narrow with
  `rg -n '<pattern>' /tmp/hawk-code-audit-hardcore-<step>.log | head -50`.
  See `code-audit/SKILL.md` and the README for the full recipe.
