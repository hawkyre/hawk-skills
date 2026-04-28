---
name: fix-bug
description: Fix a bug via hypothesis-first root cause analysis. Always considers online research at the hypothesis stage; uses WebSearch/WebFetch when heuristics indicate the root cause is likely outside the codebase (third-party library, framework quirk, version-specific behavior). Use when the user reports a symptom and needs the cause found and fixed.
---

# Fix a Bug

## Process

### Step 1 — Collect the symptom

Ensure you have:
- Observed behavior vs expected behavior.
- Environment / version info (runtime, OS, library versions).
- Logs, stack traces, or error messages — verbatim.
- Reproduction steps if available.

### Step 2 — Generate hypotheses BEFORE looking at code

- 5 ranked hypotheses for the root cause.
- For each: what would cause this symptom, likelihood
  (high/medium/low), and what evidence would confirm or disconfirm.
- Do NOT read code yet — reason from the symptom first. Reading code
  before forming hypotheses anchors you on the wrong cause.

### Step 3 — Online research (always considered, applied when triggered)

At the hypothesis stage, **always pause and ask whether online
research applies to this bug**. Apply it when **any** of these
heuristics matches:

- The error originates inside `node_modules/`, `vendor/`,
  `deps/`, a stdlib path, or any third-party package.
- The error message contains a framework- or library-specific string
  (e.g. "ECONNRESET in undici", "Postgrex.Error", "Prisma P2002",
  "Next.js dynamic = 'force-dynamic'", "React hydration mismatch").
- The bug involves a library/API the codebase has used <3 times — the
  team has not built up enough internal knowledge yet.
- Behavior depends on a specific library version, runtime version,
  Node/Bun/Erlang/Python version, OS, or platform.
- The bug looks like "this should work according to the docs."
- The fix candidate would silence a warning rather than address it —
  there's a non-zero chance the warning means something specific.
- The user is on a recent version of a fast-moving library; check the
  changelog for breaking changes.

When triggered, use:

- `WebSearch` to find similar issues, GitHub issues, Stack Overflow
  posts, and "library + error message" results. Read 2–3 of the most
  relevant results.
- `WebFetch` to pull the actual doc page, GitHub issue, or changelog
  entry. Don't trust summaries; read the source.

Fold findings back into the hypothesis list:
- If research confirms a hypothesis → upgrade its rank, note the
  source (URL + brief).
- If research adds a new hypothesis (e.g. a known bug in version X)
  → add it to the list with the source.
- If research disconfirms a hypothesis → demote or remove it.

If none of the heuristics match, skip online research and go straight
to Step 4. The skill **always considers** research; it does not
always perform it.

### Step 4 — Investigate top hypothesis

- Read the relevant code.
- Does the evidence support or contradict the hypothesis?
- If contradicted, move to the next hypothesis.
- If still ambiguous, add a targeted log/print or run a focused test
  before continuing.

For large search spaces, dispatch an `Explore` subagent to keep main
context focused on the fix.

### Step 5 — Implement the minimal fix

- Write a test that reproduces the bug (must fail before the fix).
- Implement the minimal fix — no refactoring, no cleanup, no
  unrelated improvements.
- Verify the test passes.
- **Check for the same bug pattern elsewhere** — bugs travel in
  packs. Grep for the fingerprint of the bug across the repo.
- Run the project's check command.

### Step 6 — Update common-mistakes if applicable

If the bug pattern is novel for this codebase, add an entry to
`.agents/common-mistakes/` so the next implementer doesn't recreate
it. Include the symptom, the cause, and the fix.

If online research was load-bearing for the fix, capture the URL +
brief in the common-mistake entry. Future you will not remember.

## Rules

- NEVER skip the hypothesis step — it prevents anchoring on the
  wrong cause.
- ALWAYS consider online research at Step 3. Apply when the
  heuristics match. Skipping research on a third-party-library bug
  is a recipe for hours of wrong-direction work.
- The fix is minimal — no refactoring, no cleanup, no unrelated
  improvements.
- Bugs travel in packs — check for the same pattern elsewhere.
- If the fix is a one-liner, be suspicious. A one-liner that fixes a
  hard-to-reproduce symptom often masks a deeper design issue.
  Surface the design concern even if you ship the one-liner.
- After fixing, check `.agents/common-mistakes/` — if this bug
  pattern is new, add it (with research links if used).
