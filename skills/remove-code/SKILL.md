---
name: remove-code
description: Remove a feature, delete dead code, drop a dependency, or simplify an abstraction. Use when the user wants to delete or clean up code.
---

# Remove Code

## Process

1. **Understand the capability to remove** (not just files): What user-facing or internal capability is being removed?

2. **Trace dependencies** before deleting anything:
   - All references to the functionality across the codebase
   - Code that ONLY exists to support this feature (can be fully deleted)
   - Code that is SHARED with other features (must be preserved)
   - Database migrations, config entries, env vars, feature flags, documentation that reference it

3. **Present the trace**: List everything to delete and everything to modify, grouped by file. Wait for user review.

4. **Execute deletion**:
   - Fully dead files: delete
   - Partially dead files: remove only dead parts
   - Update imports, exports, index files
   - Remove or update related tests

5. **Verify**:
   - Run the project's check command
   - Grep for remaining references to removed code (function names, class names, route paths, config keys) — there are always stragglers

## Rules

- Describe the CAPABILITY being removed, not files — this finds things you forgot about
- Always verify with a full check run after deletion
- Do deletion in its own PR, separate from any new feature work
- Check `.agents/common-mistakes/` for any removal-specific patterns before executing
