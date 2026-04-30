---
name: implement-plan-audited
description: Execute a plan increment-by-increment with the five code-audit specialists running independently at strategic checkpoints. Before execution, the orchestrator annotates the plan with audit checkpoints based on increment sizes (e.g. after a single L, after two M, after a few S). Two modes — `manual` stops between increments for user review, `auto` applies audit fixes and proceeds without interruption (designed for hours of unattended execution). Audit subagents are blind to the plan and the goal, so they evaluate code on its own merits.
---

# Implement Plan (Audited)

Same execution shape as `implement-plan`, with one addition: at strategic
**audit checkpoints** (not after every increment), the **five code-audit
specialists** run in parallel against the cumulative diff since the
previous checkpoint and either auto-apply their fixes (auto mode) or
surface them for user review (manual mode).

Checkpoints are computed and written into the plan file before
execution starts, so audits happen after a few small increments, after
two medium increments, after a single large increment, etc. — not after
every single increment. A 10-increment plan typically gets ~3 audits,
not 10.

The specialists are independent and blind. They do not read the plan, the
increment text, or the user's goal. They see only the diff and their
specialist brief — see `code-audit/SKILL.md` for the full anti-bias
contract. That blindness is the point: an audit that knows the plan
defends the plan; an audit that only sees the code evaluates the code.

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
- `agents=full|light` — passed through to the audit specialists.
  `full` = 5 specialists (default). `light` = 4 (skip online research).
- `plan=<path>` — explicit plan file path. Default: detect from `.plans/`.

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
   - **Audit (5 specialists, parallel)** on the cumulative diff since
     the previous checkpoint (or the pre-execution ref captured in
     Step 1, for the first checkpoint) — see Step 3 below.
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

Specialist prompts receive narrowed `rg -n` slices from the per-file
captures, never the full cumulative diff. Launch **all five
code-audit specialists in parallel** in a single message with
multiple Agent tool calls.

Tell each specialist (in their prompt) which increments are covered
by this audit window (e.g. "this diff covers Inc 5, Inc 6, Inc 7")
**without** revealing the increment titles, the plan, or the goal.
This lets specialists scope their reasoning to the diff size without
biasing them toward the plan's framing.

Each specialist receives the standard prompt from
`code-audit/SKILL.md` (specialist brief, anti-bias contract, files
inline, standards inline, output format). Two **non-negotiable** lines
must appear in every specialist prompt for this skill:

```
## Anti-bias guard (mandatory in this context)
- DO NOT read any file under `.plans/` or any plan directory.
- You do not know what feature this increment is part of, what other
  increments exist, or what the overall plan looks like. Your context
  is the diff and your specialist brief.
- Evaluate the code on its own merits. Conventions are not a defense.
```

Light mode skips specialist #4 (online research).

Every specialist prompt **also** includes the canonical Big-output discipline Rules bullet (see Rules below) verbatim, so each blind specialist applies the same /tmp+rg recipe when they need to capture output during their review.

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

### Step 5 — Commit hygiene (optional)

If the user wants commits per increment, commit after each increment
implements (before the checkpoint gate). At the checkpoint, after
reconcile, make a separate `audit:` commit for any fixes the
specialists applied — this keeps audit cleanup separable from
feature work in `git log`.

Message style: single-line, imperative. Use `feat({slug}): …` for
increments and `audit({slug}): cleanup for Inc X–Y` for checkpoint
fixes. No Co-Authored-By unless explicitly requested.

In auto mode, commits per increment plus a separate audit commit
per checkpoint are recommended — they make it easy to bisect after
a long run and to revert audit changes independently if needed.

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
- The audit always runs five (or four in light) parallel specialists
  when it runs. Single-pass audits are gone.
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
- Honor user-level conventions: one-line commits, no
  Co-Authored-By, no `--no-verify`, no silent lint dismissal. These
  apply to both modes.
- **Big-output discipline.** Heavy command output (project check, full `git diff`, repo-wide search, long log, large fetch) goes to `/tmp/hawk-implement-plan-audited-<step>.log`, then `rg -n '<pattern>' /tmp/hawk-implement-plan-audited-<step>.log | head -50` extracts what you need. `Read` the file only with `offset`/`limit`. See README → Big-output discipline. In auto mode, never paste a raw /tmp capture into the conversation — only narrowed slices.
