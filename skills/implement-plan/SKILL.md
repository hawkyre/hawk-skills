---
name: implement-plan
description: Execute an approved plan file systematically across increments, respecting dependencies and verifying at each step. Designed for fresh sessions with no prior context. Invoked directly, not routed from coding-process.
---

# Implement a Plan

## Args

- `commit=auto|yes|no` — default `auto`. Commits per increment unless
  on `main`/`master`. `yes` forces commits even on trunk; `no`
  suppresses commits entirely.

## Process

1. **Bootstrap context**: This skill is designed for fresh sessions. Load:
   - The plan file (and sibling files like shape.md, standards.md)
   - Relevant standards from `.agents/standards/` (matched from the plan's file paths and domains)
   - Relevant common-mistakes categories from `.agents/common-mistakes/`

2. **Build the execution schedule**: Parse the plan's increments. Build a dependency DAG. Identify the "ready set" — increments whose dependencies are all marked `done`. Skip any increments already completed in prior sessions.

3. **Execute increments**: For each ready increment:
   1. Read every file listed in the increment that already exists
   2. Implement following the plan specification, loaded standards, and loaded common-mistakes
   3. Run the project's check command, capturing output: `<check-cmd> > /tmp/hawk-implement-plan-check-<inc>.log 2>&1`, then `rg -n 'error|warning|fail|FAIL' /tmp/hawk-implement-plan-check-<inc>.log | head -50`. Fix errors (max 3 attempts before escalating). `<inc>` is the increment id (e.g. `inc3`).
   4. Self-review against common-mistakes files
   5. Update the plan file: mark the increment as `done`
   6. Recompute the ready set and continue

   **Parallel execution:** When multiple increments are independent (no shared files, all dependencies satisfied, all small/medium complexity), launch them simultaneously via subagents. Each subagent receives a self-contained prompt with all standards and conventions pasted inline. **The Big-output discipline Rules bullet (below) is included verbatim in every subagent prompt** so subagents apply the same /tmp+rg recipe to their own check-command runs. **Subagents do NOT commit** — the orchestrator owns the working tree and commits each subagent's work serially after it returns (see Step 3.5).

3.5. **Commit per increment.** After an increment passes its check command and is marked `done`, commit before moving to the next increment.

   1. **Stop-out edge cases first**: if the repo is mid-rebase (`.git/rebase-merge/` or `.git/rebase-apply/` exists), mid-merge (`.git/MERGE_HEAD` exists), or has unresolved conflicts (`git status --porcelain | grep -E '^(UU|AA|DD|AU|UA|UD|DU)'` returns rows) — **stop and surface the state**. Do not commit through it. (Matches the `cap` skill's discipline.) Plain detached HEAD (not the result of a rebase) is fine — treat as a non-trunk branch and commit.
   2. If `commit=no` (arg) or the user has explicitly opted out in the conversation — skip.
   3. If `commit=yes` (arg) — proceed regardless of branch; jump to step 5.
   4. Detect the current branch: `git rev-parse --abbrev-ref HEAD`. If `main` or `master` — **skip the commit by default**. The user is on the trunk; assume they have their own commit cadence. Continue execution without committing.
   5. Otherwise — commit. Single-line message, matching the repo's existing commit style discovered via `git log -10 --oneline`. **Stage by actual change, not by plan declaration**: capture working-tree changes with `git diff --name-only HEAD` plus `git ls-files --others --exclude-standard` for new untracked files. The plan's declared file list is a contract for what *should* change, not a substitute for what *actually* changed — subagents may legitimately touch additional files (snapshots, auto-gen tests, config). If the actual set diverges materially from the plan's declared list, log a one-line note in the commit body or the increment's plan entry, but commit what actually changed. Never `git add -A` or `git add .` (sweeps in unrelated `.env`, scratch files); always add by the discovered name list. **Renames + deletions:** `git diff --name-only HEAD` reports both the deletion (old path) and the modification side; `git ls-files --others` reports new untracked names (the post-rename path). Stage both; git auto-detects renames. A pure deletion (no corresponding new file) is staged correctly by `git add <deleted-path>` — git records the removal.
   6. **Never include AI attribution** (no `Co-Authored-By: Claude`, no `🤖`, no "Generated with Claude" line). The commit must read as if a human wrote it.
   7. If pre-commit hooks fail: fix the issue and create a new commit (never `--amend`, never `--no-verify`).
   8. If the discovered change list is empty (e.g. the increment was a no-op or fully cached) — skip the commit, log a note, continue.

   Because parallel-executed increments commit serially from the orchestrator after each subagent returns, at the moment of committing the only uncommitted changes are the just-finished increment's — `git diff --name-only HEAD` is unambiguous.

4. **Handle failures**: If an increment fails verification after 3 attempts: stop, report the specific errors, and ask whether to continue with a modified approach, skip, or abort.

5. **Completion**: When all increments are done, run a final check, self-review the full implementation, and summarize: increments completed, files created/modified, standards followed, remaining manual verification needed.

## Rules

- A fresh session without context produces wrong code. Loading standards and common-mistakes is non-negotiable.
- Never implement ahead of dependencies — the DAG exists for a reason
- Always verify before marking done — the check command must pass, no exceptions
- Update the plan file after every increment — the plan is the source of truth across sessions
- Subagent prompts must be self-contained — paste all context inline, they can't access the parent
- Do not modify the plan's design — if the plan is wrong, stop and tell the user
- **Commit per increment by default.** Skip on `main`/`master` or with `commit=no`. Stop and surface mid-rebase / mid-merge / unresolved-conflict states; do not commit through them (matches `cap`).
- **Commit messages mirror the repo's existing style** (read `git log -10 --oneline`). **No AI attribution, ever** — no `Co-Authored-By: Claude`, no `🤖`, no "Generated with Claude" line. The commit must read as if a human wrote it.
- **The orchestrator commits — subagents do NOT.** Parallel-mode subagents return their diff to the orchestrator, which stages by discovery (`git diff --name-only HEAD` + `git ls-files --others --exclude-standard`) and commits serially in DAG-scheduled order.
- **Big-output discipline.** Heavy command output (project check, full `git diff`, repo-wide search, long log, large fetch) goes to `/tmp/hawk-implement-plan-<step>.log`, then `rg -n '<pattern>' /tmp/hawk-implement-plan-<step>.log | head -50` extracts what you need. `Read` the file only with `offset`/`limit`. See README → Big-output discipline.
