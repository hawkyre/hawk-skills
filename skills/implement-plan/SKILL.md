---
name: implement-plan
description: Execute an approved plan increment-by-increment with deterministic verification at each step. Use whenever the user says "implement the plan", "run the plan", "execute the plan", "work through the increments", "do the plan", or invokes /implement-plan. Done-criteria are checked against evidence on disk, not asserted from memory; failures escalate through a layered ladder rather than repeated identical attempts; existing code gets behavior-preservation tests before modification; file divergence (touched vs declared) is reconciled before each commit; structured outcome records land in the plan file. Designed for fresh sessions with no prior context. Do NOT use for planning itself — use `plan-small` or `plan-large`. Do NOT use for unplanned coding without a plan file — use `coding-process`. Do NOT use when the user wants audits in the loop — use `implement-plan-audited`.
---

# Implement a plan

## Args

- `commit=auto|yes|no` — default `auto`. Commits per increment unless on `main`/`master`. `yes` forces commits even on trunk; `no` suppresses commits entirely.

## Process

### Step 1 — Bootstrap context

Fresh session. Load:

- The plan file and any sibling files (`overview.md`, `data-model.md`, `decisions.md`, `verification.md`, `contracts.md`, `inc-<N>-notes.md`).
- Globally relevant standards only from `.agents/standards/` — the always-on baseline (commit style, security baseline, language conventions). Layer-specific standards load per increment in Step 3.1.
- Index of available common-mistakes from `.agents/common-mistakes/`. Don't load them all yet — load per-increment based on what each increment touches.
- The project check command (look it up; do not assume). Must run the full suite — tests, type-check, lint — not a partial scope. Also capture how to run a single test or single file; the retry ladder and done-criteria check need it.
- Current git ref: `git rev-parse HEAD`. Useful for diff-vs-start reporting.

Progressive loading is the point — more standing context degrades adherence to each item. Per-increment loading keeps attention focused.

### Step 2 — Build the execution schedule

Parse increments. Build a dependency DAG. Identify the ready set — increments whose dependencies are all `done`. Skip increments already completed in prior sessions.

If `overview.md` declares an `Increment DAG`, that's the source of truth. Otherwise read each increment's `**Depends on:**` line.

### Step 3 — Execute increments

For each ready increment, run the per-increment loop below. Substeps are ordered so verification gates fire before commit.

#### 3.1 Load increment context

- Read every file in the increment's `**Files:**` list that already exists. Don't open files outside the list.
- Load increment-specific standards and common-mistakes based on the files and domain (e.g. `auth/` → load auth standards; migration file present → load migration standards).
- If the plan has a sibling `inc-<N>-notes.md`, read it now.

#### 3.2 Think before coding

In ≤ 4 lines of working notes:

- Smallest reversible step that moves this increment forward.
- If modifying existing functions: what does the current code do that callers depend on? Note the contract before touching it.
- What done-criteria evidence will be produced (command output, test result, curl response) — anchors Step 3.6.

#### 3.3 Behavior-preservation setup (only if modifying existing code)

If the increment's `**Files:**` includes existing files that will be modified (not just created):

- First preference: locate existing tests that exercise the code being modified. Run them — they must pass pre-change. If they fail pre-change, stop and surface; something is already broken.
- If no existing tests cover the path: write a brief characterization test. Run it — should pass pre-change. Commit it as part of the increment.

These tests are the regression net. After modification, they either still pass (intended for refactor / additive changes) or fail (must be deliberate and explicitly called out in done-criteria). A failing pre-existing test post-modification, without a done-criteria acknowledging the change, is a regression.

For greenfield files, skip this step — no existing behavior to preserve.

#### 3.4 Implement

Write code per the plan spec, the standards loaded in 3.1, and the common-mistakes loaded in 3.1. Incremental edits — don't rewrite whole files when a targeted change is enough.

#### 3.5 Check command — layered retry ladder

Run the project check command:

```
<check-cmd> > /tmp/hawk-implement-plan-check-<inc>.log 2>&1
rg -n 'error|warning|fail|FAIL' /tmp/hawk-implement-plan-check-<inc>.log | head -50
```

`<inc>` is the increment id (e.g. `inc3`). If clean, proceed to 3.6. If not, escalate. Each stage must be qualitatively different from the previous — repeating the same approach with minor variations doesn't count.

- Stage 1 — bare retry. Re-run without changes. Transient failures (file lock, network, flaky test) clear themselves. If clean, proceed; note the retry in the outcome record.
- Stage 2 — direct fix. Read the failure carefully. Fix the immediate, specific error. One pass. Re-run.
- Stage 3 — rephrase. Re-read the increment spec, re-load the relevant standards/common-mistakes (context may have drifted), then re-attempt with the failure as explicit input. Note in working notes: "Stage 2 failed at X; standard says Y; trying Z."
- Stage 4 — flag the plan. Question whether the increment as specified is buildable in this codebase. If a key dependency is missing, the chosen approach is fundamentally incompatible, or the plan's assumptions don't hold — flag the plan, not the implementation. Stop and surface. Do not synthesize a different plan unilaterally.

After 4 stages without a clean check, stop. The escalation message lists which stages were tried, what each attempted, and the current failure. Recovery decisions (skip, modify, abort) belong to the user.

#### 3.6 Done-criteria verification — the load-bearing gate

The check command passing means compile / lint / tests pass. It does not mean this increment did what was specified.

Read the increment's `**Done when:**` line (EARS or GIVEN/WHEN/THEN). Produce concrete evidence:

- Endpoint changes: `curl` and capture the response. Compare to expected.
- UI changes: render the page; capture observable state (HTML, screenshot, accessibility tree).
- Schema changes: query the DB; capture the result. Verify constraints, indexes, row shape.
- Library / internal code: run the specific test the done-criterion implies, or write one inline.
- CLI changes: invoke the CLI; capture stdout/stderr.

Save to `/tmp/hawk-implement-plan-verify-<inc>.log`. If you cannot produce evidence, the increment is not done — re-enter 3.4 with the verification gap as the next thing to address, or escalate.

This is the gate against the "I think it works" pattern. Self-asserted done is unreliable; evidence on disk is not.

#### 3.7 File-divergence check

Before commit, reconcile touched vs declared:

```
git diff --name-only HEAD > /tmp/hawk-implement-plan-touched-<inc>.log
git ls-files --others --exclude-standard >> /tmp/hawk-implement-plan-touched-<inc>.log
```

Compare to the increment's `**Files:**` list:

- Actual ⊇ Declared (more touched than planned). Note in the commit body with a one-line reason ("also touched X because Y"). Legitimate causes: snapshot updates, auto-generated tests, formatter side effects on imported files. If the cause is non-trivial — a file the plan didn't anticipate — pause and ask.
- Actual ⊂ Declared (fewer touched). Strong signal of incompleteness. Re-check the spec before marking done.
- Actual matches Declared. Proceed.

Catches the failure mode where the agent silently wanders into out-of-scope files — discovered too late at audit time or in code review.

#### 3.8 Self-review against common-mistakes

Walk through the loaded common-mistakes files for this increment. Apply each as a checklist item against the actual diff — do not paraphrase, apply. If any apply, fix before proceeding.

Lowest-asymmetry verification (same model that wrote the code is reviewing). Complements the deterministic gates above; do not rely on it alone.

#### 3.9 Pre-commit semantic check

Targeted grep over the diff for things the check command won't catch:

- Debug residue: `console.log`, `console.debug`, `print(`, `dbg!`, `dump(`, `pp(`, language-appropriate equivalents.
- TODO/FIXME/XXX comments added in this increment (vs pre-existing).
- Hardcoded-looking secrets: long base64-ish strings, `BEGIN ... PRIVATE KEY`, `sk_live_`, `xoxb-`, AWS access key patterns.
- Temp files in untracked: `tmp_*`, `*.bak`, `*.swp`, `*-debug-*`.

Pre-commit hooks catch most of this deterministically — this step is the fallback when they don't. Surface findings; don't auto-remove without confirmation.

#### 3.10 Record outcome in the plan file

Append a structured outcome under the increment block (not free prose):

```markdown
**Status:** done
**Attempts:** 1 (or "3 stages: check failed on type, fixed import, clean on stage 3")
**Files changed:** path/a, path/b (matches plan: yes | extra: path/c — see commit body)
**Done-criteria check:** passed (evidence: /tmp/hawk-implement-plan-verify-inc3.log)
**Tests added/modified:** test_widgets.py::test_create_widget
```

Five lines. Lets the next session reconstruct what happened without re-deriving it; lets the user audit the run after the fact. Writing `Done-criteria check: passed` requires evidence in the named log — no log, no "passed".

### Step 3.5 — Commit cadence (contract `CC-1`)

After Step 3.10 records `done`, commit before the next increment. This sub-step is the named contract `CC-1`. Sibling skills (notably `implement-plan-audited`) inherit it by reference; do not duplicate its rules elsewhere. The step number is stable — `code-audit` and `implement-plan-audited` reference "Step 3.5" by name.

1. Stop-out edge cases first. If the repo is mid-rebase (`.git/rebase-merge/` or `.git/rebase-apply/` exists), mid-merge (`.git/MERGE_HEAD` exists), or has unresolved conflicts (`git status --porcelain | grep -E '^(UU|AA|DD|AU|UA|UD|DU)'` returns rows) — stop and surface the state. Do not commit through (matches the `cap` skill's discipline). Plain detached HEAD (not from a rebase) is fine — treat as non-trunk and commit.
2. If `commit=no` (arg) or the user has opted out in conversation — skip.
3. If `commit=yes` (arg) — proceed regardless of branch; jump to step 5.
4. Detect the current branch: `git rev-parse --abbrev-ref HEAD`. If `main` or `master` — skip the commit by default. The user is on trunk; assume their own cadence. Continue execution.
5. Otherwise — commit. Single-line message matching the repo's existing style (discovered via `git log -10 --oneline`). Stage by actual change, using the discovery from Step 3.7 (the `/tmp/.../touched-<inc>.log`). Never `git add -A` or `git add .` — they sweep in `.env`, scratch files, unrelated changes. Always stage by the discovered name list. Renames + deletions: `git diff --name-only HEAD` reports both the old (deleted) and new (modified) sides; `git ls-files --others` reports the post-rename name as untracked. Stage both; git auto-detects renames. A pure deletion is staged correctly by `git add <deleted-path>` — git records the removal.
6. No AI attribution. No `Co-Authored-By: Claude`, no robot emoji, no "Generated with Claude" line, no model name in the trailer. The commit must read as if a human wrote it.
7. If pre-commit hooks fail: fix the issue and create a new commit. Never `--amend`, never `--no-verify`. Pre-commit hooks are the repo maintainers' chosen deterministic gate; bypassing them is forbidden.
8. If the discovered change list is empty (no-op increment, fully cached): skip the commit, log a note, continue.

Because parallel-executed increments commit serially from the orchestrator after each subagent returns, at commit time the only uncommitted changes are the just-finished increment's — `git diff --name-only HEAD` is unambiguous.

### Step 4 — Handle failures

If the retry ladder (3.5) exhausts 4 stages without a clean check, OR 3.6 cannot produce evidence, OR 3.7 reveals material divergence the agent can't explain: stop. Report:

- The specific failure (final check output, missing evidence, or file divergence).
- Which ladder stages were tried and what each attempted.
- The current diff state (uncommitted).

Ask the user: continue with a modified approach, skip this increment (mark `blocked-on-user`), or abort. Do not loop. Do not synthesize a different plan unilaterally.

### Step 5 — Completion

When all increments are `done` or `blocked-on-user`:

1. Run a final full check command. Capture to `/tmp/hawk-implement-plan-final-check.log`.
2. Self-review the full diff against the full loaded standards set (not just per-increment subsets).
3. Summarize to the user:
   - Increments completed and blocked.
   - For each completed increment: attempts (1 / 2 / 3 stages — quick signal of friction).
   - Files created/modified across the run.
   - Standards followed.
   - Per-increment done-criteria evidence files (`/tmp/.../verify-incN.log`) — explicit audit trail.
   - Remaining manual verification (anything the plan flagged as out of scope for automated checks).
   - Commit count when enabled. If skipped (on `main`/`master` or `commit=no`), say so explicitly so the user isn't surprised by a clean `git log`.

## Parallel execution

When multiple increments are independent (no shared files, all dependencies satisfied, all S or M complexity), launch them simultaneously via subagents. Each subagent prompt is self-contained:

- The relevant slice of the plan (its increment + dependencies' summaries).
- All standards and common-mistakes for the files it will touch — pasted inline.
- The Big-output discipline rule verbatim (so subagents apply the same `/tmp` + `rg` recipe to their own check-command runs).
- The full per-increment loop instructions (Steps 3.1 through 3.10).

Subagents do not commit. They return their diff to the orchestrator. The orchestrator owns the working tree and applies CC-1 serially in DAG-scheduled order after each subagent returns.

The parallel path uses the same verification gates as the serial path — done-criteria check, file-divergence check, outcome record. A subagent's "I implemented it and the check passed" is not enough; its verify log is part of what it returns, and the orchestrator confirms before committing.

## Hard floors

The Process steps above are the source of truth. These are the floors that must not slip:

- Fresh sessions without context produce wrong code. Loading the plan, global standards, and increment-specific standards/common-mistakes is non-negotiable.
- Never implement ahead of dependencies. The DAG exists for a reason.
- Done means evidence on disk, not memory (Step 3.6). An increment without a verify log is not done — regardless of what the check command says.
- Retries are layered, not repeated (Step 3.5). Each stage qualitatively different.
- Behavior preservation by default when modifying existing code (Step 3.3). A failing pre-existing test post-modification, without a done-criteria explicitly calling out the change, is a regression.
- File divergence is a signal, not a footnote (Step 3.7). Material divergence pauses the run.
- Plan file gets a structured outcome after every increment (Step 3.10), not just `Status: done`.
- Commit cadence follows CC-1. No AI attribution, no `--amend`, no `--no-verify`, no `git add -A`, no commits through mid-rebase / mid-merge / unresolved-conflict states.
- Subagent prompts are self-contained. They can't access the parent context — paste all context inline, including the Big-output discipline rule.
- Stage 4 stops the run. Do not modify the plan's design — if the plan is wrong, tell the user.
- The orchestrator commits — subagents do not.
- Big-output discipline. Heavy command output (project check, full `git diff`, repo-wide search, long log, large fetch) goes to `/tmp/hawk-implement-plan-<step>.log`, then `rg -n '<pattern>' /tmp/hawk-implement-plan-<step>.log | head -50` extracts what you need. `Read` the file only with `offset`/`limit`. Subagent prompts include this verbatim.
