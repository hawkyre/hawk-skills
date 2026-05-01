---
name: review-large-pr
description: Review a large pull request (30+ changed files) using chunked parallel review with synthesis. Each chunk is audited by the audit-* specialists in parallel, then synthesized into one consolidated report. Use when a PR is too large for a single audit pass.
---

# Review a Large PR

The strategy: partition the PR into coherent chunks, run the
`audit-*` specialists against each chunk in parallel, then synthesize
across chunks. Specialist briefs and anti-bias contracts live in the
agent files (`audit-triage`, `audit-logic`, `audit-security`,
`audit-simplification`, `audit-research`, `audit-architecture`) — this
skill orchestrates.

## Process

1. **Scope and partition.** Get the file list (`git diff --name-only`,
   inline — small). Group files into review chunks of max ~10 files
   each, organized by logical coherence:
   - Same domain or entity
   - Same architectural layer (schemas, core logic, routers, triggers,
     frontend)
   - Files that import each other belong in the same chunk

   For each file in scope, capture a per-file diff:

   ```
   git diff -- <path> > /tmp/hawk-review-large-pr-chunk-<n>-<file-slug>.patch 2>&1
   ```

   **Never** capture or read the concatenated multi-file diff — large
   PRs are exactly the case Big-output discipline exists for.

2. **Per-chunk triage and fan-out.** For each chunk, run the same
   pattern as `code-audit`:

   a. **Triage** (always — this is a large PR; right-sizing the
      specialist subset per chunk is the whole point of partitioning).
      Call `Agent(subagent_type="audit-triage", prompt=<chunk scope, signals>)`.
      Triage decision is internal; record it in the chunk report
      header but do not surface to the user unless asked. If triage's
      reply doesn't parse, fall back to `tier=standard` for that
      chunk and continue.

   b. **Fan out specialists in parallel** for the triaged subset.
      Use the concrete agent names — install-time prefix rewriting
      depends on it:

      ```
      Agent(subagent_type="audit-logic",         prompt=<chunk user prompt>)
      Agent(subagent_type="audit-security",      prompt=<chunk user prompt>)
      Agent(subagent_type="audit-simplification",prompt=<chunk user prompt>)
      Agent(subagent_type="audit-research",      prompt=<chunk user prompt>)
      Agent(subagent_type="audit-architecture",  prompt=<chunk user prompt>)
      ```

      Skip any role not in the triage subset. The chunk user prompt
      contains:
      - Per-file `rg -n` slices from the chunk's capture files (not
        the raw concatenated diff)
      - Relevant `.agents/standards/` content pasted inline
      - Relevant `.agents/common-mistakes/` content pasted inline
      - One-line context: `Chunk N of M; files: <count>; layer: <layer>.`

   c. **Merge per chunk** the same way `code-audit` merges (dedupe by
      `path:line`, attach overlapping reasoning).

   **Wave semantics.** Cap concurrency at **3–4 chunks per wave**
   (one wave = `(1 triage + N specialists) × 3–4 chunks` running
   concurrently). Wait for **every** chunk in the current wave to
   return before starting the next wave. Streaming-style replacement
   ("queue the next chunk as soon as one finishes") is not allowed —
   it makes per-wave error handling and progress reporting unreliable.

3. **Synthesize across chunks.** After all chunk reports return:
   - **Deduplicate** — multiple chunks may flag the same cross-cutting
     issue (e.g. a shared utility used in different chunks).
   - **Resolve conflicts** — if reviewers disagree, investigate which
     is correct.
   - **Verify high-risk recommendations** yourself (schema changes,
     import changes, defensive guards).
   - **Categorize and prioritize** — correctness bugs > security >
     architecture > duplication > dead code > readability.

   Produce a consolidated report.

4. **Human approval gate.** Present the consolidated report. Explain
   total findings by category, questionable items, and cross-cutting
   themes. **Stop and wait for explicit approval.** Never auto-apply
   review findings.

5. **Implement in small batches.** After receiving approval, group
   approved items by file proximity (not by original chunk).
   Implement in batches of max 5–8 files. Run the check command after
   each batch. Fix any issues before starting the next batch.

## Rules

- The synthesis phase is non-negotiable — it catches what individual
  chunk reviews miss.
- Human approval is non-negotiable — never auto-apply findings.
- Small implementation batches are non-negotiable — monolithic
  implementation crashes or introduces cascading errors.
- Specialists run as `audit-*` subagents with their built-in
  anti-bias contract. Do NOT paste the goal, PR description, or
  branch name into specialist user prompts; only the chunk's diff
  slices, standards, and one-line chunk context.
- Feed lessons back into `.agents/common-mistakes/` after every
  review.
- **Big-output discipline.** Heavy command output (project check,
  full `git diff`, repo-wide search, long log, large fetch) goes to
  `/tmp/hawk-review-large-pr-<step>.log`, then
  `rg -n '<pattern>' /tmp/hawk-review-large-pr-<step>.log | head -50`
  extracts what you need. `Read` the file only with `offset`/`limit`.
  30+ file diffs are the worst offender for context bloat — this
  skill is the strictest enforcer: never capture or read the
  concatenated multi-file diff. Specialist user prompts receive
  narrowed slices only.
