---
name: fix-bug
description: Fix a bug via hypothesis-first root cause analysis. Generates ranked hypotheses BEFORE reading code; always considers online research at the hypothesis stage. Three-branch hypothesis revision (disconfirmed → next; new evidence → rewind; all exhausted → escalate). Requires a failing reproduction test before the fix and evidence-on-disk that it passes after. Layered retry ladder when checks fail — Stage 3 explicitly considers that the fix itself was wrong and reverts. Lazy patches (swallow-the-exception, mask-the-symptom, comment-instead-of-fix) are rejected. Design-level bugs route through plan skills. Use when the user reports a symptom and needs the cause found and fixed.
---

# Fix a Bug

## Process

### Step 1 — Collect the symptom

Ensure you have:

- Observed behaviour vs expected behaviour.
- Environment / version info (runtime, OS, library versions).
- Logs, stack traces, or error messages — verbatim.
- Reproduction steps if available. If reproduction is not available, ask the user for them, or note explicitly that this is a non-reproducible bug — Step 5 has a heisenbug branch.

### Step 2 — Generate hypotheses BEFORE looking at code

- 5 ranked hypotheses for the root cause.
- For each: what would cause this symptom, likelihood (high/medium/low), and what evidence would confirm or disconfirm.
- Do NOT read code yet — reason from the symptom first. Reading code before forming hypotheses anchors you on the wrong cause.

### Step 3 — Online research (always considered, applied when triggered)

At the hypothesis stage, **always pause and ask whether online research applies to this bug**. Apply it when **any** of these heuristics matches:

- The error originates inside `node_modules/`, `vendor/`, `deps/`, a stdlib path, or any third-party package.
- The error message contains a framework- or library-specific string (e.g. "ECONNRESET in undici", "Postgrex.Error", "Prisma P2002", "Next.js dynamic = 'force-dynamic'", "React hydration mismatch").
- The bug involves a library/API the codebase has used <3 times — the team has not built up enough internal knowledge yet.
- Behaviour depends on a specific library version, runtime version, Node/Bun/Erlang/Python version, OS, or platform.
- The bug looks like "this should work according to the docs."
- The fix candidate would silence a warning rather than address it — there's a non-zero chance the warning means something specific.
- The user is on a recent version of a fast-moving library; check the changelog for breaking changes.

When triggered, use:

- `WebSearch` to find similar issues, GitHub issues, Stack Overflow posts, and "library + error message" results. Read 2–3 of the most relevant results.
- `WebFetch` to pull the actual doc page, GitHub issue, or changelog entry. Don't trust summaries; read the source.

Fold findings back into the hypothesis list:

- If research confirms a hypothesis → upgrade its rank, note the source (URL + brief).
- If research adds a new hypothesis (e.g. a known bug in version X) → add it to the list with the source.
- If research disconfirms a hypothesis → demote or remove it.

If none of the heuristics match, skip online research and go to Step 4. The skill **always considers** research; it does not always perform it.

### Step 4 — Investigate top hypothesis

Read the relevant code. Compare evidence against the hypothesis. Three branches:

- **Hypothesis cleanly disconfirmed** (evidence contradicts it) → move to the next hypothesis on the list.
- **New evidence emerges that doesn't fit any hypothesis on the list** → **rewind to Step 2.** Regenerate the hypothesis list with the new evidence in hand. Do not muddle through with a list you've already invalidated; new evidence means new hypotheses.
- **All 5 hypotheses exhausted** → **stop and escalate to the user.** Do not invent a 6th hypothesis from thin air — that's where invented bugs come from. Surface what you tried, what was disconfirmed, and ask the user to weigh in.

If still ambiguous within a hypothesis, add a targeted log/print or run a focused test before continuing. For large search spaces, dispatch an `Explore` subagent to keep main context focused on the fix.

### Step 5 — Implement the minimal fix

#### 5a. Reproduction test first

Write a test that reproduces the bug. Run it and capture the **failing** run:

```bash
<test-cmd for the new test> > /tmp/hawk-fix-bug-repro-pre.log 2>&1
```

If the test doesn't fail pre-fix, you haven't actually reproduced the bug — return to Step 4 before proceeding. A "fix" without a failing reproduction is a guess.

#### 5b. Heisenbugs — when reproduction is genuinely infeasible

If reproduction is genuinely infeasible after reasonable effort (race conditions, environmental dependencies, load-only failures), **stop and surface this to the user before attempting a fix.** A fix without a reproduction is shipping a guess; the user must consciously agree to that trade-off. The typical right next step is to add instrumentation/logging that will catch the bug in the wild on the next occurrence — not blind-fixing.

#### 5c. Implement the fix — minimal, and not lazy

No refactoring, no cleanup, no unrelated improvements. Address the root cause identified in Step 4, not the symptom in Step 1.

**Reject the lazy patch.** A fix that silences the symptom without addressing the cause is worse than no fix — it makes the underlying issue invisible to the next developer. The following are lazy patches; if your candidate fix matches any of them, **revert and treat the bug as design-level (5g):**

- Wrapping the failing call in try/catch and swallowing the error.
- Adding an early return that hides bad state from later code.
- Tightening a check to mask the symptom instead of fixing the upstream cause.
- Adding a comment that explains the bug instead of fixing it.
- Catching an exception just to log it when the right behaviour is to propagate or handle.
- Renaming a variable or restructuring whitespace in lieu of fixing the logic.

#### 5d. Verify the test passes

Run the reproduction test again. It must now pass. Capture:

```bash
<test-cmd for the new test> > /tmp/hawk-fix-bug-repro-post.log 2>&1
```

Claiming "fixed" without the post-fix passing log on disk is not allowed. The two files (`-pre.log` failing, `-post.log` passing) are the evidence the fix did what it claims. Self-asserted "I verified it" is the canonical hallucination pattern; evidence on disk is not.

#### 5e. Bugs travel in packs

Grep for the bug fingerprint across the repo:

```bash
rg -n '<fingerprint>' . > /tmp/hawk-fix-bug-pattern.log 2>&1
rg -n '<narrower pattern>' /tmp/hawk-fix-bug-pattern.log | head -50
```

Fix sibling instances in the same PR if they're small and localized. Surface them as a follow-up issue if broader (likely design-level — see 5g).

#### 5f. Full check command — with the layered retry ladder

Run the project's full check command (full test suite, type-check, lint — not a partial scope). Regression-check is the whole suite; a bug fix that introduces a regression elsewhere is worse than the original bug.

```bash
<check-cmd> > /tmp/hawk-fix-bug-check.log 2>&1
rg -n 'error|warning|fail|FAIL' /tmp/hawk-fix-bug-check.log | head -50
```

If the check fails, escalate through the layered ladder (matches `implement-plan` Step 3.5):

- **Stage 1 (Level 0 retry):** Re-run; transient failures clear.
- **Stage 2 (Level 0 fix):** Fix the immediate breakage caused by the fix.
- **Stage 3 (Level 1 reconsider):** **The fix may be wrong.** Revert it and return to Step 4 with the next hypothesis on the list. A previously-passing test newly failing after your fix is a strong signal the fix is wrong, not that the unrelated test is wrong. This stage is the bug-fix-specific safety valve — a "fix" that breaks unrelated tests almost always means you fixed the wrong thing.
- **Stage 4 (Level 3 escalate):** Stop. Surface what was tried, which hypotheses were ruled out, and the current failure state.

#### 5g. Design-level bugs — route through plan skills

If the investigation reveals that the bug's root cause is structural — the design is wrong, not a specific line — the minimal-fix posture is the wrong tool. The lazy-patch list above triggers this; so does a hypothesis revealing that the bug class will recur in different shapes until the underlying design changes.

Stop the minimal-fix path and route the work to a plan:

- Localized redesign within one PR → invoke `/plan-small "fix <bug>: <approach>"`.
- Spans modules or PRs → invoke `/plan-large "redesign <area> to address <bug class>"`.

Surface the design concern to the user with a one-line summary; let them decide whether to invoke the plan skill now, or ship a minimal patch and follow up with the plan separately. Both are valid; the worst move is silently shipping a band-aid without flagging the design concern.

### Step 6 — Update common-mistakes if applicable

If the bug pattern is novel for this codebase, add an entry to `.agents/common-mistakes/` so the next implementer doesn't recreate it. Include the symptom, the cause, and the fix.

If online research was load-bearing for the fix, capture the URL + brief in the common-mistake entry. Future you will not remember which Stack Overflow answer it was.

## Committing the fix

If a commit is being made, delegate to `implement-plan` Step 3.5 in full — stop-out edge cases (mid-rebase / mid-merge / unresolved conflicts), discovery-based staging, repo style mirroring via `git log -10 --oneline`, no `--amend`, no `--no-verify`, and **no AI attribution ever** (no `Co-Authored-By: Claude`, no `🤖`, no "Generated with Claude" line).

The reproduction test goes in the **same commit** as the fix — they're one logical change, and you want future bisects to see the test arriving with the code it covers.

## Rules

- **NEVER skip the hypothesis step** — it prevents anchoring on the wrong cause.
- **ALWAYS consider online research at Step 3.** Apply when the heuristics match. Skipping research on a third-party-library bug is a recipe for hours of wrong-direction work.
- **Hypothesis revision is structured.** Clean disconfirmation → next hypothesis. New evidence → rewind to Step 2. All 5 exhausted → escalate to the user; do not invent a 6th.
- **The reproduction test must fail before the fix.** No reproduction = you don't understand the bug. For heisenbugs, surface non-reproducibility to the user before proceeding.
- **Evidence on disk, not memory.** The `-pre.log` failing run and the `-post.log` passing run are both required to claim "fixed." Self-asserted verification is rejected.
- **The fix is minimal** — no refactoring, no cleanup, no unrelated improvements. Design-level bugs route through plan skills instead.
- **Reject the lazy patch.** A fix that silences the symptom without addressing the cause is worse than no fix. The enumerated patterns in 5c are not negotiable; matching any of them sends the bug to 5g.
- **Bugs travel in packs** — check for the same pattern elsewhere with `rg`.
- **If the fix is a one-liner, be suspicious.** A one-liner that fixes a hard-to-reproduce symptom often masks a deeper design issue. Surface the design concern even if you ship the one-liner.
- **Layered retry ladder, not 3-attempt retry.** Stage 3 explicitly considers reverting the fix and returning to Step 4 — a fix that breaks unrelated tests is usually wrong.
- **Full check command, not partial.** Regression-check is the whole suite, type-check, lint.
- **Commit hygiene delegates to `implement-plan` Step 3.5.** No AI attribution. No `--no-verify`. Stop-out cases honored. Reproduction test commits with the fix.
- After fixing, check `.agents/common-mistakes/` — if this bug pattern is new, add it (with research links if used).
- **Big-output discipline.** Heavy command output (project check, full `git diff`, repo-wide search, long log, large fetch) goes to `/tmp/hawk-fix-bug-<step>.log`, then `rg -n '<pattern>' /tmp/hawk-fix-bug-<step>.log | head -50` extracts what you need. `Read` the file only with `offset`/`limit`. See README → Big-output discipline.
