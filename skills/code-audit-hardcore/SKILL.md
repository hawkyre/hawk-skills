---
name: code-audit-hardcore
description: Aggressive cleanup audit scoped to the user's specified changes plus tangibly-relevant surrounding code. Same blind audit-* specialists as code-audit, with a maximum-improvement posture — any code in the expanded review scope that can be cleaner WILL be made cleaner. Small fixes applied inline; big fixes (>5 files, schema, public API, redesigns) routed through `/plan-small` or `/plan-large`. Plan-overrides — when the audit reveals the original plan was wrong — route through `/plan-large` by default. Always improve over preserve.
---

# Code Audit (Hardcore)

Run `code-audit`'s entire process (read `code-audit/SKILL.md`), with the deltas below. Don't restate the shared shape — the orchestrator follows code-audit, then applies these overrides.

## What carries through from `code-audit`

Hardcore inherits all of code-audit's quality gates — the deltas change the posture and routing, not the gates:

- **Verify clauses on every FIX, runnable.** FIXes without one are downgraded to NOTEs.
- **Agreement strength tracked** through merge (`Strength: N/S`).
- **The seven-pattern verification gate**: Verify-clause runnability, schema, library/dependency existence, API/function existence, import patterns, defensive guards, behavior-change visibility, standards conflicts, lazy-patch refusal.
- **Lazy-patch refusal** — silencing warnings, defensive guards for upstream bugs, renames-for-structural-issues, catch-and-log, fallbacks that mask invalid state. All downgraded to NOTE.
- **Stop-out cases** (mid-rebase / mid-merge / unresolved-conflict) — surface and stop, never apply through them.
- **Working-tree scope discovery** includes untracked files.
- **Layered retry ladder** for check-command failures (Stage 1 retry → Stage 2 fix → Stage 3 reconsider/revert → Stage 4 escalate).
- **Big-output discipline.**
- **Hard guardrail**: `code-audit` is a skill, not a subagent. Do not call `Agent(subagent_type="code-audit", …)`.

## Deltas vs `code-audit`

| Aspect                 | code-audit                                       | hardcore                                                                                          |
| ---------------------- | ------------------------------------------------ | ------------------------------------------------------------------------------------------------- |
| `tier=` default        | `auto`                                           | `deep` (run all five specialists)                                                                 |
| Modes                  | `report` or `cleanup`                            | always cleanup — no `report`                                                                      |
| Scope                  | the user-specified diff                          | core scope **expanded** to tangibly-relevant code (rule below)                                    |
| Specialist user prompt | standard template                                | standard template **+ Posture: hardcore block** (below)                                           |
| Merge step             | dedupe and verify                                | additionally **promote NOTE→FIX** when criteria met (below)                                       |
| Routing axis           | `Scope: local \| cross-cutting \| plan-override` | `Size: small \| big` — replaces Scope (below)                                                     |
| Apply step             | apply local FIXes only                           | classify each FIX small/big; apply small inline; route big through `/plan-small` or `/plan-large` |
| Plan-overrides         | surface as QUESTION                              | **route through `/plan-large`** (hardcore acts)                                                   |
| Output                 | code-audit report template                       | hardcore template (below)                                                                         |

Hardcore defaults to `tier=deep` because the expanded review scope and the always-improve posture both benefit from the research and architecture specialists, which `standard` omits.

## When to use

- "Audit this and clean it up properly."
- "I'm reviewing this endpoint — if the API setup is wrong, fix the whole API setup."
- "Don't just check the diff, look at everything related and make it spotless."
- "The plan was wrong; figure out what we should do instead."
- After landing a feature where the diff was minimal but the surrounding code rotted around it.

For a strict diff-only review, use `code-audit`.

## Args

- `scope=<files|diff|HEAD~N>` — same shape as `code-audit`. The **initial** core scope; the skill expands from here per the rule below.
- `tier=auto|light|standard|deep` — passed through to code-audit's triage. Default `deep`. Pass `tier=auto` to let `audit-triage` right-size on the **expanded** review scope.

There is no `mode=` arg — hardcore always cleans up. For a report-only hardcore-style review, use `code-audit mode=report` and read it as a punch list.

## The scope expansion rule

The user's specified changes are the **core scope**. They are a starting point, not a fence. Before the audit, identify the **tangibly-relevant** surrounding code and add it to the review:

- Files the core scope imports from where the import is load-bearing (not just a utility re-export).
- Setup / wiring code the core scope depends on: router config, middleware stack, DI container, schema definitions, base classes, shared types.
- Sibling files in the same module that share types, helpers, or conventions with the core scope.
- Tests for any of the above.

One hop out from the diff. Not callers (two hops). Not the whole repo. The user can rerun hardcore with explicit `scope=` to widen.

The union of the core scope and the tangibly-relevant set is the **review scope**. Present the expansion as a fact before fixing — the user should know what code the skill is touching, and they can interrupt to narrow. **Default is forward; hardcore is aggressive, not chatty.**

If the expansion is **>15 files**, group by module/area in the presentation instead of file-by-file — keeps the message scannable.

The **always-improve rule** then applies across the entire review scope:

> When evaluating any line in the review scope, if there is a choice between leaving it as it is and improving it, choose to improve. Always. Conventions in the surrounding code are not a defense.

"Improvement" means the same dimensions the specialists already cover: cleaner naming, simpler control flow, fewer abstractions, no dead code, consistent layering, correct types, no duplication, proper error paths, modern API usage.

## Specialist user prompt — Posture: hardcore

When fanning out, call the `audit-*` subagents directly — the same concrete `Agent(subagent_type="audit-logic", …)` etc. listed in `code-audit/SKILL.md`. **Do NOT call `Agent(subagent_type="code-audit", …)`** — `code-audit` is a skill, not a subagent. Append this block to the standard `code-audit` user prompt:

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

**Apply more, not faster.** A FIX that masks a symptom is a
regression even when it makes the build green. Hardcore's licence
is to improve aggressively — that licence is forfeit the moment
you take a lazy patch. When in doubt: surface the issue and let
the orchestrator route it through a plan skill, rather than
applying a band-aid.

You may flag improvements that exceed the scope of an inline
patch (rename a public API, redesign a module, change a schema).
Mark them clearly in your `Why:` — the orchestrator will route
them through a plan skill.

Promote NOTEs to FIXes whenever the note describes a concrete
improvement to code in scope. NOTE is for "interesting but no
action" only.
```

## NOTE→FIX promotion criteria

After merge, walk every NOTE. A NOTE is promoted to FIX when **all three** are true:

1. The NOTE identifies a specific `path:line` and a named issue (not "this section could be cleaner").
2. A concrete change can be expressed as a FIX with a runnable Verify clause.
3. The change passes the lazy-patch check (addresses the underlying issue, not the symptom).

Vague NOTEs ("this abstraction could be better") stay as NOTEs. Concrete NOTEs ("the `if (x) return x` chain on lines 42–47 duplicates the lookup in `getUser` — extract a helper") get promoted with a real Fix and Verify.

## Small-vs-big classifier

After merge and promotion, each FIX is **big** if any of these are true:

- Touches >5 files.
- Changes a database schema or migration.
- Changes a public API (exported function signature, HTTP route shape, CLI argument).
- Refactors a module's external surface (rename, split, merge).
- Requires user-facing behavior change.
- The specialist's `Fix:` is "redesign X" / "extract Y into a new module" rather than a concrete patch.
- **The FIX implies the original plan's approach was wrong (plan-override).** These always go through `/plan-large`, regardless of how localized the patch itself would be.

Otherwise: **small**.

**When in doubt, classify big. Plans are cheap; bad refactors are not.**

## Routing

**Small FIXes** — apply inline. After each batch, run the project check command with the layered retry ladder (inherited from code-audit's cleanup mode):

- **Stage 1 (Level 0 retry):** Re-run; clears transient failures.
- **Stage 2 (Level 0 fix):** Fix the immediate breakage caused by the FIXes.
- **Stage 3 (Level 1 reconsider):** Which specific FIX caused the breakage? Try reverting that FIX rather than fixing forward. In hardcore, aggressive batches mean more false-positive risk; reverting and re-classifying as NOTE is often the right call.
- **Stage 4 (Level 3 escalate):** Stop, surface the failing diff and which FIXes were applied.

Stage 3 matters more in hardcore than in code-audit because hardcore applies more FIXes per batch — so the probability that one is wrong is higher, and "revert the suspect FIX" is the safety valve that prevents an aggressive batch from forcing the user into manual cleanup.

**Big FIXes** — cluster related ones by module/theme. For each cluster, derive a kebab-case slug from the cluster's theme (≤4 words: e.g. `routing-cleanup`, `error-handling-refactor`, `schema-naming`), then invoke:

```
/plan-small "<cluster description>" slug=<derived-slug>
```

…or `/plan-large` when the cluster spans modules or PRs. **Plan-override clusters always go through `/plan-large` regardless of size** — they need the schema-first treatment and the architectural-decisions structure that the small-plan template doesn't have.

The plan skill's own slug-collision logic (`-2`, `-3`) handles duplicates. Hardcore stops at "plan written" and surfaces the plan path. Implementation belongs to the plan skill and its corresponding `/implement-plan` invocation.

**Behavior-changing FIXes** are surfaced in the output even when applied as small fixes. Apply more, not faster — never silent.

## Output template

```markdown
# Hardcore Audit: {{core scope}}

## Scope

- Core: {{user-specified scope}}
- Expanded (tangibly relevant):
  - {{path}} — {{one-line reason}}
  - ...
    (if >15 files, group by module/area)

## Applied (small fixes)

- [path:line] — issue
  Verify: <runnable check that confirms the fix stuck>
  Strength: <N>/<S>
  Source: logic / security / simplification / research / architecture
  Behavior change: yes (omit when no)
- ...

## Routed to plans (big fixes)

- {{cluster name}} → `.plans/{{slug}}/plan.md` (plan-small | plan-large)
  Why this needs a plan: {{summary}}
  Specialists involved: ...
  Plan-override: yes (omit when no)
- ...

## Notes (no concrete fix)

- [path:line] — observation
- ...

## Open questions

- ...

## Check command

- {{result}} ({{n}} retries if any; which ladder stage closed it)
```

## Rules

- **Scope starts at the user's changes; expand to tangibly-relevant surrounding code; do not expand to the whole repo.** One hop out — load-bearing imports, setup/wiring, sibling files, tests. Not callers, not config, not two-hop.
- **Always improve over preserve. Conventions are not a defense.** Existing patterns are observations, not defaults.
- **Apply more, not faster.** A lazy patch is doubly damaging in hardcore. Refuse it; route through a plan instead.
- **Promote NOTEs to FIXes when all three criteria are met:** specific path:line, concrete change with runnable Verify, passes the lazy-patch check. Vague NOTEs stay NOTEs.
- **Big fixes go through plan skills. Hardcore does not implement them inline.** Public API changes are always big.
- **Plan-overrides route through `/plan-large`**, not surfaced as QUESTIONs. Hardcore acts on plan-overrides; that's the philosophical line between code-audit and hardcore.
- **Behavior-changing FIXes are surfaced in output even when applied.** Never silent.
- **Routing axis is `Size: small | big`**, not code-audit's `Scope: local | cross-cutting | plan-override`. The two skills decide different things; don't carry both axes.
- **Verify clauses on every FIX are mandatory** (inherited from code-audit). FIXes without a runnable Verify are downgraded to NOTEs.
- **Specialists run as `audit-*` subagents** with their built-in anti-bias contract. The hardcore posture is added per-call in the user prompt; do not duplicate it inside the agent's system prompt.
- **The check command must pass after every batch of small fixes** — same layered ladder as code-audit cleanup mode. Stage 3 (reconsider/revert the suspect FIX) matters more in hardcore than elsewhere; use it.
- **Stop-out cases** (mid-rebase / mid-merge / unresolved-conflict) — surface and stop; do not apply through them. Inherited from code-audit.
- **Hardcore stops at "plan written"** for big fixes. It does not silently invoke `/implement-plan` after writing plans. The user reviews the plans, then decides.
- **Big-output discipline.** Heavy command output goes to `/tmp/hawk-code-audit-hardcore-<step>.log`, narrow with `rg -n '<pattern>' /tmp/hawk-code-audit-hardcore-<step>.log | head -50`. See `code-audit/SKILL.md` and the README for the full recipe.
