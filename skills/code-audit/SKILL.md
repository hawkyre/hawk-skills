---
name: code-audit
description: Audit code with parallel independent specialist subagents (logic bugs, security, simplification, online research, architecture). Each runs blind to the user's goal and the plan, so they evaluate code on its own merits — not by deferring to existing patterns. Use when reviewing a diff, PR, or specific code. Supports report mode (default, stops for approval) and cleanup mode (applies local FIXes, surfaces cross-cutting issues). For full-repo restructural changes, use the hardcore-audit skill instead.
---

# Code Audit

The audit is a fan-out of independent specialists, each running as a fresh `audit-*` subagent. They work in parallel. None of them knows what feature the code is for, what plan generated it, or what the user is trying to ship. The orchestrator (this skill) merges their findings.

That blindness is the point. A reviewer who knows the goal will rationalize the code toward the goal. A reviewer who only has the diff and a narrow specialist brief is forced to evaluate the code on its own merits.

The specialist briefs, anti-bias contracts, and output formats live in the agent files (`audit-triage`, `audit-logic`, `audit-security`, `audit-simplification`, `audit-research`, `audit-architecture`). This skill orchestrates — it does not redefine those briefs.

This skill is the **quick-wins-and-surface-the-big-stuff** layer. Local FIXes get applied in cleanup mode; cross-cutting issues get surfaced as high-priority NOTEs and left for the user (or the hardcore-audit skill). For aggressive full-repo restructural changes, invoke the hardcore-audit skill explicitly.

## Posture — non-negotiable

**The orchestrator and specialists evaluate quality, not style.** Existing patterns are observations to be evaluated, not defaults to be matched. The repo is a starting point, not a baseline.

- If a function is a 200-line tangle, flag it even if every neighbouring function is also a 200-line tangle. Consistency with bad code is not a virtue.
- If an import pattern is wrong in 20 files, the 21st should not be wrong to match — flag both, and add a NOTE for the broader cleanup.
- If a plan asks for an approach that doesn't make sense in the code as it currently exists, flag the plan, not the code. The plan is not sacred; flawed plans get surfaced as QUESTIONs.
- Specialists' specialist briefs and anti-bias contracts give them license to push back on the codebase. The orchestrator must not soften their findings to match the codebase's existing tone.

**Refuse the lazy patch.** The worst failure mode of an AI auditor is a fix that silences a symptom without addressing the cause. Concretely, the orchestrator downgrades to NOTE (does not apply in cleanup mode) any FIX that:

- Silences a warning, error, or assertion without addressing why it fired.
- Adds a defensive guard for a condition that's only reachable because of a bug elsewhere — the upstream bug is the real FIX.
- Renames a variable or adds a comment when the underlying issue is structural.
- Catches an exception just to log it, when the right behaviour is to propagate or handle it.
- Adds a fallback or default that masks invalid state instead of making the invalid state unreachable.

A lazy FIX is worse than no FIX, because it makes the underlying issue invisible. When in doubt: surface, don't patch.

The goal is to leave the touched code **better than the average of its surroundings**, not to match the average.

## Modes

- **Report** (default) — Produce a merged FIX/NOTE/QUESTION report and **stop**. No edits. Wait for human approval. Use when reviewing code you didn't write, reviewing a PR, or auditing a concern.
- **Cleanup** — Apply every local FIX that survives verification, then run the project's check command. Surface cross-cutting FIXes and plan-overrides as NOTEs without applying them — those are hardcore-audit territory. Use as a post-implementation quality pass on your own code.

Cleanup mode is not licensed to do everything report mode finds. It applies the small wins (local fixes) and surfaces the big stuff (cross-cutting changes, plan-overrides) for explicit human or hardcore-audit decision.

## Args

- `mode=report|cleanup` — default `report`.
- `tier=auto|light|standard|deep` — default `auto`. The `audit-triage` agent reads the diff and picks the tier; explicit values skip triage and use the static mapping below.
- `scope=<files|diff|HEAD~N>` — default: the working diff against `HEAD`. Accepts an explicit file list, a `git diff` range, or `all` for the current working tree.

### Tier → specialists

| Tier       | Specialists                                             |
| ---------- | ------------------------------------------------------- |
| `light`    | logic, simplification                                   |
| `standard` | logic, security, simplification, architecture           |
| `deep`     | logic, security, simplification, research, architecture |

Triage may pick any subset across these tiers. When `tier` is forced, the static mapping above is used.

## Process

1. **Resolve scope.** From the args, build the file list and capture the diff. Group by layer (frontend, backend, shared). Note immediate imports/exports — neighbour files are in scope for cross-cutting checks.

   Diff capture:

   ```bash
   git diff <range> > /tmp/hawk-code-audit-diff.patch 2>&1
   git ls-files --others --exclude-standard > /tmp/hawk-code-audit-untracked.log
   ```

   The untracked-files capture matters when scope is the working tree — staged-but-uncommitted new files belong in the audit. Get the file list with `git diff --name-only <range>` (small, inline). Specialist user-prompts receive per-file `rg -n` slices of the captures, never the raw concatenated diff.

2. **Triage** (when `tier=auto`). Spawn the `audit-triage` subagent:

   ```
   Agent(subagent_type="audit-triage", prompt=<USER PROMPT>)
   ```

   Where `<USER PROMPT>` contains:

   - **Changed files** — output of `git diff --name-only --stat <range>`.
   - **Risk-signal greps** — narrowed `rg -n` matches over the diff capture for each PATH and DIFF signal listed in the agent's body (capped at ~30 lines total). Omit signals with no matches.
   - **Scope stats** — `files: N`, `lines added/removed: +A/-B`, `layers spanned: <e.g. db, api, ui>`.

   Parse the structured reply:

   ```
   tier: <light|standard|deep>
   specialists: <subset>
   reason: <…>
   ```

   The triage decision is **not surfaced to the user** — log it internally and proceed. (If the user explicitly asks "why these specialists?", show the `reason`.)

   **If the reply doesn't parse** (missing `tier:` line, unknown tier value, empty specialists list, no response): fall back to `tier=standard` (logic, security, simplification, architecture) and continue. Bias is up — never silently skip the audit because triage misbehaved.

   When `tier` is forced, skip this step and use the static mapping.

3. **Load shared context** (orchestrator only — pasted into each specialist's user prompt). Load **only what's relevant to the diff scope**, matched by file extension, layer, or domain. Skip standards and common-mistakes files that don't apply to any file in scope.

   - `.agents/standards/` (read `index.yml`, then the relevant files).
   - `.agents/common-mistakes/` (read `index.yml`, then the relevant files).
   - The check command for the project. Look it up — do not assume.

   Progressive loading is deliberate: less standing context per specialist means stronger attention to each loaded item. Specialists do not fetch additional context — what's in their prompt is what they have.

4. **Spawn the specialists in parallel.** **One message, multiple Agent tool calls.** For each role in the triage subset:

   ```
   Agent(subagent_type="audit-logic",          prompt=<USER PROMPT>)
   Agent(subagent_type="audit-security",       prompt=<USER PROMPT>)
   Agent(subagent_type="audit-simplification", prompt=<USER PROMPT>)
   Agent(subagent_type="audit-research",       prompt=<USER PROMPT>)
   Agent(subagent_type="audit-architecture",   prompt=<USER PROMPT>)
   ```

   Skip any role not in the triage subset.

   **Do NOT call `Agent(subagent_type="code-audit", …)`.** This skill IS the orchestrator — it calls the audit-\* subagents directly, never itself. `code-audit` is a skill, not a subagent; the Agent tool will reject that name.

5. **Merge the outputs.**

   - Dedupe by **`path:line`**. When multiple specialists flag the same line, merge into one FIX entry, keep the most concrete remediation, attach each specialist's `Why:` as a supporting reason, and **set `Strength: N/S`** where N is the number of specialists that independently flagged the line and S is the total specialists run. High-strength findings are stronger signals — the orchestrator and user can prioritize them.
   - Concatenate NOTEs. Drop exact duplicates only.
   - Surface every QUESTION immediately to the user — do not guess.

   Empirical: findings flagged by multiple specialists are materially stronger signals than solo findings. Don't discard that information at the merge step.

6. **Verify before claiming a FIX** — the orchestrator's last gate. Run each check that applies to the FIX. Anything that fails verification becomes a NOTE, not a FIX.

   - **Verify clause is mandatory and must be runnable.** Every FIX must include a `Verify:` clause that is a concrete check — a command to run, a test to add or run, an assertion, a query. "Verify the behaviour is correct" is not runnable; downgrade to NOTE. "Run `pytest tests/billing/test_invoice.py::test_zero_amount`" is runnable; keep as FIX. This rule has teeth: it's how downstream callers like `implement-plan-audited` close the audit loop.
   - **Schema changes** — confirm against migrations / live schema. If the schema doesn't agree, the FIX is hallucinated.
   - **Library / dependency existence** — if the FIX adds an import or suggests a package, confirm the package exists in the project's lockfile (`package.json`, `pyproject.toml`, `Cargo.toml`, `mix.exs`, etc.). The literature documents "20% of package recommendations are fabricated" — this check catches that failure mode.
   - **API / function existence** — if the FIX calls a function or method, grep the codebase or the library's docs to confirm it exists with the proposed signature. Specialists hallucinate APIs.
   - **Import patterns** — grep current usage; if the codebase already does it the proposed way, drop the FIX (it's a no-op).
   - **Defensive guards** — trace the call sites. If the condition the guard checks for is provably unreachable, prefer deleting dead code over adding a guard. (This is also the lazy-patch refusal in action.)
   - **Standards conflicts** — distinguish two cases:
     - The FIX contradicts a _documented_ standard in `.agents/standards/`. Surface the conflict to the user as a QUESTION ("standards say X, this code does Y, which is canonical?"). Do not silently downgrade.
     - The FIX contradicts an _undocumented_ observed pattern in the codebase. **Do not downgrade.** The posture is explicit: existing patterns are not defenses. The FIX is the right move; apply (in cleanup mode) or keep as FIX (in report mode).
   - **Behavior change** — if the FIX changes external behaviour (HTTP response shape, function signature, error semantics, side effects, persisted data), flag it as a behavior-change. In cleanup mode, behavior-changing FIXes are **surfaced even when applied** — never silent. (Matches `implement-plan-audited` Step 4.)
   - **Lazy-patch check** — apply the rules in the Posture section above. A FIX that masks a symptom rather than addressing the cause is downgraded to NOTE.

   **Classify scope** as the last verification step:

   - `Scope: local` — affects 1–3 files, no public API change, no cross-cutting impact. Apply in cleanup mode.
   - `Scope: cross-cutting` — affects more than 3 files, or touches a pattern repeated across the codebase, or requires structural refactor. **Surface as a high-priority NOTE; do not apply in cleanup mode.** This is hardcore-audit territory.
   - `Scope: plan-override` — the FIX implies the plan's approach was suboptimal or wrong. **Surface as QUESTION**; do not apply. The plan is not sacred but it is the user's contract — they decide whether to override.

7. **Act on the merged output.**

   - **Report mode:** emit the report (template below) and stop. No edits.

   - **Cleanup mode:** before applying any FIX, check for stop-out states (matches `implement-plan` Step 3.5):

     - Mid-rebase (`.git/rebase-merge/` or `.git/rebase-apply/` exists).
     - Mid-merge (`.git/MERGE_HEAD` exists).
     - Unresolved conflicts (`git status --porcelain | grep -E '^(UU|AA|DD|AU|UA|UD|DU)'` returns rows).

     If any state is hit — stop and surface; do not apply through it.

     Otherwise: apply each `Scope: local` FIX. After applying all local FIXes, run each FIX's `Verify:` clause individually — the verify clause must pass to confirm the fix resolved the finding rather than masking it. If a verify clause fails, revert that specific FIX and surface to the user. Once all applied FIXes have passing verify clauses, run the project check command with the **layered retry ladder**:

     - **Stage 1 (Level 0 retry):** Re-run; clears transient failures.
     - **Stage 2 (Level 0 fix):** Fix the immediate breakage caused by the FIXes.
     - **Stage 3 (Level 1 reconsider):** Which specific FIX caused the breakage? Try reverting that FIX rather than fixing forward — a false-positive FIX is more common than a structurally correct FIX that needs follow-up work. If reverting clears the build, surface that FIX as a NOTE explaining why it didn't survive.
     - **Stage 4 (Level 3 escalate):** Stop, surface the failing diff and which FIXes were applied. Recovery decisions belong to the user.

     `Scope: cross-cutting` and `Scope: plan-override` FIXes are **not applied** in cleanup mode — they remain as surfaced findings in the report. This is the boundary between code-audit and hardcore-audit.

## Specialist user-prompt template

The agent's system prompt already contains the role, anti-bias contract, verification rule, and output schema. The orchestrator sends only the per-call context:

```
## Files / diff in scope

{{per-file `rg -n` slices of the diff capture, or full file content
when the file is outside the diff}}

## Standards (pasted inline, do not fetch)

{{full content of every relevant `.agents/standards/` file}}

## Common mistakes (pasted inline, do not fetch)

{{full content of every relevant `.agents/common-mistakes/` file}}

## Context

{{optional — e.g. "this diff covers N increments, +A/-B lines, M files"
for callers like implement-plan-audited; omit for plain code-audit}}

## Verify clause requirement

For every FIX you propose, include a `Verify:` clause — a concrete,
runnable check (a command, a test name, an assertion, a query) that
confirms the FIX resolves the finding rather than masking it. FIXes
without runnable Verify clauses are downgraded to NOTEs by the
orchestrator.
```

That's the entire user prompt. No role re-statement, no anti-bias restatement, no output-format restatement — those are in the agent.

## Output template (orchestrator → user)

```markdown
# Code Audit Report: {{scope}}

## FIX

1. [path:line] — issue
   Why: …
   Fix: …
   Verify: <runnable check>
   Strength: <N>/<S> (specialists that independently flagged this)
   Scope: local | cross-cutting | plan-override
   Source: logic / security / simplification / research / architecture
   (multiple if specialists agreed)

## NOTE

1. [path:line] — observation
   Scope: local | cross-cutting

## QUESTION

1. … (surfaces blocking ambiguities and plan-overrides — do not guess)
```

In report mode, stop here. In cleanup mode, apply each `Scope: local` FIX (after running its Verify clause individually), then run the check command with the layered ladder. `Scope: cross-cutting` and `Scope: plan-override` FIXes remain surfaced; they're not auto-applied.

## Rules

- **The repo is a starting point, not a baseline.** Existing patterns are observations, not defaults. Specialists' and the orchestrator's job is to evaluate quality, not to match style. Sheep are not welcome.
- **The plan is not sacred.** If the audit reveals the plan's approach is suboptimal, surface as a QUESTION or `Scope: plan-override` FIX. Do not silently match a flawed plan.
- **Lazy patches are downgraded.** A FIX that silences a symptom without addressing the cause becomes a NOTE. The Posture section enumerates the patterns; the verification gate enforces them.
- **Every FIX must have a runnable Verify clause.** Findings without one are downgraded to NOTEs. This is the contract that `implement-plan-audited` relies on — keep it strict.
- **Strength is tracked through merge.** When multiple specialists flag the same line, that's a stronger signal — the report carries `Strength: N/S` so prioritization is explicit.
- **Cleanup mode applies local FIXes only.** `Scope: cross-cutting` and `Scope: plan-override` findings are surfaced, not auto-applied. Cross-cutting changes are the hardcore-audit skill's job.
- **Behavior-changing FIXes are never silent.** Even when applied in cleanup mode, behavior changes are surfaced to the user.
- **Cleanup mode honors stop-out cases** (mid-rebase / mid-merge / unresolved-conflict) before applying any FIX. Matches `implement-plan` Step 3.5.
- **Layered retry ladder, not 3-attempt retry.** Each stage qualitatively different; Stage 3 explicitly considers reverting a false-positive FIX rather than fixing forward.
- **Whichever specialists run, run in parallel** as fresh subagents. The subset is decided by triage (or the explicit `tier=`); the parallel-fresh-subagent shape never changes.
- **Triage never reviews the code.** It only classifies scope and picks specialists. Its output schema is non-negotiable. The triage decision is internal — do not surface unless asked.
- **Each specialist user prompt must be self-contained.** No shared chat history, no plan paths, no goal description. The agent's system prompt enforces the anti-bias contract; do not weaken it by pasting goal context.
- **Verification gates are the orchestrator's job, not the specialists'.** Specialists propose; the orchestrator confirms before turning a FIX into an edit.
- **An unverifiable recommendation is a NOTE, never a FIX.**
- **Cleanup mode is not allowed to skip the check command** — a green build is the contract.
- **No AI attribution** in any commit message that cleanup mode produces. No `Co-Authored-By: Claude`, no `🤖`, no "Generated with Claude". No `--no-verify`.
- **Big-output discipline.** Heavy command output (project check, full `git diff`, repo-wide search, long log, large fetch) goes to `/tmp/hawk-code-audit-<step>.log`, then `rg -n '<pattern>' /tmp/hawk-code-audit-<step>.log | head -50` extracts what you need. `Read` the file only with `offset`/`limit`. Specialist user prompts receive narrowed slices only.
