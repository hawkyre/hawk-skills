---
name: code-audit-hardcore
description: Aggressive cleanup audit scoped to the user's specified changes. Same five blind specialists as code-audit, plus a maximum-improvement posture — any code tangibly relevant to the changes (setup, wiring, sibling files, dependencies) that can be made cleaner WILL be made cleaner. Always improve over preserve. Refactors too large for an inline patch get routed through /plan-small or /plan-large.
---

# Code Audit (Hardcore)

This is the aggressive sibling of `code-audit`. Same scope as
`code-audit`: whatever changes the user pointed at (a diff, a feature,
an endpoint, a module). Same five parallel blind specialists. Same
anti-bias contract.

The difference is the posture: when there is a choice between leaving
tangibly-relevant code as it is and improving it, the skill **always
chooses to improve**. No exceptions. Conventions are not a defense.
"It's not strictly in the diff" is not a defense. If the changes touch
an endpoint and the surrounding API setup is wrong, the API setup gets
fixed. If a small fix sits next to duplicated utilities, the
duplicates get collapsed.

If the improvement is too large to land inline (whole-API rework,
module redesign, schema change), the skill routes that work through
`/plan-small` or `/plan-large` instead of patching directly. Inline
patches and plan-routed refactors can both come out of a single
hardcore run.

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

- `scope=<files|diff|HEAD~N>` — same shape as `code-audit`. Default:
  the working diff against `HEAD`. This is the **initial** (core)
  scope; the skill will expand from here per the rule below.
- `agents=full|light` — pass-through to the specialists. `full` (5)
  by default; `light` drops the online-research pass.

There is no `mode=report`. Hardcore always cleans up. For a
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

Then, the **always-improve rule** applies across the entire review
scope:

> When evaluating any line in the review scope, if there is a choice
> between leaving it as it is and improving it, choose to improve.
> Always. Conventions in the surrounding code are not a defense.

"Improvement" means the same dimensions the five specialists already
cover: cleaner naming, simpler control flow, fewer abstractions, no
dead code, consistent layering, correct types, no duplication,
proper error paths, modern API usage.

## Process

1. **Identify the core scope** from the args (or the working diff if
   unspecified).
2. **Compute the review scope** by expanding the core scope per the
   tangibly-relevant rule above. Print the expansion so the user can
   see what's about to be touched.
3. **Load shared context**: `.agents/standards/`,
   `.agents/common-mistakes/`, the project check command.
4. **Spawn the five specialists in parallel** — one message,
   multiple Agent tool calls. Each gets the standard `code-audit`
   specialist prompt **with the hardcore addendum appended** (see
   below). The anti-bias contract is unchanged: subagents do not
   read `.plans/`, do not see the user's goal, evaluate code on its
   own merits.
5. **Merge specialist outputs** the same way `code-audit` merges
   them (dedupe by `path:line`, attach overlapping reasoning).
6. **Promote NOTEs to FIXes** wherever a NOTE describes a concrete
   improvement to code in the review scope. The always-improve rule
   means "this works but could be simpler" is a FIX in hardcore
   mode, not a NOTE.
7. **Classify each FIX** as small (apply inline) or big (route to a
   plan):
   - **Big** if any of these are true:
     - Touches >5 files.
     - Changes a database schema or migration.
     - Changes a public API (exported function signature, HTTP
       route shape, CLI argument).
     - Refactors a module's external surface (rename, split, merge).
     - Requires user-facing behavior change.
     - The specialist's `Fix:` is "redesign X" / "extract Y into a
       new module" rather than a concrete patch.
   - Otherwise: **small**.

   When in doubt, classify big. Plans are cheap; bad refactors are
   not.
8. **Apply small fixes inline** (cleanup mode). Run the check
   command after each batch. If it fails, fix or revert before
   moving on (max 3 attempts).
9. **Route big fixes through plan skills**. Cluster related big
   fixes by module/theme. For each cluster, invoke `/plan-small` if
   it's a single-PR refactor, `/plan-large` if it spans modules or
   PRs. The plan skills handle their own questions, file output,
   self-review. Hardcore stops at "plan written" and surfaces the
   plan paths.
10. **Final pass**: run the check command across the affected
    files. Report (template below).

## Hardcore prompt addendum

Each specialist receives the standard `code-audit` prompt with this
appended at the top:

```
## Hardcore mode — always-improve posture

You are reviewing the user's diff PLUS the tangibly-relevant
surrounding code (setup, wiring, sibling files in the same module,
files the diff depends on). The full review scope is provided
below.

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

The rest of the standard specialist prompt (anti-bias contract,
brief, scope, standards, output format) applies unchanged.

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
- Specialists run with the standard `code-audit` anti-bias contract:
  no `.plans/` reads, no goal context, evaluate code on its own
  merits.
- The check command must pass after every batch of small fixes.
- Public API changes are always big fixes — route through a plan,
  even if the patch itself is small.
