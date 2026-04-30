---
name: implement-plan
description: Execute an approved plan file systematically across increments, respecting dependencies and verifying at each step. Designed for fresh sessions with no prior context. Invoked directly, not routed from coding-process.
---

# Implement a Plan

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

   **Parallel execution:** When multiple increments are independent (no shared files, all dependencies satisfied, all small/medium complexity), launch them simultaneously via subagents. Each subagent receives a self-contained prompt with all standards and conventions pasted inline. **The Big-output discipline Rules bullet (below) is included verbatim in every subagent prompt** so subagents apply the same /tmp+rg recipe to their own check-command runs.

4. **Handle failures**: If an increment fails verification after 3 attempts: stop, report the specific errors, and ask whether to continue with a modified approach, skip, or abort.

5. **Completion**: When all increments are done, run a final check, self-review the full implementation, and summarize: increments completed, files created/modified, standards followed, remaining manual verification needed.

## Rules

- A fresh session without context produces wrong code. Loading standards and common-mistakes is non-negotiable.
- Never implement ahead of dependencies — the DAG exists for a reason
- Always verify before marking done — the check command must pass, no exceptions
- Update the plan file after every increment — the plan is the source of truth across sessions
- Subagent prompts must be self-contained — paste all context inline, they can't access the parent
- Do not modify the plan's design — if the plan is wrong, stop and tell the user
- **Big-output discipline.** Heavy command output (project check, full `git diff`, repo-wide search, long log, large fetch) goes to `/tmp/hawk-implement-plan-<step>.log`, then `rg -n '<pattern>' /tmp/hawk-implement-plan-<step>.log | head -50` extracts what you need. `Read` the file only with `offset`/`limit`. See README → Big-output discipline.
