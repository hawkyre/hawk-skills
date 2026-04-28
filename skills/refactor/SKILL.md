---
name: refactor
description: Refactor existing code without changing behavior. Use when the user wants to improve readability, modularity, performance, type safety, or reduce duplication.
---

# Refactor Code

## Process

1. **Confirm the constraint** (ask if not provided):
   - Invariant: what must NOT change (behavior, API, tests passing)
   - Dimension (pick ONE):
     - Readability (clearer naming, simpler control flow)
     - Modularity (break apart, extract, separate concerns)
     - Performance (reduce allocations, optimize hot paths)
     - Type safety (tighten types, eliminate `any`, add guards)
     - Deduplication (consolidate repeated patterns)
   - Context: why this refactor, what pain it solves

   Always pick ONE dimension. Multi-axis refactors produce unreadable diffs and are impossible to review.

2. **Load context**:
   - Read relevant standards from `.agents/standards/`
   - Read relevant common-mistakes from `.agents/common-mistakes/`

3. **Outline the plan**:
   - Specific transformations to apply
   - Order (each step leaves the check command passing)
   - What the code will look like after (brief description, not full code)
   - Risks or tricky parts

4. **Execute incrementally**: One step at a time. Confirm tests pass between steps. If something breaks, roll back one step, not the whole refactor.

5. **Verify the invariant**:
   - Run the project's check command
   - Diff the public API/interface — confirm nothing changed externally
   - List any behavioral differences (there should be zero)

## Rules

- ALWAYS constrain to ONE dimension. Multi-axis refactors produce unreadable diffs.
- Each step must leave tests passing
- A refactor diff should be "boring" — moves, renames, restructures. No logic changes.
- If you discover a bug during refactoring, note it for a separate fix PR. Never mix refactoring and bug fixes.
- Check `.agents/common-mistakes/` for relevant patterns before and after
