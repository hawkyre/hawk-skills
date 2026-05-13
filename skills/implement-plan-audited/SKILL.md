---
name: implement-plan-audited
description: Execute a plan increment-by-increment with the audit-* specialists running independently at strategic checkpoints. Before execution, the orchestrator annotates the plan with audit checkpoints based on increment sizes (e.g. after a single L, after two M, after a few S). Two modes — `manual` stops between increments for user review, `auto` applies audit fixes and proceeds without interruption (designed for hours of unattended execution). Audit subagents are blind to the plan and the goal, so they evaluate code on its own merits.
---

# Implement Plan (Audited)

Same execution shape as `implement-plan`, with one addition: at
strategic **audit checkpoints** (not after every increment), the
`audit-*` specialist subagents run in parallel against the cumulative
diff since the previous checkpoint and either auto-apply their fixes
(auto mode) or surface them for user review (manual mode). The
specialist subset is decided per checkpoint by `audit-triage`.

Checkpoints are computed and written into the plan file before
execution starts, so audits happen after a few small increments, after
two medium increments, after a single large increment, etc. — not after
every single increment. A 10-increment plan typically gets ~3 audits,
not 10.

The specialists are independent and blind. They do not read the plan,
the increment text, or the user's goal. They see only the diff and
their specialist brief — see `code-audit/SKILL.md` for the
orchestration shape and the agent files in `~/.claude/agents/audit-*.md`
for the briefs and anti-bias contracts. That blindness is the point:
an audit that knows the plan defends the plan; an audit that only sees
the code evaluates the code.

## When to use this skill vs `implement-plan`

- `implement-plan` — trust the plan, get it done.
- `implement-plan-audited` (manual) — the plan is a starting point;
  work gets stress-tested at audit checkpoints (after a few small
  increments / a couple of mediums / one large). Stops between
  increments so you can review.
- `implement-plan-audited` (auto) — same checkpoint cadence, no user
  gate. Use when you want to leave a plan running for hours and come
  back to a finished, audited result. Failure auto-falls-back to
  manual.

## Args

- `mode=manual|auto` — default `manual`.
- `tier=auto|light|standard|deep` — default `auto`. Passed through to
  each checkpoint audit. `auto` calls `audit-triage` per checkpoint
  and lets it pick the specialist subset for that checkpoint's diff.
  Explicit values force the same tier on every checkpoint. See
  `code-audit/SKILL.md` for the static tier→specialist mapping.
  Replaces the old `agents=full|light` knob.
- `plan=<path>` — explicit plan file path. Default: detect from `.plans/`.
- `commit=auto|yes|no` — default `auto`. Commits per increment AND per audit checkpoint unless on `main`/`master`. `yes` forces commits even on trunk; `no` suppresses commits entirely.

## Process

### Step 0 — Locate and load the plan

Same as `implement-plan` — read the plan file, match standards and
common mistakes, summarize to the user.

### Step 1 — Bootstrap context

Same as `implement-plan` Step 1. Capture the project check command. The
orchestrator will need it for verification gates. Also capture the
current git ref (`git rev-parse HEAD`) — the first checkpoint's audit
diff is computed against it.

All check-command runs in this skill follow the **Big-output discipline**: redirect to `/tmp/hawk-implement-plan-audited-<step>.log` and inspect with `rg -n 'error|warning|fail|FAIL' /tmp/hawk-implement-plan-audited-<step>.log | head -50`. `<step>` is e.g. `inc3-check`, `ckpt2-check`, `final-check`.

### Step 1.5 — Annotate audit checkpoints into the plan

Before any code is written, walk the plan's increments in order and
decide where audits will run. The result is written **into the plan
file** as `**Audit checkpoint:** yes` lines under selected increments
so that:

- The cadence is visible to the user before execution starts.
- A fresh session resuming the plan inherits the same cadence.
- The execution loop has a single source of truth.

**Heuristic** — assign each increment a weight by its size estimate:

| Size | Weight |
| ---- | ------ |
| S    | 1      |
| M    | 2      |
| L    | 4      |

Walk increments in dependency order. Maintain a running
`accumulated_weight`, starting at 0. For each increment:

1. Add its weight to `accumulated_weight`.
2. If `accumulated_weight >= 4`, mark this increment as a checkpoint
   and reset `accumulated_weight = 0`.

After the walk, if the **final increment** is not already a checkpoint
**and** `accumulated_weight > 0` (i.e. there is uncovered work at the
tail), promote the final increment to a checkpoint so nothing ships
unaudited.

Edge case — manual / user-driven increments
(`Status: blocked-on-user`): skip them when accumulating weight, and
do not mark them as checkpoints. The next executable increment can
own a checkpoint instead.

**Worked examples:**

- 10 × S → checkpoints after Inc 4, Inc 8, Inc 10 → **3 audits**.
- 5 × M → checkpoints after Inc 2, Inc 4, Inc 5 → **3 audits**.
- 1 × L → checkpoint after Inc 1 → **1 audit**.
- S, S, M, S, L, M, M → after Inc 4 (S+S+M+S=5), after Inc 5 (L=4),
  after Inc 7 (M+M=4) → **3 audits**.

**Annotation format** — for each chosen checkpoint increment, insert a
single line directly under its `**Done criteria:**` line (or under the
increment heading if no done-criteria line exists):

```
**Audit checkpoint:** yes
```

Do not modify any other part of the plan. After annotation, summarize
to the user (in both modes): "Annotated N audit checkpoints across M
increments — audits will run after: Inc X, Inc Y, Inc Z."

If the plan already contains `**Audit checkpoint:** yes` lines (e.g.
the user added them by hand, or this is a resumed run), **trust them
and skip the heuristic** — the user's choices win. Just summarize the
inherited cadence.

### Step 2 — Execution loop

For each increment in dependency order:

1. **Implement** — follow `implement-plan` Step 3 (read files, write
   code, run the check command until clean, self-review against common
   mistakes).
2. **Mark done** — update the increment's `**Status**:` to `done` in the
   plan file. Do **not** rewrite the plan to leak prior audit context
   into future increments — keep the plan stable so later increments
   are not biased.
3. **Checkpoint gate** — if this increment is annotated
   `**Audit checkpoint:** yes`:
   - **Audit** on the cumulative diff since the previous checkpoint
     (or the pre-execution ref captured in Step 1, for the first
     checkpoint) — see Step 3 below. Specialist subset is decided
     per checkpoint by `audit-triage`.
   - **Reconcile** — see Step 4.
   - Append at most a one-line audit note under the checkpoint
     increment (e.g. `audit: 3 small fixes applied, 0 plan-overrides,
     covered Inc 5–7`).
   - Update the "previous checkpoint ref" to the current `git
     rev-parse HEAD`.
4. **Mode gate**:
   - `manual` — pause and report the increment outcome (and audit
     outcome, if a checkpoint just ran) before starting the next
     increment.
   - `auto` — proceed to the next increment immediately. No prompts.

Manual/user-driven increments (e.g. "hand-write context and verify in
prod") are marked `blocked-on-user` and skipped, regardless of mode.

### Step 3 — Launch the audit specialists

At a checkpoint, capture the **cumulative diff** since the previous
checkpoint ref (or the pre-execution ref for the first checkpoint).
**Per-file enumeration first, then per-file capture** — never the
raw concatenated cumulative diff:

```bash
git diff --name-only <prev_checkpoint_ref>..HEAD > /tmp/hawk-implement-plan-audited-files-<ckpt>.log
# for each file in that list:
git diff <prev_checkpoint_ref>..HEAD -- <path> > /tmp/hawk-implement-plan-audited-diff-<ckpt>-<file-slug>.patch 2>&1
```

Specialist user prompts receive narrowed `rg -n` slices from the
per-file captures, never the full cumulative diff.

**Per-checkpoint triage** (when `tier=auto`, the default). Before
fanning out, call:

```
Agent(subagent_type="audit-triage", prompt=<scope, signals>)
```

The triage **agent contract** — tiers, decision rule, output schema —
is owned by `agents/audit-triage.md` and reused here without
modification.

The **orchestrator-side triage call** — what fields to assemble in
the user prompt — is mostly shared with `code-audit/SKILL.md` Step 2,
with explicit deltas because the two skills capture diffs differently
(code-audit uses a single accumulated diff; this skill uses per-file
captures across a cumulative range). The delegation table is the
single source of truth:

| Field                    | Source                                                                                                                                                                                |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Changed files            | **Supersedes** `code-audit` Step 2. This skill uses `git diff --name-only <prev_checkpoint_ref>..HEAD` (from Step 3's per-file capture flow), not `git diff --name-only --stat <range>`. |
| Risk-signal greps        | **Same as** `code-audit` Step 2: narrowed `rg -n` over the diff captures, omit signals with no matches. **Aggregation note**: this skill's per-file capture structure means greps run per-file; aggregate the matches across all per-file captures into a single combined set, *then* apply the ~30-line cap to the combined set (not per file). |
| Scope stats              | **Same as** `code-audit` Step 2 (`files: N`, `lines added/removed: +A/-B`, `layers spanned: <…>`) **plus** an additional field: `increments covered: Inc X–Y`.                          |
| Parse contract           | **Same**: `tier: <…>`, `specialists: <…>`, `reason: <…>` lines, in that order.                                                                                                        |
| Parse-fail fallback      | **Same**: `tier=standard`, continue, never silently skip the audit. Auto mode does **not** stop on a malformed triage — bias is up.                                                   |
| When forced              | **Same**: `tier=light|standard|deep` skips triage and uses the static mapping in `code-audit/SKILL.md`.                                                                                |
| When run                 | **Delta**: per checkpoint, not once per skill invocation. Different checkpoints in the same run can legitimately land on different tiers.                                             |

If `code-audit` Step 2 changes any "Same" row, this skill inherits the
change automatically; the "Supersedes" and "Delta" rows are this
skill's responsibility.

Triage decision is internal; record it in the per-checkpoint audit
note (e.g. `audit: 3 small fixes applied, 0 plan-overrides, covered
Inc 5–7`) but do not surface it to the user unless asked.

**Fan out the specialists in parallel** — one message, one Agent call
per role in the triaged subset. Use the concrete agent names so
install-time prefix rewriting stays consistent:

```
Agent(subagent_type="audit-logic",         prompt=<USER PROMPT>)
Agent(subagent_type="audit-security",      prompt=<USER PROMPT>)
Agent(subagent_type="audit-simplification",prompt=<USER PROMPT>)
Agent(subagent_type="audit-research",      prompt=<USER PROMPT>)
Agent(subagent_type="audit-architecture",  prompt=<USER PROMPT>)
```

Skip any role not in the triage subset.

**Do NOT call `Agent(subagent_type="code-audit", …)`.** `code-audit`
is a *skill*, not a subagent — it has no entry in `~/.claude/agents/`
and the Agent tool will reject it. The audit-* subagents are the
only callable specialists; this skill is calling them directly here
in place of invoking `/code-audit`. The agent body owns the role,
anti-bias contract, verification rule, and output schema. The
orchestrator's per-call user prompt contains only:

```
## Files / diff in scope

{{narrowed `rg -n` slices from the per-file captures}}

## Standards (pasted inline, do not fetch)

{{full content of every relevant `.agents/standards/` file}}

## Common mistakes (pasted inline, do not fetch)

{{full content of every relevant `.agents/common-mistakes/` file}}

## Context

This diff covers Inc {{X}}–{{Y}}. Do NOT look up which increments
those are or what they did — they are integer indices, nothing more.
```

Tell each specialist which increment indices the diff covers (so they
can scale reasoning to the window size) but **never** reveal increment
titles, descriptions, or the plan path. The agent's anti-bias contract
already forbids reading `.plans/`; do not weaken it by pasting goal
context here.

### Step 4 — Reconcile

When all specialists return:

1. **Merge their FIX/NOTE/QUESTION outputs** the same way `code-audit`
   merges them — dedupe by `path:line`, attach overlapping reasoning,
   surface QUESTIONs immediately.
2. **Apply** depends on mode:
   - `auto` — apply every FIX directly. Run the check command. If it
     fails: fix the breakage (max 3 attempts). After 3 failed attempts,
     **fall back to manual mode**: stop, surface the audit output and
     the failing diff, and wait for user input.
   - `manual` — present the merged FIX list to the user. Apply only
     what the user approves. Then run the check command.
3. **Plan-override flagging**: if the merged output reveals that the
   approach taken in any covered increment was structurally wrong (a
   specialist's `Why:` describes a fundamentally cleaner
   architecture, or a fix touches the public API the plan specified),
   surface this as a "plan-override" item to the user even in auto
   mode. Auto mode still applies the fix; the user gets a
   notification at the next completion summary so they can decide
   whether to update later increments.
4. **Behavior preservation**: any FIX that changes external behavior
   must be surfaced even if applied. Auto mode does not get to
   silently change behavior.

Because a checkpoint covers multiple increments, the merged FIX list
will often be larger than a per-increment audit. Group findings by
file in the user-facing report so reviewers can scan quickly.

### Step 5 — Commit hygiene (default-on)

Commits per increment AND per audit checkpoint are **default-on**.
Branch detection, opt-out flow, stop-out edge cases, staging-by-
discovery (`git diff --name-only HEAD` + `git ls-files --others --exclude-standard`), rename/deletion handling, no-AI-attribution rule, pre-commit hook failure handling, and empty-change skip — all delegate to `implement-plan` Step 3.5 in full. The one addition here: commits fire both after each increment **and** after each audit fix pass.

**Commit cadence:**

- **Per increment** — after the increment's check command is clean and `**Status**:` is marked `done`, before any checkpoint gate. Follow `implement-plan` Step 3.5 for staging, branch detection, message style, and attribution rules.
- **Per audit fix pass** — after Step 4 (reconcile) applies fixes and the check command is clean. Re-discover changes with `git diff --name-only HEAD` after applying fixes (do not track per-FIX file lists during Step 4 — re-discovery is the canonical source). **Separate commit from the increment commit**, so audit cleanup is bisectable independent of feature work.
- If the audit applied **zero fixes**, skip the audit commit entirely (no empty commits).

**Ordering when the increment IS the checkpoint:** the increment commit fires first (Step 2 of the execution loop), then the checkpoint audit runs against the new HEAD, then any audit-fix commit fires after reconcile. This means `git diff --name-only HEAD` for audit-fix staging sees only the audit's changes, not the increment's — because the increment was already committed.

**Commit message style — discovery-driven, with audit-commit
disambiguation:**

1. Read `git log -10 --oneline` to detect the dominant style.
2. **Mirror the style for increment commits** verbatim (per `implement-plan` Step 3.5).
3. **For audit commits**, keep them distinguishable from increment commits in `git log` so a reviewer can peel off audit cleanup with `git revert`. Match the detected style — **check Conventional Commits first** because its `<type>(<scope>):` pattern overlaps the plain-scope pattern below:
   - Repo uses Conventional Commits (messages match `<type>(<scope>):` — parenthesized scope, e.g. `feat(billing): …`) → audit commits use `chore({{slug}}): audit cleanup for {{increment-labels}}` (e.g. `chore(billing): audit cleanup for Inc 5–7`).
   - Else if repo uses plain `<scope>: <description>` (no parentheses, e.g. `billing: add invoice export`) → audit commits use `audit: cleanup for {{increment-labels}}` (e.g. `audit: cleanup for Inc 5–7`).
   - Else if repo uses plain lowercase imperative with no prefix → audit commits prefix with `audit:` literally (e.g. `audit: cleanup for inc 5–7`).
   - Else (mixed, emoji-prefixed, JIRA-ticket-prefixed, or unclear) → default to plain `audit: cleanup for {{increment-labels}}`.
4. **`{{slug}}`** = the plan directory name (last path component of `.plans/<slug>/` from Step 0, e.g. `billing`).
5. **`{{increment-labels}}`** match whatever the plan's increment labels actually are — typically `Inc 5–7` for a numeric range, but a plan with non-numeric labels (e.g. `Inc foo-bar`) should produce `audit: cleanup for Inc foo-bar`. Mirror the plan, do not normalize.

Auto mode honors the same cadence — the per-increment and per-audit
commits make a long unattended run easy to bisect after the fact, and
each commit is a recovery point if a later step fails.

### Step 6 — Completion

When all increments are `done` (or `blocked-on-user`):

1. If the final increment was not a checkpoint and there is uncovered
   work since the last checkpoint, run one final checkpoint audit
   now (this should be rare — Step 1.5 promotes the final increment
   to a checkpoint by default).
2. Run a final check command.
3. Summarize to the user:
   - Increments completed and blocked.
   - Number of audit checkpoints run, and which increments each
     checkpoint covered.
   - Total fixes applied across all audits, broken down by specialist.
   - Plan-override flags raised.
   - Any unresolved NOTEs.
   - Any QUESTIONs that the audit surfaced and the orchestrator
     answered (and how) vs. surfaced for the user.
   - **Commit count** (when commits are enabled): e.g. "N feature
     commits + M audit commits" — sanity check for the user after a
     long auto run. If commits are skipped (on `main`/`master` or
     `commit=no`), say so explicitly so the user isn't surprised by
     a clean `git log`.

## Auto mode — failure handling

Auto mode is designed for unattended runs. Its failure ladder:

1. Increment implementation fails check command 3× → stop, fall back
   to manual.
2. Audit specialists return → applied → check command fails 3× →
   stop, fall back to manual.
3. A specialist surfaces a QUESTION it can't resolve → stop, ask the
   user (auto mode does not guess on blocking questions).
4. A plan-override is raised → apply the fix, **continue** (do not
   stop), but surface in the completion summary so the user can
   propagate to later increments if desired.

Stopping in auto mode means: print the current state, the merged
audit output, and the failing diff. Wait for user input. Do not
revert.

## Rules

- Audits run **only at annotated checkpoints**, not after every
  increment. Step 1.5 computes the cadence; the loop honors it.
- Whichever specialists run, run **in parallel** as fresh subagents.
  The subset per checkpoint is decided by triage (or by an explicit
  `tier=`); a single-pass non-parallel audit is never allowed.
- Triage runs once per checkpoint, not once per skill invocation —
  different checkpoints in the same run can legitimately land on
  different tiers.
- Specialist prompts are self-contained and blind: no plan path, no
  goal, no chat history. They may be told which increment indices
  the diff covers, but never their titles or descriptions.
- The plan file is updated with `**Audit checkpoint:** yes` lines
  during Step 1.5, then with `done` status and at most a one-line
  audit note under each checkpoint increment. Audit outputs do
  **not** leak into the plan otherwise.
- User-authored `**Audit checkpoint:** yes` lines are respected
  verbatim — the heuristic only fires when the plan has none.
- Auto mode never silently changes external behavior — those FIXes
  are always surfaced.
- Auto mode has a hard floor of 3 retries before falling back to
  manual; it will not loop forever.
- **Commit hygiene** — follow Step 5 in full (which delegates branch detection, staging, message style, no-AI-attribution rule, and pre-commit-hook handling to `implement-plan` Step 3.5). **No AI attribution, ever** — no `Co-Authored-By: Claude`, no `🤖`, no "Generated with Claude" line. No empty audit commits. No `--no-verify`. Both modes.
- **Triage-call shape is owned by `code-audit/SKILL.md` Step 2.** This skill reuses it per the delegation table in Step 3; do not duplicate or redefine the input/parse contract here.
- **Big-output discipline.** Heavy command output (project check, full `git diff`, repo-wide search, long log, large fetch) goes to `/tmp/hawk-implement-plan-audited-<step>.log`, then `rg -n '<pattern>' /tmp/hawk-implement-plan-audited-<step>.log | head -50` extracts what you need. `Read` the file only with `offset`/`limit`. See README → Big-output discipline. In auto mode, never paste a raw /tmp capture into the conversation — only narrowed slices.
