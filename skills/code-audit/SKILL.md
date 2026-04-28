---
name: code-audit
description: Audit code with five parallel independent specialist subagents (logic bugs, security, simplification, online research, architecture). Each runs blind to the user's goal and the plan, so they evaluate code on its own merits. Use when reviewing a diff, PR, or specific code. Supports report mode (default, stops for approval) and cleanup mode (auto-fix).
---

# Code Audit

The audit is a fan-out of five independent specialists, each spawned as a
fresh subagent. They work in parallel. None of them knows what feature the
code is for, what plan generated it, or what the user is trying to ship.
The orchestrator (this skill) merges their findings.

That blindness is the point. A reviewer who knows the goal will rationalize
the code toward the goal. A reviewer who only has the diff and a narrow
specialist brief is forced to evaluate the code on its own merits.

## Modes

- **Report** (default) — Produce a merged FIX/NOTE report and **stop**. No
  edits. Wait for human approval. Use when reviewing code you didn't write,
  reviewing a PR, or auditing a concern.
- **Cleanup** — Apply every FIX directly, then run the project's check
  command. Use as a post-implementation quality pass on your own code.

## Args

- `mode=report|cleanup` — default `report`.
- `agents=full|light` — default `full` (5 specialists). `light` drops the
  online-research specialist (4 specialists). Use `light` for tight token
  budgets or when the diff has no third-party API surface.
- `scope=<files|diff|HEAD~N>` — default: the working diff against `HEAD`.
  Accepts an explicit file list, a `git diff` range, or `all` for the
  current working tree.

## Posture

Even in default mode this skill is licensed to improve the repo **agnostic
to scope, current quality, and conventions**. Conventions are not a
defense. If a function is a 200-line tangle, flag it even if every
neighboring function is also 200 lines. If an import pattern is wrong in
20 files, it is still wrong — flag the diff and add a NOTE for the
broader cleanup. The goal is to leave the touched code better than the
average of its surroundings, not to match the average.

## Process

1. **Resolve scope**. From the args, build the file list and capture the
   diff content (or the file content for files outside the diff). Group
   by layer (frontend, backend, shared). Note immediate imports/exports —
   neighbor files in scope for cross-cutting checks.

2. **Load shared context** (the orchestrator only — subagents get this
   pasted inline):
   - `.agents/standards/` (read `index.yml`, then the relevant files).
   - `.agents/common-mistakes/` (read `index.yml`, then the relevant
     files).
   - The check command for the project (`bun run c`, `pnpm typecheck`,
     `mix test`, etc.). Look it up — do not assume.

3. **Spawn the specialists in parallel**. **One message, multiple Agent
   tool calls** so they run concurrently. Each gets a self-contained
   prompt — see "Specialist prompt template" below.

   Default (full): launch all five.
   Light: launch #1, #2, #3, #5 (skip #4).

4. **Merge the outputs**:
   - Concatenate every specialist's FIX list.
   - Dedupe by `path:line` + similar issue text. When two specialists flag
     the same line, keep the more concrete fix and append the other's
     reasoning as supporting "Why".
   - Concatenate NOTEs. Drop exact duplicates only.
   - Surface every QUESTION immediately to the user — do not guess.

5. **Verify before claiming a FIX** (the orchestrator's last gate before
   acting on a specialist's output):
   - **Schema changes** — confirm against migrations / live schema.
   - **Import patterns** — grep current usage; if the codebase already
     does it the proposed way, drop the FIX.
   - **Defensive guards** — trace the call sites; if the condition is
     provably unreachable, prefer deleting dead code over adding a guard.
   - **Standards conflicts** — if a specialist's FIX contradicts an
     observed dominant pattern, flag the *standard* for review and
     downgrade the FIX to a NOTE.

   Anything not verifiable becomes a NOTE, not a FIX.

6. **Act on the merged output**:
   - **Report mode**: emit the report (template below) and stop.
   - **Cleanup mode**: apply every FIX. Run the check command. If it
     fails, fix the breakage (max 3 attempts) before reporting back.

## The five specialists

| # | Specialist | Brief |
|---|------------|-------|
| 1 | **Logic & edge cases** | Off-by-one, null/undefined/NaN, empty inputs, concurrency, race conditions, ordering assumptions, error paths, boundary values, unhandled enum branches, partial failure, retries, idempotency. Trace each function for inputs that break it. |
| 2 | **Security** | Input validation, authn/authz boundaries, SQL/command injection, XSS, secret handling, SSRF, path traversal, deserialization, log injection, CORS, rate limits, prompt injection, trust boundaries between LLM output and code paths. |
| 3 | **Simplification & readability** | Functions >30 lines, deep nesting, dead code, duplication, premature abstraction, comments that restate code, names that don't match behavior, redundant conditions, dead state. Propose concrete simpler versions, not just complaints. |
| 4 | **Online research** | For each non-stdlib import, framework call, or non-obvious API in the diff: verify the assumption against current docs via WebSearch + WebFetch. Flag deprecated APIs, version-specific gotchas, "this works but the docs warn against it" patterns, known issues in the library/version. *Cheapest pass to drop in light mode.* |
| 5 | **Architecture & conventions** | Layer separation, file placement, import direction (no upward leaks), naming, type-safety regressions, observability gaps, leaks across module boundaries, public API stability. Cross-references `.agents/standards/`. |

## Specialist prompt template

The orchestrator builds a prompt for each specialist using this template.
Substitute `{{...}}` placeholders.

```
You are an independent code reviewer. You did not write this code. You do
not know what feature it is part of. You do not know what the user is
trying to ship. Your only job is the specialist brief below.

## Specialist brief: {{specialist name}}

{{full text of the specialist's row from "The five specialists" table —
not the one-line cell, the full brief paragraph}}

## Anti-bias contract — non-negotiable

- DO NOT read any file under `.plans/`, `.agent/plans/`, or any other plan
  directory. They are off-limits.
- DO NOT search the codebase for the user's intent, design docs, or
  feature descriptions. The diff and the standards below are your entire
  context.
- DO NOT ask "what is this for?" — judge it on its own merits.
- DO evaluate the code agnostic to the surrounding repo's quality bar.
  Conventions are not a defense. If something is wrong, flag it even if
  it matches the rest of the codebase.

## Files / diff in scope

{{either inline diff content, or a file list with file content pasted
inline — the subagent should not need to fetch anything outside scope}}

## Standards (pasted inline, do not fetch)

{{full content of every relevant `.agents/standards/` file}}

## Common mistakes (pasted inline, do not fetch)

{{full content of every relevant `.agents/common-mistakes/` file}}

## Verification rule

Before recommending a FIX, verify it against the code in scope. If you
cannot verify (e.g. it depends on a file outside scope, the live schema,
or runtime behavior), downgrade to NOTE.

## Output format

Reply with exactly this structure. Use empty sections if you found nothing.

```
## FIX
1. [path:line] — short issue
   Why: what's wrong and what impact it has
   Fix: concrete change (code snippet or clear instruction)
   Verify: how to confirm the fix is correct

## NOTE
1. [path:line] — observation worth knowing, no action

## QUESTION
1. <question that, if answered, would unblock you>
```

Be concise. Concrete fixes beat philosophical complaints.
```

## Output template (orchestrator → user)

```markdown
# Code Audit Report: {{scope}}

_Specialists run: logic, security, simplification, [research], architecture_

## FIX
1. [path:line] — issue
   Why: …
   Fix: …
   Verify: …
   Source: logic / security / simplification / research / architecture
   (multiple if specialists agreed)

## NOTE
1. [path:line] — observation

## QUESTION
1. … (surface immediately, do not guess)
```

In report mode, stop here. In cleanup mode, apply each FIX and run the
check command before reporting.

## Rules

- The five specialists run in parallel as fresh subagents. Always.
- Each specialist's prompt must be self-contained — no shared chat
  history, no plan paths, no goal description.
- Conventions are observations, not defenses. Flag what's wrong even when
  the surrounding code is also wrong.
- Verification gates are the orchestrator's job, not the specialists' —
  they propose, the orchestrator confirms before turning a FIX into an
  edit.
- An unverifiable recommendation is a NOTE, never a FIX.
- Cleanup mode is not allowed to skip the check command — a green build
  is the contract.
