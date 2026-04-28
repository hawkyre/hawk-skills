---
name: code-audit-hardcore
description: Whole-repo deep clean. Runs the five code-audit specialists across every chunk of the codebase, overrides repo conventions in favor of cleanliness/safety/simplicity, auto-fixes small issues, and routes large fixes through /plan-small or /plan-large. Use when you want the repo left spotless, not just the diff.
---

# Code Audit (Hardcore)

This is the aggressive sibling of `code-audit`. It works at repo scope, not
diff scope. Its license is explicit: **leave every file it touches spotless,
ignore repo conventions when they conflict with cleanliness, safety, or
simplicity, and route any fix too large for an in-place patch through a
proper plan**.

It reuses the five specialists from `code-audit`. Same anti-bias contract:
they don't know what the repo is for, they don't read `.plans/*`, they
evaluate code on its own merits.

## When to use

- "Audit the repo," "deep clean," "leave it spotless."
- After a long feature push when the diff was reviewed but the surrounding
  code rotted.
- Periodically, as a quality gate for the whole codebase.

For a single diff or PR review, use `code-audit` instead.

## Args

- `scope=<path|all>` — default `all`. Restrict to a subdir if needed
  (e.g. `scope=lib/billing`).
- `parallelism=<n>` — number of parallel chunk waves. Default `3`. Each
  wave runs all five specialists simultaneously; total in-flight =
  `parallelism × 5`.
- `mode=cleanup` — fixed. Hardcore is always cleanup-mode-style — it
  fixes things. The wrinkle is that *some* fixes route to a plan
  instead of a direct edit. There is no report-only hardcore mode; for
  that, use `code-audit scope=all`.

## Posture (read this carefully)

The whole point of this skill is to override the default deference to
existing code. Specialists are told:

- **Ignore repo conventions** when they conflict with cleanliness,
  safety, or simplicity. If the repo's pattern is bad, change it.
- **Touched files end spotless**: no dead code, no >30-line functions
  without justification, no duplicated utils, no commented-out blocks,
  no inconsistent naming, no leftover debug logs, no inline TODO/FIXME
  without an issue link.
- **No cargo-cult fixes**. Match a pattern only when the pattern is
  good. Otherwise propose what should exist.

## Process

1. **Resolve scope and partition**:
   - List every source file under `scope`.
   - Group by domain/layer (e.g. `auth/*`, `billing/*`, `lib/*`,
     `web/*`).
   - Split each group into chunks of ~10 files each. Chunks should keep
     tightly-coupled files together (a route, its handler, its tests).

2. **Load shared context** (orchestrator only — pasted inline to
   subagents):
   - Every relevant file in `.agents/standards/` and
     `.agents/common-mistakes/`.
   - Project check command (`bun run c`, `pnpm typecheck`, `mix test`,
     etc.).

3. **Run waves**. For each chunk, in waves of `parallelism`:

   - Launch all five specialists in parallel for that chunk
     (one message, multiple Agent tool calls). Each gets the
     specialist prompt template from `code-audit/SKILL.md`, with one
     hardcore-specific addition (see "Hardcore prompt addendum" below).
   - Collect FIX/NOTE/QUESTION lists.
   - Merge by `path:line`, dedupe.
   - Classify each FIX as **small** or **big** (see classifier below).
   - **Apply small fixes immediately** in cleanup mode. Run the check
     command after each chunk's small-fix batch. If it fails, fix or
     revert before moving on (max 3 attempts).
   - **Queue big fixes** with their context for a final plan-routing
     pass.

4. **Big-fix routing**. After all waves complete, walk the queued big
   fixes:
   - Cluster related big fixes (same module / same theme).
   - For each cluster, invoke `/plan-small` if it's a single-PR
     refactor, `/plan-large` if it spans modules or multiple PRs. The
     plan skill handles questions, file output, self-review, etc.
   - The hardcore skill **does not implement** big fixes itself — it
     stops at "plan written" and reports the plan paths back to the
     user.

5. **Final pass**:
   - Run the check command across the whole repo.
   - Report: count of small fixes applied, count of big fixes routed
     to plans (with paths), every NOTE collected, every QUESTION still
     unanswered.

## Big-vs-small classifier

A fix is **big** (route to a plan) if any of these are true:

- Touches >5 files.
- Changes a database schema or migration.
- Changes a public API (exported function signature, HTTP route shape,
  CLI argument).
- Refactors a module's external surface (renames, splits, merges).
- Requires user-facing behavior change.
- The specialist's `Fix:` instruction is "redesign X" / "extract Y"
  rather than a concrete patch.

Otherwise it's **small**: apply directly.

When in doubt, classify big. Plans are cheap; bad refactors are not.

## Hardcore prompt addendum

In addition to the standard `code-audit` specialist prompt, hardcore
specialists receive this addendum at the top of their prompt:

```
## Hardcore mode — convention override license

You are explicitly licensed to ignore the surrounding repo's conventions
when they conflict with cleanliness, safety, or simplicity. If the repo
does something bad consistently, that is not a reason to keep doing it.

Quality bar for any file in scope:
- No dead code (unused imports, vars, functions, types, exports).
- No commented-out blocks.
- No >30-line functions without a clear justification.
- No duplicated utilities — flag the dupe with a FIX that points at the
  canonical version.
- No inconsistent naming within a file.
- No inline TODO/FIXME without a tracking link.
- No leftover debug logging or `console.log`-equivalents.

You may flag fixes that exceed the patchable scope of this chunk
(rename a public API, redesign a module, change a schema). Mark them
clearly in your `Why:` line — the orchestrator will route them through
a plan skill.
```

The rest of the standard `code-audit` specialist prompt (anti-bias
contract, brief, scope, standards, output format) applies unchanged.

## Anti-bias contract (unchanged)

Same as `code-audit`. Subagents do not read `.plans/*`, do not see the
user's goal, evaluate code on its own merits. Hardcore widens what
specialists are *allowed* to flag — it does not relax their independence.

## Output template

```markdown
# Hardcore Audit: {{scope}}

## Applied (small fixes)
- {{chunk}}: {{n}} fixes applied
  - [path:line] — issue (source: logic/security/…)
  ...

## Routed to plans (big fixes)
- {{cluster name}} → `.plans/{{slug}}/plan.md` (plan-small | plan-large)
  - Why this needs a plan: {{summary}}
  - Specialists involved: …

## Notes
- ...

## Open questions
- ...

## Check command
- {{result}} — green / red ({{n}} retries)
```

## Rules

- Hardcore is whole-repo, not diff. If you only want to review a diff,
  use `code-audit`.
- Specialists run with the standard anti-bias contract. They do not see
  the goal. They do not read plans.
- Big fixes go through plan skills. Hardcore does not implement them
  inline — that is the entire reason for the big-fix classifier.
- The check command must pass after every chunk's small-fix batch. No
  amassing red commits.
- Convention override is the *posture*, not a license to break public
  APIs without a plan. Public-surface changes are always big fixes.
