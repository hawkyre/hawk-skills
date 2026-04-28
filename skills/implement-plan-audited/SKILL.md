---
name: implement-plan-audited
description: Execute a plan increment-by-increment with the five code-audit specialists running independently after each increment. Two modes — `manual` stops between increments for user review, `auto` applies audit fixes and proceeds without interruption (designed for hours of unattended execution). Audit subagents are blind to the plan and the goal, so they evaluate code on its own merits.
---

# Implement Plan (Audited)

Same execution shape as `implement-plan`, with one addition: after every
increment passes the project check command, the **five code-audit
specialists** run in parallel against the increment's diff and either
auto-apply their fixes (auto mode) or surface them for user review
(manual mode).

The specialists are independent and blind. They do not read the plan, the
increment text, or the user's goal. They see only the diff and their
specialist brief — see `code-audit/SKILL.md` for the full anti-bias
contract. That blindness is the point: an audit that knows the plan
defends the plan; an audit that only sees the code evaluates the code.

## When to use this skill vs `implement-plan`

- `implement-plan` — trust the plan, get it done.
- `implement-plan-audited` (manual) — the plan is a starting point; each
  increment gets stress-tested before the next starts. Stops between
  increments so you can review.
- `implement-plan-audited` (auto) — same audit per increment, but no
  user gate. Use when you want to leave a plan running for hours and
  come back to a finished, audited result. Failure auto-falls-back to
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
orchestrator will need it for verification gates.

### Step 2 — Execution loop

For each increment in dependency order:

1. **Implement** — follow `implement-plan` Step 3 (read files, write
   code, run the check command until clean, self-review against common
   mistakes).
2. **Audit (5 specialists, parallel)** — see Step 3 below.
3. **Reconcile** — see Step 4.
4. **Mark done** — update the increment's `**Status**:` to `done` in the
   plan file. Append at most a one-line audit note (e.g. `audit:
   3 small fixes applied, 0 plan-overrides`). Do **not** rewrite the
   plan to leak audit context into future increments — keep the plan
   stable so later increments are not biased by earlier audits.
5. **Mode gate**:
   - `manual` — pause and report the increment outcome to the user
     before starting the next increment.
   - `auto` — proceed to the next increment immediately. No prompts.

Manual/user-driven increments (e.g. "hand-write context and verify in
prod") are marked `blocked-on-user` and skipped, regardless of mode.

### Step 3 — Launch the audit specialists

After the increment's check command passes, capture the increment's
diff (`git diff` against the pre-increment ref or the staged changes)
and launch **all five code-audit specialists in parallel** in a single
message with multiple Agent tool calls.

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
   increment's approach was structurally wrong (a specialist's `Why:`
   describes a fundamentally cleaner architecture, or a fix touches
   the public API the plan specified), surface this as a
   "plan-override" item to the user even in auto mode. Auto mode
   still applies the fix; the user gets a notification at the next
   completion summary so they can decide whether to update later
   increments.
4. **Behavior preservation**: any FIX that changes external behavior
   must be surfaced even if applied. Auto mode does not get to
   silently change behavior.

### Step 5 — Commit hygiene (optional)

If the user wants commits per increment, commit after reconcile.
Message style: single-line, imperative. Use `feat({slug}): …` or
`refactor({slug}): audit cleanup for …` if the audit changed
material things. No Co-Authored-By unless explicitly requested.

In auto mode, commits per increment are recommended — they make it
easy to bisect after a long run.

### Step 6 — Completion

When all increments are `done` (or `blocked-on-user`):

1. Run a final check command.
2. Summarize to the user:
   - Increments completed and blocked.
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

- The audit always runs five (or four in light) parallel specialists.
  Single-pass audits are gone.
- Specialist prompts are self-contained and blind: no plan path, no
  goal, no chat history.
- The plan file is updated only with the `done` status and at most a
  one-line audit note per increment. Audit outputs do **not** leak
  into the plan.
- Auto mode never silently changes external behavior — those FIXes
  are always surfaced.
- Auto mode has a hard floor of 3 retries before falling back to
  manual; it will not loop forever.
- Honor user-level conventions: one-line commits, no
  Co-Authored-By, no `--no-verify`, no silent lint dismissal. These
  apply to both modes.
