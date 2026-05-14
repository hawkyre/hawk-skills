---
name: implement-plan
description: Execute an approved plan increment-by-increment with deterministic verification at each step. Done-criteria are checked against evidence on disk, not asserted from memory. Failures escalate through a layered ladder (each retry qualitatively different) rather than repeated identical attempts. Existing code gets behavior-preservation tests before modification. File divergence (touched vs declared) is reconciled before each commit. Structured outcome records land in the plan file. Designed for fresh sessions with no prior context. Invoked directly, not routed from coding-process.
---

# Implement a Plan

## Args

- `commit=auto|yes|no` — default `auto`. Commits per increment unless on `main`/`master`. `yes` forces commits even on trunk; `no` suppresses commits entirely.

## Process

### Step 1 — Bootstrap context

This skill is designed for fresh sessions. Load:

- The plan file and any sibling files (`overview.md`, `data-model.md`, `decisions.md`, `verification.md`, `contracts.md`, `inc-<N>-notes.md`).
- **Globally relevant standards only** from `.agents/standards/` — the always-on baseline (commit style, security baseline, language conventions). Skip standards that only apply to specific layers; those load per increment in Step 3.1.
- The index of available common-mistakes categories from `.agents/common-mistakes/`. Don't load them all yet — load per-increment based on what each increment touches.
- The project check command — look it up, do not assume. The check command must run the **full suite** (tests, type-check, lint), not a partial scope. Capture also: how to run a single test or single file, since the layered retry ladder and done-criteria check need it.
- Current git ref: `git rev-parse HEAD`. Useful for diff-vs-start reporting.

Progressive loading is deliberate: the curse-of-instructions research is empirical — more standing context degrades adherence to each item. Per-increment loading keeps attention focused.

### Step 2 — Build the execution schedule

Parse the plan's increments. Build a dependency DAG. Identify the **ready set** — increments whose dependencies are all marked `done`. Skip any increments already completed in prior sessions.

If the plan declares an `Increment DAG` in `overview.md` (large plans), that's the source of truth. Otherwise read dependencies from each increment's `**Depends on:**` line.

### Step 3 — Execute increments

For each ready increment, run the full per-increment loop below. Substeps are ordered so verification gates fire before commit:

#### 3.1 Load increment context

- Read every file in the increment's `**Files:**` list that already exists. Don't open files outside the list — context cleanliness matters.
- Load increment-specific standards and common-mistakes based on the files and the increment's domain (e.g. `auth/` → load auth standards; migration file in the diff → load migration standards).
- If the plan has a sibling `inc-<N>-notes.md` for this increment, read it now.

#### 3.2 Think before coding

Before writing any code, outline the implementation approach in 1–3 sentences. Capture:

- The order of operations — what's the smallest reversible step that moves this increment forward?
- If the increment modifies existing functions: what does the current code do that callers depend on? Note the contract before touching it.
- What done-criteria evidence will be produced (a command output, a test result, a curl response) — this anchors Step 3.6.

This step is brief (≤ 4 lines in your own working notes). It exists to prevent the failure mode where you read files, jump to writing code, then discover mid-implementation that the chosen path doesn't fit.

#### 3.3 Behavior-preservation setup (only if modifying existing code)

If the increment's `**Files:**` includes existing files that will be modified (not just created):

- **First preference:** locate existing tests that currently exercise the code being modified. Run them. They must pass before any changes — if they fail pre-change, stop and surface (something is already broken; do not paper over).
- **If no existing tests cover the code path:** write a brief characterization test that captures the current behavior. Run it; it should pass pre-change. Commit it as part of this increment.

These tests are the regression net. After modification (Step 3.4 and beyond), they either still pass (behavior preserved — intended for refactor or additive changes) or fail (behavior changed — must be deliberate and explicitly called out in the increment's done-criteria). A failing pre-existing test after modification, with no done-criteria acknowledging the change, is a regression, not progress.

For greenfield files (created new in this increment), skip this step — there's no existing behavior to preserve.

#### 3.4 Implement

Write the code following the plan specification, the standards loaded in 3.1, and the common-mistakes loaded in 3.1. Make incremental edits; don't rewrite whole files when a targeted change is sufficient.

#### 3.5 Check command — layered retry ladder

Run the project check command, capturing output:

```
<check-cmd> > /tmp/hawk-implement-plan-check-<inc>.log 2>&1
rg -n 'error|warning|fail|FAIL' /tmp/hawk-implement-plan-check-<inc>.log | head -50
```

`<inc>` is the increment id (e.g. `inc3`). If the check passes, proceed to 3.6. If it fails, escalate through the ladder. **Each stage must be qualitatively different from the previous.** Repeating the same approach with minor variations doesn't count as a new stage.

- **Stage 1 — Level 0 retry.** Re-run the check command without changes. Transient failures (file locks, network, flaky test) clear themselves; if Stage 1 passes, proceed. Note in the outcome record that a retry was needed.
- **Stage 2 — Level 0 fix.** Read the failure carefully. Fix the immediate, specific error in the current approach. One pass. Re-run.
- **Stage 3 — Level 1 rephrase.** Re-read the increment spec, re-load the relevant standards/common-mistakes (in case context has drifted), then attempt the implementation with the failure as explicit input. Capture in working notes: "Stage 2 failed at X; standard says Y; trying Z."
- **Stage 4 — Level 3 partial replan.** Question whether the increment as specified is buildable in this codebase. If a key dependency is missing, the chosen approach is fundamentally incompatible, or the plan's assumptions don't hold — flag the **plan** as the problem, not the implementation. **Stop and surface to the user.** Do not synthesize a different plan unilaterally.

After 4 stages without a clean check, stop. Don't loop. The escalation message to the user includes: which stages were tried, what each attempted, and the current failure. Recovery decisions (skip the increment, modify the approach, abort) belong to the user.

#### 3.6 Done-criteria verification — the load-bearing gate

The check command passing means the project compiles, lints, and tests pass. It does **not** mean this increment did what was specified. Done-criteria verification is a separate gate.

Read the increment's `**Done when:**` line (EARS or GIVEN/WHEN/THEN form). Produce concrete evidence that the criterion is met:

- For endpoint changes: `curl` the endpoint and capture the response. Compare to expected.
- For UI changes: render the page or component; capture the observable state (HTML, screenshot, accessibility tree).
- For schema changes: query the DB; capture the result. Verify constraints, indexes, row shape.
- For library/internal code: run the specific test that the done-criterion implies, or write one inline if needed.
- For CLI changes: invoke the CLI; capture stdout/stderr.

Save the evidence to `/tmp/hawk-implement-plan-verify-<inc>.log`. If you cannot produce evidence, **the increment is not done.** Do not mark it done. Re-enter Step 3.4 with the verification gap as the next thing to address, or escalate to the user if the increment as specified cannot be verified externally.

This is the gate that prevents the "I think it works" hallucination pattern. Self-asserted done is unreliable, especially after long sessions; evidence on disk is not.

#### 3.7 File-divergence check

Before any commit logic runs, reconcile what was actually touched against what the plan declared:

```
git diff --name-only HEAD > /tmp/hawk-implement-plan-touched-<inc>.log
git ls-files --others --exclude-standard >> /tmp/hawk-implement-plan-touched-<inc>.log
```

Compare to the increment's `**Files:**` list:

- **Actual ⊇ Declared (more files touched than planned).** Note the divergence in the commit body with a one-line reason ("also touched X because Y"). Common legitimate causes: snapshot updates, auto-generated tests, formatter changes to files imported. If the cause is non-trivial — you genuinely touched a file the plan didn't anticipate — pause and ask the user.
- **Actual ⊂ Declared (fewer files touched).** Strong signal that the increment is incomplete. Re-check the increment spec before marking done.
- **Actual matches Declared.** Proceed.

This catches the failure mode where the agent silently wanders into files outside the increment's scope — discovered too late at audit time or in code review.

#### 3.8 Self-review against common-mistakes

Run through the loaded common-mistakes files for this increment. Don't paraphrase them — apply each one as a checklist item against the actual diff. If any apply, fix before proceeding.

This is the lowest-asymmetry verification step (same model that wrote the code is reviewing it) so it catches the least. Don't rely on it alone; it complements the deterministic gates above.

#### 3.9 Pre-commit semantic check

A targeted grep over the diff for things the check command won't catch:

- Debug residue: `console.log`, `console.debug`, `print(`, `dbg!`, `dump(`, `pp(`, language-appropriate equivalents.
- TODO/FIXME/XXX comments **added** in this increment (vs. pre-existing).
- Hardcoded-looking secrets: long base64-ish strings, `BEGIN ... PRIVATE KEY`, `sk_live_`, `xoxb-`, AWS access key patterns.
- Temp files in untracked: `tmp_*`, `*.bak`, `*.swp`, `*-debug-*`.

Pre-commit hooks (if the repo has them) catch most of this deterministically. This step is the fallback when they don't. Surface anything found; don't auto-remove without confirmation.

#### 3.10 Record outcome in the plan file

Update the increment's block in the plan file. Append a structured outcome (not free prose):

```markdown
**Status:** done
**Attempts:** 1 (or "3 stages: check failed on type, fixed import, clean on stage 3")
**Files changed:** path/a, path/b (matches plan: yes | extra: path/c — see commit body)
**Done-criteria check:** passed (evidence: /tmp/hawk-implement-plan-verify-inc3.log)
**Tests added/modified:** test_widgets.py::test_create_widget
```

Five lines. Lets the next session reconstruct what happened without re-deriving it; lets the user audit the run after the fact. Crucially: writing `Done-criteria check: passed` requires evidence in the named log — you can't write "passed" without a real file behind it.

### Step 3.5 — Commit per increment

After Step 3.10 (`done` recorded), commit before moving to the next increment. **This step's logic is referenced verbatim by `implement-plan-audited` Step 5 — do not change its number.**

1. **Stop-out edge cases first.** If the repo is mid-rebase (`.git/rebase-merge/` or `.git/rebase-apply/` exists), mid-merge (`.git/MERGE_HEAD` exists), or has unresolved conflicts (`git status --porcelain | grep -E '^(UU|AA|DD|AU|UA|UD|DU)'` returns rows) — **stop and surface the state.** Do not commit through it (matches the `cap` skill's discipline). Plain detached HEAD (not from a rebase) is fine — treat as a non-trunk branch and commit.
2. If `commit=no` (arg) or the user has explicitly opted out in the conversation — skip.
3. If `commit=yes` (arg) — proceed regardless of branch; jump to step 5.
4. Detect the current branch: `git rev-parse --abbrev-ref HEAD`. If `main` or `master` — **skip the commit by default.** The user is on the trunk; assume they have their own commit cadence. Continue execution.
5. Otherwise — commit. Single-line message matching the repo's existing style discovered via `git log -10 --oneline`. **Stage by actual change**, using the discovery already done in Step 3.7 (the `/tmp/.../touched-<inc>.log` file). Never `git add -A` or `git add .` (sweeps in unrelated `.env`, scratch files); always add by the discovered name list. **Renames + deletions:** `git diff --name-only HEAD` reports both the old (deleted) and new (modified) sides; `git ls-files --others` reports the post-rename name as untracked. Stage both; git auto-detects renames. A pure deletion is staged correctly by `git add <deleted-path>` — git records the removal.
6. **Never include AI attribution** (no `Co-Authored-By: Claude`, no `🤖`, no "Generated with Claude" line, no model name in the trailer). The commit must read as if a human wrote it.
7. **If pre-commit hooks fail**: fix the issue and create a new commit. **Never `--amend`, never `--no-verify`.** Pre-commit hooks are the deterministic verification gate the repo's maintainers chose; bypassing them is forbidden.
8. **If the discovered change list is empty** (no-op increment, fully cached) — skip the commit, log a note, continue.

Because parallel-executed increments commit serially from the orchestrator after each subagent returns, at commit time the only uncommitted changes are the just-finished increment's — `git diff --name-only HEAD` is unambiguous.

### Step 4 — Handle failures

If the layered retry ladder (Step 3.5) exhausts all 4 stages without a clean check, OR if Step 3.6 cannot produce done-criteria evidence, OR if Step 3.7 reveals material file divergence the agent can't explain: **stop.** Report:

- The specific failure (output of the final check, or the missing evidence, or the file divergence).
- Which stages of the ladder were tried and what each attempted.
- The current diff state (uncommitted).

Ask the user: continue with a modified approach, skip this increment (mark `blocked-on-user`), or abort. Do not loop indefinitely; do not synthesize a different plan unilaterally.

### Step 5 — Completion

When all increments are `done` (or `blocked-on-user`):

1. Run a final full check command. Capture to `/tmp/hawk-implement-plan-final-check.log`.
2. Self-review the full diff against the full loaded standards set (not just per-increment subsets).
3. Summarize to the user:
   - Increments completed and blocked.
   - For each completed increment: attempts (1 / 2 / 3 stages — quick signal of friction).
   - Files created/modified across the run.
   - Standards followed.
   - **Per-increment done-criteria evidence files** (the `/tmp/.../verify-incN.log` paths) — explicit audit trail.
   - Remaining manual verification (anything the plan flagged as out of scope for automated checks).
   - **Commit count** when commits are enabled. If skipped (on `main`/`master` or `commit=no`), say so explicitly so the user isn't surprised by a clean `git log`.

## Parallel execution

When multiple increments are independent (no shared files, all dependencies satisfied, all S or M complexity), launch them simultaneously via subagents. Each subagent receives a self-contained prompt with:

- The relevant slice of the plan (its increment + dependencies' summaries).
- All standards and common-mistakes for the files it will touch — pasted inline.
- The **Big-output discipline** rule verbatim (so subagents apply the same `/tmp` + `rg` recipe to their own check-command runs).
- The full per-increment loop instructions (Steps 3.1 through 3.10).

**Subagents do NOT commit.** They return their diff to the orchestrator. The orchestrator owns the working tree and commits each subagent's work serially in DAG-scheduled order, applying Step 3.5 to each one.

The parallel path uses the same verification gates as the serial path — done-criteria check, file-divergence check, outcome record. A subagent returning "I implemented it and the check passed" is not enough; the subagent's verify log is part of what it returns, and the orchestrator confirms before committing.

## Rules

- **Fresh sessions without context produce wrong code.** Loading the plan, global standards, and increment-specific standards/common-mistakes is non-negotiable.
- **Never implement ahead of dependencies.** The DAG exists for a reason.
- **Done means evidence on disk, not memory.** The done-criteria check (Step 3.6) is the load-bearing verification gate. An increment without a verify log is not done — regardless of what the check command says.
- **Layered retries, not repeated retries.** Each stage of the ladder must be qualitatively different from the previous. Repeating the same approach three times doesn't count as three attempts.
- **Behavior preservation by default.** When modifying existing code, find or write tests that capture current behavior before changing. A failing pre-existing test post-modification, without a done-criteria explicitly calling out the change, is a regression.
- **File divergence is a signal, not a footnote.** Reconcile touched-vs-declared before every commit. Material divergence pauses the run.
- **Update the plan file after every increment.** Structured outcome record, not just `Status: done`. The plan is the source of truth across sessions.
- **Subagent prompts must be self-contained.** They can't access the parent context. Paste all context inline, including the Big-output discipline rule.
- **Do not modify the plan's design.** If the plan is wrong — Stage 4 of the ladder — stop and tell the user. Do not write a different plan.
- **Commit per increment by default.** Skip on `main`/`master` or with `commit=no`. Stop and surface mid-rebase / mid-merge / unresolved-conflict states; do not commit through them.
- **The orchestrator commits — subagents do NOT.** Parallel-mode subagents return their diff; the orchestrator stages by discovery and commits serially.
- **Commit messages mirror the repo's existing style** (read `git log -10 --oneline`). **No AI attribution, ever** — no `Co-Authored-By: Claude`, no `🤖`, no "Generated with Claude" line. The commit must read as if a human wrote it.
- **Never `--amend`, never `--no-verify`.** Pre-commit hooks are the repo's deterministic verification gate; bypassing them is forbidden.
- **Big-output discipline.** Heavy command output (project check, full `git diff`, repo-wide search, long log, large fetch) goes to `/tmp/hawk-implement-plan-<step>.log`, then `rg -n '<pattern>' /tmp/hawk-implement-plan-<step>.log | head -50` extracts what you need. `Read` the file only with `offset`/`limit`. Subagent prompts include this rule verbatim.
