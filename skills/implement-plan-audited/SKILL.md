---
name: implement-plan-audited
description: Execute a plan increment-by-increment with the audit-* specialists running independently at strategic checkpoints. Inherits the full per-increment verification loop from `implement-plan` (done-criteria evidence, layered retry ladder, file-divergence check, outcome records). Adds checkpoint annotation, blind parallel audits, audit-fix verification (each FIX must close its own loop), plan-override propagation to dependent increments, and BEHAVIOR_CHANGE.md artifacts. Two modes — `manual` stops between increments for user review; `auto` applies audit fixes and proceeds without interruption (designed for hours of unattended execution). Specialists are blind to the plan and the goal.
---

# Implement Plan (Audited)

Same execution shape as `implement-plan`, with one addition: at strategic **audit checkpoints** (not after every increment), the `audit-*` specialist subagents run in parallel against the cumulative diff since the previous checkpoint and either auto-apply their fixes (auto mode) or surface them for user review (manual mode). The specialist subset is decided per checkpoint by `audit-triage`.

Checkpoints are computed and written into the plan file before execution starts, so audits happen after a few small increments, after two medium increments, after a single large increment — not after every single increment. A 10-increment plan typically gets ~3 audits, not 10.

The specialists are independent and blind. They do not read the plan, the increment text, or the user's goal. They see only the diff and their specialist brief — see `code-audit/SKILL.md` for the orchestration shape and the agent files in `~/.claude/agents/audit-*.md` for the briefs and anti-bias contracts. That blindness is the point: an audit that knows the plan defends the plan; an audit that only sees the code evaluates the code.

This skill **inherits** the entire per-increment verification loop from `implement-plan` Step 3 — pre-implementation think step, behavior-preservation tests, layered retry ladder, done-criteria check, file-divergence check, structured outcome record. Don't re-implement those here; just call them.

## Args

- `mode=manual|auto` — default `manual`.
- `plan=<path>` — explicit plan file path. Default: detect from `.plans/`.
- `commit=auto|yes|no` — default `auto`. Commits per increment AND per audit checkpoint unless on `main`/`master`. `yes` forces commits even on trunk; `no` suppresses commits entirely.

## Process

### Step 1 — Bootstrap context

Delegates fully to `implement-plan` Step 1 (plan file, global standards, common-mistakes index, project check command, current git ref).

Additionally:

- The pre-execution git ref captured by `implement-plan` Step 1 is the **first checkpoint's base** — the cumulative diff for the first audit is computed against it.
- Maintain a **specialist findings ledger** in memory for this run: `{specialist: [findings_count_by_checkpoint]}`. Used in Step 4 for adaptive triage. Initially empty.

All check-command runs in this skill follow the **Big-output discipline**: redirect to `/tmp/hawk-implement-plan-audited-<step>.log` and inspect with `rg -n 'error|warning|fail|FAIL' /tmp/hawk-implement-plan-audited-<step>.log | head -50`. `<step>` is e.g. `inc3-check`, `ckpt2-check`, `final-check`.

### Step 1.5 — Annotate audit checkpoints into the plan

Before any code is written, walk the plan's increments in order and decide where audits will run. The result is written **into the plan file** as `**Audit checkpoint:** yes` lines under selected increments so that:

- The cadence is visible to the user before execution starts.
- A fresh session resuming the plan inherits the same cadence.
- The execution loop has a single source of truth.

**Heuristic** — assign each increment a weight by its size estimate:

| Size | Weight |
| ---- | ------ |
| S    | 1      |
| M    | 2      |
| L    | 4      |

Walk increments in dependency order. Maintain a running `accumulated_weight`, starting at 0. For each increment:

1. Add its weight to `accumulated_weight`.
2. If `accumulated_weight >= 5`, mark this increment as a checkpoint and reset `accumulated_weight = 0`.

After the walk, if the **final increment** is not already a checkpoint **and** `accumulated_weight > 0` (uncovered work at the tail), promote the final increment to a checkpoint so nothing ships unaudited.

Edge case — manual / user-driven increments (`Status: blocked-on-user`): skip them when accumulating weight, and do not mark them as checkpoints. The next executable increment can own a checkpoint instead.

**Worked examples:**

- 10 × S → checkpoints after Inc 5, Inc 10 → **2 audits**.
- 5 × M → checkpoints after Inc 3, Inc 8 → **2 audits**.
- 1 × L → checkpoint after Inc 1 → **1 audit**.
- S, S, M, S, L, M, M → after Inc 6 (S+S+M+S=5), after Inc 12 (L=4), after Inc 18 (M+M=4) → **3 audits**.

**Annotation format** — for each chosen checkpoint increment, insert a single line directly under its `**Done when:**` line (or under the increment heading if no done-when exists):

```
**Audit checkpoint:** yes
```

Do not modify any other part of the plan. After annotation, summarize to the user (in both modes): "Annotated N audit checkpoints across M increments — audits will run after: Inc X, Inc Y, Inc Z."

If the plan already contains `**Audit checkpoint:** yes` lines (user-added by hand, or this is a resumed run), **trust them and skip the heuristic** — the user's choices win. Just summarize the inherited cadence.

### Step 2 — Execution loop

For each increment in dependency order:

1. **Implement** — run `implement-plan` Step 3 in full (substeps 3.1 through 3.10, including the done-criteria check, the file-divergence check, and the structured outcome record). When that returns successfully, the increment is `done` with evidence on disk.

2. **Read forwarded markers** — before starting this increment, check whether any earlier audit checkpoint wrote a `**Plan-override raised at ckpt N:** see <ref>` line under this increment's block (see Step 4). If present, read the referenced audit note and adjust the implementation approach accordingly. The orchestrator must not silently ignore a forwarded marker.

3. **Checkpoint gate** — if this increment is annotated `**Audit checkpoint:** yes`:

   - **Audit** on the cumulative diff since the previous checkpoint (or the pre-execution ref captured in Step 1, for the first checkpoint) — see Step 3 below. Specialist subset is decided per checkpoint by `audit-triage`.
   - **Reconcile** — see Step 4.
   - Append the **structured audit note** under the checkpoint increment (format in Step 4).
   - Update the "previous checkpoint ref" to the current `git rev-parse HEAD`.

4. **Mode gate**:
   - `manual` — pause and report the increment outcome (and audit outcome, if a checkpoint just ran) before starting the next increment.
   - `auto` — proceed to the next increment immediately. No prompts. Exceptions: behavior-change FIXes and architecture-level plan-overrides stop at the next checkpoint regardless of mode (see Step 4).

Manual/user-driven increments (e.g. "hand-write context and verify in prod") are marked `blocked-on-user` and skipped, regardless of mode.

### Step 3 — Launch the audit specialists

At a checkpoint, capture the **cumulative diff** since the previous checkpoint ref (or the pre-execution ref for the first checkpoint). **Per-file enumeration first, then per-file capture** — never the raw concatenated cumulative diff:

```bash
git diff --name-only <prev_checkpoint_ref>..HEAD > /tmp/hawk-implement-plan-audited-files-<ckpt>.log
# for each file in that list:
git diff <prev_checkpoint_ref>..HEAD -- <path> > /tmp/hawk-implement-plan-audited-diff-<ckpt>-<file-slug>.patch 2>&1
```

Specialist user prompts receive narrowed `rg -n` slices from the per-file captures, never the full cumulative diff.

#### Per-checkpoint triage

Before fanning out, call:

```
Agent(subagent_type="audit-triage", prompt=<scope, signals>)
```

The triage **agent contract** — decision rule, output schema — is owned by `agents/audit-triage.md` and reused here without modification.

The **orchestrator-side triage call** — what fields to assemble in the user prompt — is mostly shared with `code-audit/SKILL.md` Step 2, with explicit deltas because the two skills capture diffs differently. The delegation table is the single source of truth:

| Field               | Source                                                                                                                                                                                                                                                                                                              |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Changed files       | **Supersedes** `code-audit` Step 2. This skill uses `git diff --name-only <prev_checkpoint_ref>..HEAD` (from the per-file capture flow), not `git diff --name-only --stat <range>`.                                                                                                                                 |
| Risk-signal greps   | **Same as** `code-audit` Step 2: narrowed `rg -n` over the diff captures, omit signals with no matches. Aggregation: greps run per-file; aggregate matches across all per-file captures into a single combined set, then apply the ~30-line cap to the combined set (not per file).                                 |
| Scope stats         | **Same as** `code-audit` Step 2 (`files: N`, `lines added/removed: +A/-B`, `layers spanned: <…>`) plus an additional field: `increments covered: <N> increments` (count, **not** the index range).                                                                                                                  |
| Adaptive bias       | **Delta**: pass the specialist findings ledger from Step 1's run state. The triage agent may use this as a tiebreak: specialists with ≥2 prior findings this run get included automatically; specialists with 0 findings across ≥3 prior checkpoints may be safely skipped when other signals don't argue for them. |
| Parse contract      | **Same**: `tier: <…>`, `specialists: <…>`, `reason: <…>` lines, in that order.                                                                                                                                                                                                                                      |
| Parse-fail fallback | **Same**: `tier=standard`, continue, never silently skip the audit. Auto mode does **not** stop on a malformed triage — bias is up.                                                                                                                                                                                 |
| When forced         | **Same**: `tier=light\|standard\|deep` skips triage and uses the static mapping in `code-audit/SKILL.md`.                                                                                                                                                                                                           |
| When run            | **Delta**: per checkpoint, not once per skill invocation. Different checkpoints in the same run can legitimately land on different tiers.                                                                                                                                                                           |

If `code-audit` Step 2 changes any "Same" row, this skill inherits the change automatically; the "Supersedes" and "Delta" rows are this skill's responsibility.

Triage decision is internal; record it in the structured audit note (see Step 4).

#### Fan out the specialists in parallel

One message, one Agent call per role in the triaged subset. Use the concrete agent names so install-time prefix rewriting stays consistent:

```
Agent(subagent_type="audit-logic",          prompt=<USER PROMPT>)
Agent(subagent_type="audit-security",       prompt=<USER PROMPT>)
Agent(subagent_type="audit-simplification", prompt=<USER PROMPT>)
Agent(subagent_type="audit-research",       prompt=<USER PROMPT>)
Agent(subagent_type="audit-architecture",   prompt=<USER PROMPT>)
```

Skip any role not in the triage subset.

**Do NOT call `Agent(subagent_type="code-audit", …)`.** `code-audit` is a _skill_, not a subagent — it has no entry in `~/.claude/agents/` and the Agent tool will reject it. The audit-\* subagents are the only callable specialists; this skill calls them directly in place of invoking `/code-audit`.

#### Specialist user prompt — minimum-context principle

The agent body owns the role, anti-bias contract, verification rule, and output schema. The orchestrator's per-call user prompt contains **only** what specialists need to evaluate the code on its own merits:

```
## Files / diff in scope

{{narrowed `rg -n` slices from the per-file captures}}

## Standards (pasted inline, do not fetch)

{{full content of every relevant `.agents/standards/` file}}

## Common mistakes (pasted inline, do not fetch)

{{full content of every relevant `.agents/common-mistakes/` file}}

## Scope

This diff covers {{N}} increments — {{files}} files, +{{added}}/-{{removed}} lines, layers: {{layers}}. Do NOT look up which increments those are or what they did. Scale your reasoning to the diff size, nothing more.

## Verification clause requirement

For every FIX you propose, include a `verify:` clause — a concrete check that confirms your fix actually resolves the finding (a command to run, a test to add, an assertion to make, a query to evaluate). FIXes without a verify clause will be rejected at reconcile.
```

**Key changes from prior versions:**

- **No increment indices.** Pass scope stats (`N increments, +A/-B lines, M files, layers`) instead of `Inc X–Y`. The orchestrator keeps the index mapping internally for its own reconciliation; the specialist doesn't need it. Removes the bias risk where "Inc 1–3" might imply foundation work and bias the specialist toward foundational concerns.
- **Verify clause requirement.** Every FIX must come with a concrete verification check. Findings without verify clauses are not closeable in Step 4.

### Step 4 — Reconcile

When all specialists return:

1. **Merge their FIX/NOTE/QUESTION outputs** the same way `code-audit` merges them — dedupe by `path:line`, attach overlapping reasoning, surface QUESTIONs immediately.

2. **Validate verify clauses.** For each FIX in the merged set, confirm a `verify:` clause is present and the clause is runnable (a command, a test name, a specific assertion — not "ensure correctness"). FIXes missing or with non-runnable verify clauses are returned to the specialist if there's session budget, or escalated to the user.

3. **Apply** depends on mode:

   - `auto` — apply every validated FIX directly. For each FIX:
     - Apply the change.
     - Run the FIX's `verify:` clause. **The verify clause must pass** — otherwise the fix did not resolve the finding (it may have masked it). On verify failure, revert that specific fix and surface to the user; do not silently proceed.
     - When all FIXes applied and verified, run the project check command with the full layered retry ladder (Stages 1–4 from `implement-plan` Step 3.5). If the ladder exhausts without a clean check: stop, fall back to manual mode, surface the audit output and the failing diff.
   - `manual` — present the merged FIX list (with verify clauses) to the user. Apply only what the user approves. Then run each approved fix's verify clause, then the project check command.

4. **Plan-override flagging.** If the merged output reveals that the approach taken in any covered increment was structurally wrong (a specialist's `Why:` describes a fundamentally cleaner architecture, or a fix touches the public API the plan specified):

   - **Apply the fix** (the immediate code is now corrected).
   - **Propagate the override.** Walk the remaining increments in the DAG. For any increment that depends on the audited range — directly or transitively — append a line under its block:
     ```
     **Plan-override raised at ckpt N:** see <audit note ref>; review approach before implementing.
     ```
     This is the marker that Step 2's "Read forwarded markers" sub-step picks up. Later increments cannot silently rebuild on a flawed foundation.
   - **Architecture-level overrides stop at the next checkpoint regardless of mode.** If the override is structural (changes module boundaries, public API surface, data model in a way the plan didn't anticipate), auto mode finishes the current run-up to the next checkpoint, runs that checkpoint's audit, then stops and surfaces to the user. Bounds the blast radius to one additional checkpoint of work.

5. **Behavior-preservation FIXes.** Any FIX that changes external behavior (HTTP response shape, function signature, side effects, error semantics, data persisted):

   - Apply and commit as its own commit (per Step 5 cadence).
   - Write `BEHAVIOR_CHANGE.md` in the plan directory (`.plans/<slug>/BEHAVIOR_CHANGE.md`), appending an entry: timestamp, ckpt id, file:line, one-line description of what changed, link to the audit note.
   - **Stop at the next checkpoint regardless of mode.** Behavior changes that emerge mid-run need explicit user acknowledgement before further increments build on them.

6. **Update the specialist findings ledger** (in-memory from Step 1) with this checkpoint's per-specialist counts. The next checkpoint's triage sees this.

7. **Append the structured audit note** under the checkpoint increment:

```
**Audit checkpoint:** yes (executed)
audit-ckpt<N>: tier=<light|standard|deep> specialists=[<list>] reason="<from triage>"
  fixes=<count> plan-overrides=<count> behavior-changes=<count> covers=<inc-labels>
```

Three lines, structured fields, parseable. A reviewer reconstructing the run can read it in 5 seconds; a tool can parse it for run analytics.

Because a checkpoint covers multiple increments, the merged FIX list will often be larger than a per-increment audit. Group findings by file in the user-facing report (manual mode) so reviewers can scan quickly.

### Step 5 — Commit hygiene

Commits per increment AND per audit checkpoint are **default-on**. Branch detection, opt-out flow, stop-out edge cases, staging-by-discovery (`git diff --name-only HEAD` + `git ls-files --others --exclude-standard`), rename/deletion handling, no-AI-attribution rule, pre-commit hook failure handling, and empty-change skip — all delegate to `implement-plan` Step 3.5 in full. The additions here: separate audit-fix commits, and a BEHAVIOR_CHANGE.md commit when applicable.

**Commit cadence:**

- **Per increment** — handled by `implement-plan` Step 3.5 inside the per-increment loop (Step 2 of this skill). The increment's outcome record (`Status: done`, etc.) is in the plan when this commit fires.
- **Per audit fix pass** — after Step 4 (reconcile) applies fixes and the check command is clean. Re-discover changes with `git diff --name-only HEAD` after applying fixes (do not track per-FIX file lists during Step 4 — re-discovery is the canonical source). **Separate commit from the increment commit**, so audit cleanup is bisectable independent of feature work.
- **BEHAVIOR_CHANGE.md commit** — when Step 4 wrote a new entry. Can be folded into the audit-fix commit if the same checkpoint produced both, or stand alone if the audit-fix commit was skipped (verify failure path).
- If the audit applied **zero fixes**, skip the audit commit entirely (no empty commits).

**Ordering when the increment IS the checkpoint:** the increment commit fires first (inside `implement-plan` Step 3.5), then the checkpoint audit runs against the new HEAD, then any audit-fix commit fires after reconcile. This means `git diff --name-only HEAD` for audit-fix staging sees only the audit's changes, not the increment's — because the increment was already committed.

**Commit message style — discovery-driven, with audit-commit disambiguation:**

1. Read `git log -10 --oneline` to detect the dominant style (done once per run, by `implement-plan` Step 3.5).
2. **Mirror the style for increment commits** verbatim (per `implement-plan` Step 3.5).
3. **For audit commits**, keep them distinguishable from increment commits so a reviewer can peel off audit cleanup with `git revert`. Match the detected style — **check Conventional Commits first** because its `<type>(<scope>):` pattern overlaps the plain-scope pattern:
   - Repo uses Conventional Commits (messages match `<type>(<scope>):`) → `chore({{slug}}): audit cleanup for {{increment-labels}}` (e.g. `chore(billing): audit cleanup for Inc 5–7`).
   - Plain `<scope>: <description>` (no parentheses) → `audit: cleanup for {{increment-labels}}`.
   - Plain lowercase imperative, no prefix → prefix with `audit:` literally.
   - Mixed / emoji-prefixed / JIRA-prefixed / unclear → default to plain `audit: cleanup for {{increment-labels}}`.
4. **`{{slug}}`** = the plan directory name (last path component of `.plans/<slug>/`).
5. **`{{increment-labels}}`** match whatever the plan's increment labels actually are — `Inc 5–7` for a numeric range, `Inc foo-bar` for non-numeric labels. Mirror the plan, do not normalize.

Auto mode honors the same cadence — the per-increment and per-audit commits make a long unattended run easy to bisect after the fact, and each commit is a recovery point if a later step fails.

### Step 6 — Completion

When all increments are `done` (or `blocked-on-user`):

1. If the final increment was not a checkpoint and there is uncovered work since the last checkpoint, run one final checkpoint audit now (this should be rare — Step 1.5 promotes the final increment to a checkpoint by default).
2. Run a final check command.
3. Summarize to the user:
   - Increments completed and blocked.
   - **Per-increment outcomes** — pull each increment's `**Attempts:**` line from the plan. Quick read of where friction happened. Flag any increment with ≥3 attempts or ≥2 ladder stages.
   - **Done-criteria evidence paths** — list each `/tmp/hawk-implement-plan-verify-incN.log`. Explicit audit trail.
   - **Audit checkpoints** — for each, paste the structured audit note (tier, specialists, fixes, plan-overrides, behavior-changes, covers).
   - **Plan-override flags raised** — including which subsequent increments got the `**Plan-override raised at ckpt N:**` marker, and whether the override was architecture-level (i.e. caused an early stop).
   - **BEHAVIOR_CHANGE.md contents** if any entries — read the file back, paste each entry.
   - Any unresolved NOTEs.
   - Any QUESTIONs the audit surfaced — how the orchestrator answered them, or what was surfaced for the user.
   - **Commit count** when commits are enabled: e.g. "N feature commits + M audit commits". If skipped, say so explicitly so the user isn't surprised by a clean `git log`.

## Auto mode — failure handling

Auto mode is designed for unattended runs. Its failure ladder:

1. **Increment implementation fails** the layered ladder (`implement-plan` Step 3.5, Stage 4) → already escalated to the user by `implement-plan` itself. Auto mode stops there.
2. **Done-criteria check cannot produce evidence** (`implement-plan` Step 3.6) → escalated by `implement-plan`. Auto mode stops.
3. **File divergence is material and unexplained** (`implement-plan` Step 3.7) → escalated by `implement-plan`. Auto mode stops.
4. **Audit specialists return** → applied → **verify clause fails** for a FIX → revert that fix, surface, stop.
5. **Audit applied** → **check command fails** the layered ladder → stop, fall back to manual.
6. **A specialist surfaces a QUESTION** it can't resolve → stop, ask the user. Auto mode does not guess on blocking questions.
7. **A non-architecture plan-override** is raised → apply the fix, propagate the marker to dependent increments, **continue.** User sees it in the completion summary.
8. **An architecture-level plan-override** is raised → apply the fix, propagate the marker, finish the current run-up to the next checkpoint, run that checkpoint, **then stop.** User decides whether to continue.
9. **A behavior-change FIX** is raised → apply, commit, write BEHAVIOR_CHANGE.md, finish the current run-up to the next checkpoint, **then stop.** Behavior changes are never silent mid-run.

Stopping in auto mode means: print the current state, the merged audit output (if any), the failing diff or failing verify clause, and the contents of BEHAVIOR_CHANGE.md if written. Wait for user input. Do not revert (except for the specific failed-verify FIX in case 4).

## Rules

- **Audits run only at annotated checkpoints**, not after every increment. Step 1.5 computes the cadence; the loop honors it.
- **Triage runs once per checkpoint**, not once per skill invocation. Different checkpoints can legitimately land on different tiers.
- **Specialists run in parallel** as fresh subagents. A single-pass non-parallel audit is never allowed.
- **Specialist prompts are blind and minimum-context.** No plan path, no goal, no chat history, **no increment indices.** Specialists get scope stats (count, lines, layers) — nothing that could leak the goal.
- **Every FIX must include a runnable `verify:` clause.** Findings without verify clauses can't close; FIXes whose verify clauses fail can't be accepted.
- **Plan-overrides propagate forward.** Auto mode marks dependent increments with `**Plan-override raised at ckpt N:**` lines that the implementer must read before starting. Architecture-level overrides stop at the next checkpoint regardless of mode.
- **Behavior-changing FIXes are never silent.** Apply, commit, write to BEHAVIOR_CHANGE.md, stop at the next checkpoint.
- **The specialist findings ledger informs adaptive triage** within a run — earned seats for specialists with hits, optional skip for specialists with consistent zero findings.
- **The plan file gets `**Audit checkpoint:** yes` lines** in Step 1.5, then the structured audit note from Step 4 under each checkpoint increment. Per-increment outcomes are owned by `implement-plan` Step 3.10 — do not duplicate them here.
- **User-authored `**Audit checkpoint:** yes` lines are respected verbatim** — the heuristic only fires when the plan has none.
- **Auto mode has hard floors at every gate.** The `implement-plan` layered ladder (4 stages), the audit-fix verify check, the audit-fix layered ladder, the QUESTION gate, the architecture-override gate, the behavior-change gate — any one stops the run. Auto mode will not loop indefinitely.
- **Commit hygiene** delegates to `implement-plan` Step 3.5 for per-increment commits and adds audit-fix / BEHAVIOR_CHANGE commits per Step 5 here. **No AI attribution, ever** — no `Co-Authored-By: Claude`, no `🤖`, no "Generated with Claude" line. No empty audit commits. No `--no-verify`. Both modes.
- **Triage-call shape is owned by `code-audit/SKILL.md` Step 2.** This skill reuses it per the delegation table in Step 3; do not duplicate or redefine the input/parse contract here.
- **Big-output discipline.** Heavy command output goes to `/tmp/hawk-implement-plan-audited-<step>.log` (or a unique slug with randomness for parallel-safe contexts), then `rg -n '<pattern>' /tmp/... | head -50` extracts what's needed. `Read` the file only with `offset`/`limit`. In auto mode, never paste a raw `/tmp` capture into the conversation — only narrowed slices.
