---
name: coding-process
description: Entry point for all work. Identifies your task type and routes to the right workflow skill. Start here when beginning any task.
---

# Coding Process

This is the entry point for all work. It identifies the task type and routes to the appropriate workflow.

## Process

1. **Load context**:
   - Read relevant standards from `.agents/standards/` (check `index.yml` first)
   - Read relevant common-mistakes from `.agents/common-mistakes/` (check `index.yml` first)
   - Check `.plans/` for any existing plan files related to the current work

2. **Identify the task type** from the user's description:

   | Task Type | Route To | Trigger |
   |-----------|----------|---------|
   | Small feature / endpoint / component / config | `/plan-small` | Self-contained, fits in one PR |
   | Large feature / multi-system / architectural | `/plan-large` | Multi-day, multiple PRs, sequencing dependencies |
   | Delete feature / remove dead code / drop dependency | `/remove-code` | Removing capability |
   | Bug fix / error / crash / wrong behavior | `/fix-bug` | Something is broken |
   | Code review / audit / PR review | `/code-audit` | Reviewing code quality |
   | Aggressive cleanup of changes + tangibly-related code | `/code-audit-hardcore` | Same scope as code-audit, always-improve posture across related code (setup, wiring, siblings); big refactors route through plan skills |
   | Large PR review (30+ files) | `/review-large-pr` | PR too large for single audit |
   | Refactor / improve without behavior change | `/refactor` | Improving existing code |
   | Understand / explore / onboard | `/learn-system` | Building mental models |

3. **Route to the appropriate skill** and follow its process.

## Rules

- Always load standards and common-mistakes before starting any workflow
- If the task type is ambiguous, ask the user to clarify
- `review-plan` (Workflow 8) and `implement-plan` (Workflow 9) are invoked directly when needed — they are not routed from here
- If a plan file exists in `.plans/`, reference it and resume from where the last session left off
- **Big-output discipline.** Heavy command output (project check, full `git diff`, repo-wide search, long log, large fetch) goes to `/tmp/hawk-<skill>-<step>.log`, then `rg -n '<pattern>' /tmp/hawk-<skill>-<step>.log | head -50` extracts what you need. `Read` the file only with `offset`/`limit`. See README → Big-output discipline.
