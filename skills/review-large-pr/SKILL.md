---
name: review-large-pr
description: Review a large pull request (30+ changed files) using partitioned parallel review with synthesis. Use when a PR is too large for a single audit pass.
---

# Review a Large PR

## Process

1. **Scope and partition**: Get the file list (`git diff --name-only`). Group files into review chunks of max ~10 files each, organized by logical coherence:
   - Same domain or entity
   - Same architectural layer (schemas, core logic, routers, triggers, frontend)
   - Files that import each other belong in the same chunk

2. **Dispatch parallel review agents**: For each chunk, dispatch a subagent running the `/code-audit` skill in report mode. Each subagent receives:
   - The exact file list to review
   - Relevant standards content (pasted inline — subagents can't access parent context)
   - Relevant common-mistakes content (pasted inline)
   - The 7-pass audit structure
   - The verification rules
   - Anti-patterns to avoid (lessons learned from past reviews)

   Max 3–4 subagents per wave.

3. **Synthesize across reports**: After all reports return, perform cross-cutting analysis:
   - **Deduplicate** — Multiple reports may flag the same issue
   - **Resolve conflicts** — If reviewers disagree, investigate which is correct
   - **Verify high-risk recommendations** yourself (schema changes, import changes, defensive guards)
   - **Categorize and prioritize** — Correctness bugs > security > architecture > duplication > dead code > readability

   Produce a consolidated report.

4. **Human approval gate**: Present the consolidated report. Explain total findings by category, questionable items, and cross-cutting themes. **Stop and wait for explicit approval.** Never auto-apply review findings.

5. **Implement in small batches**: After receiving approval, group approved items by file proximity (not by original report). Implement in batches of max 5–8 files. Run the check command after each batch. Fix any issues before starting the next batch.

## Rules

- The synthesis phase is non-negotiable — it catches what individual reviewers miss
- Human approval is non-negotiable — never auto-apply findings
- Small implementation batches are non-negotiable — monolithic implementation crashes or introduces cascading errors
- Feed lessons back into `.agents/common-mistakes/` after every review
