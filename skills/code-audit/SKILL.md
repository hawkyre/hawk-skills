---
name: code-audit
description: Audit code with parallel independent specialist subagents (logic bugs, security, simplification, online research, architecture). Each runs blind to the user's goal and the plan, so they evaluate code on its own merits. Use when reviewing a diff, PR, or specific code. Supports report mode (default, stops for approval) and cleanup mode (auto-fix).
---

# Code Audit

The audit is a fan-out of independent specialists, each running as a
fresh `audit-*` subagent. They work in parallel. None of them knows
what feature the code is for, what plan generated it, or what the user
is trying to ship. The orchestrator (this skill) merges their findings.

That blindness is the point. A reviewer who knows the goal will
rationalize the code toward the goal. A reviewer who only has the diff
and a narrow specialist brief is forced to evaluate the code on its
own merits.

The specialist briefs, anti-bias contracts, and output formats live in
the agent files (`audit-triage`, `audit-logic`, `audit-security`,
`audit-simplification`, `audit-research`, `audit-architecture`). This
skill orchestrates — it does not redefine those briefs.

## Modes

- **Report** (default) — Produce a merged FIX/NOTE report and **stop**.
  No edits. Wait for human approval. Use when reviewing code you
  didn't write, reviewing a PR, or auditing a concern.
- **Cleanup** — Apply every FIX directly, then run the project's check
  command. Use as a post-implementation quality pass on your own code.

## Args

- `mode=report|cleanup` — default `report`.
- `tier=auto|light|standard|deep` — default `auto`. The `audit-triage`
  agent reads the diff and picks the tier; explicit values skip
  triage and use the static mapping below. Replaces the old
  `agents=full|light` knob (`agents=light` ≈ `tier=standard`,
  `agents=full` ≈ `tier=deep`).
- `scope=<files|diff|HEAD~N>` — default: the working diff against
  `HEAD`. Accepts an explicit file list, a `git diff` range, or `all`
  for the current working tree.

### Tier → specialists

| Tier | Specialists |
|------|-------------|
| `light` | logic, simplification |
| `standard` | logic, security, simplification, architecture |
| `deep` | logic, security, simplification, research, architecture |

Triage may pick any subset across these tiers. When `tier` is forced,
the static mapping above is used.

## Posture

Even in default mode this skill is licensed to improve the repo
**agnostic to scope, current quality, and conventions**. Conventions
are not a defense. If a function is a 200-line tangle, flag it even
if every neighboring function is also 200 lines. If an import pattern
is wrong in 20 files, it is still wrong — flag the diff and add a
NOTE for the broader cleanup. The goal is to leave the touched code
better than the average of its surroundings, not to match the average.

## Process

1. **Resolve scope**. From the args, build the file list and capture
   the diff. Group by layer (frontend, backend, shared). Note
   immediate imports/exports — neighbor files in scope for
   cross-cutting checks.

   Diff capture: `git diff <range> > /tmp/hawk-code-audit-diff.patch 2>&1`. Get the file list with `git diff --name-only <range>` (small, inline). Specialist user-prompts receive per-file `rg -n` slices of the capture, never the raw concatenated diff.

2. **Triage** (when `tier=auto`). Spawn the `audit-triage` subagent.
   Its system prompt and decision rules already live in the agent
   file — pass only the per-call context:

   ```
   Agent(subagent_type="audit-triage", prompt=<USER PROMPT>)
   ```

   Where `<USER PROMPT>` contains:
   - **Changed files** — output of `git diff --name-only --stat <range>`.
   - **Risk-signal greps** — narrowed `rg -n` matches over the diff
     capture for each PATH and DIFF signal listed in the agent's
     body (capped at ~30 lines total). Omit signals with no matches.
   - **Scope stats** — `files: N`, `lines added/removed: +A/-B`,
     `layers spanned: <e.g. db, api, ui>`.

   Parse the structured reply:

   ```
   tier: <light|standard|deep>
   specialists: <subset>
   reason: <…>
   ```

   The triage decision is **not surfaced to the user** — log it
   internally and proceed. (If the user explicitly asks "why these
   specialists?", show the `reason`.)

   **If the reply doesn't parse** (missing `tier:` line, unknown tier
   value, empty specialists list, or no response): fall back to
   `tier=standard` (logic, security, simplification, architecture)
   and continue. Bias is up — never silently skip the audit because
   triage misbehaved.

   When `tier` is forced, skip this step and use the static mapping.

3. **Load shared context** (orchestrator only — pasted into each
   specialist's user prompt):
   - `.agents/standards/` (read `index.yml`, then the relevant files).
   - `.agents/common-mistakes/` (read `index.yml`, then the relevant
     files).
   - The check command for the project (`bun run c`, `pnpm typecheck`,
     `mix test`, etc.). Look it up — do not assume.

4. **Spawn the specialists in parallel.** **One message, multiple
   Agent tool calls.** For each role in the triage subset, call its
   subagent — the names are concrete so install-time prefix rewriting
   stays consistent across all callers:

   ```
   Agent(subagent_type="audit-logic",         prompt=<USER PROMPT>)
   Agent(subagent_type="audit-security",      prompt=<USER PROMPT>)
   Agent(subagent_type="audit-simplification",prompt=<USER PROMPT>)
   Agent(subagent_type="audit-research",      prompt=<USER PROMPT>)
   Agent(subagent_type="audit-architecture",  prompt=<USER PROMPT>)
   ```

   Skip any role not in the triage subset.

   **Do NOT call `Agent(subagent_type="code-audit", …)`.** This skill
   IS the orchestrator — it calls the audit-* subagents directly,
   never itself. `code-audit` is a skill, not a subagent; the Agent
   tool will reject that name.

   The user prompt template is the small block below — the role,
   brief, anti-bias contract, verification rule, output format, and
   big-output recipe are already in the agent's system prompt and
   must NOT be repeated.

5. **Merge the outputs**:
   - Concatenate every specialist's FIX list.
   - Dedupe by `path:line` + similar issue text. When two specialists
     flag the same line, keep the more concrete fix and append the
     other's reasoning as a supporting "Why".
   - Concatenate NOTEs. Drop exact duplicates only.
   - Surface every QUESTION immediately to the user — do not guess.

6. **Verify before claiming a FIX** (the orchestrator's last gate):
   - **Schema changes** — confirm against migrations / live schema.
   - **Import patterns** — grep current usage; if the codebase already
     does it the proposed way, drop the FIX.
   - **Defensive guards** — trace the call sites; if the condition is
     provably unreachable, prefer deleting dead code over adding a
     guard.
   - **Standards conflicts** — if a specialist's FIX contradicts an
     observed dominant pattern, flag the *standard* for review and
     downgrade the FIX to a NOTE.

   Anything not verifiable becomes a NOTE, not a FIX.

7. **Act on the merged output**:
   - **Report mode**: emit the report (template below) and stop.
   - **Cleanup mode**: apply every FIX. Run the check command,
     capturing output:
     `<check-cmd> > /tmp/hawk-code-audit-check.log 2>&1`, then
     `rg -n 'error|warning|fail|FAIL' /tmp/hawk-code-audit-check.log | head -50`. If it fails, fix the breakage (max 3 attempts) before reporting back.

## Specialist user-prompt template

The agent's system prompt already contains the role, anti-bias
contract, verification rule, and output schema. The orchestrator
sends only the per-call context:

```
## Files / diff in scope

{{per-file `rg -n` slices of the diff capture, or full file content
when the file is outside the diff}}

## Standards (pasted inline, do not fetch)

{{full content of every relevant `.agents/standards/` file}}

## Common mistakes (pasted inline, do not fetch)

{{full content of every relevant `.agents/common-mistakes/` file}}

## Context

{{optional — e.g. "this diff covers Inc 5–7" for callers like
implement-plan-audited; omit for plain code-audit}}
```

That's the entire user prompt. No role re-statement, no anti-bias
restatement, no output-format restatement — those are in the agent.

## Output template (orchestrator → user)

```markdown
# Code Audit Report: {{scope}}

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

In report mode, stop here. In cleanup mode, apply each FIX and run
the check command before reporting.

## Rules

- Whichever specialists run, run **in parallel** as fresh subagents.
  The subset is decided by triage (or the explicit `tier=`); the
  parallel-fresh-subagent shape never changes.
- Triage **never** reviews the code. It only classifies scope and
  picks specialists. Its output schema is non-negotiable.
- The triage decision is internal — do not surface it to the user
  unless asked.
- Each specialist user prompt must be self-contained — no shared chat
  history, no plan paths, no goal description. The agent's system
  prompt already enforces the anti-bias contract; do not weaken it
  by pasting goal context.
- Conventions are observations, not defenses. Flag what's wrong even
  when the surrounding code is also wrong.
- Verification gates are the orchestrator's job, not the specialists'
  — they propose, the orchestrator confirms before turning a FIX into
  an edit.
- An unverifiable recommendation is a NOTE, never a FIX.
- Cleanup mode is not allowed to skip the check command — a green
  build is the contract.
- **Big-output discipline.** Heavy command output (project check,
  full `git diff`, repo-wide search, long log, large fetch) goes to
  `/tmp/hawk-code-audit-<step>.log`, then
  `rg -n '<pattern>' /tmp/hawk-code-audit-<step>.log | head -50`
  extracts what you need. `Read` the file only with `offset`/`limit`.
  Specialist user prompts receive narrowed slices only.
