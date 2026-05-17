# {{Title}}

## Summary

One paragraph: problem, approach, what ships. A reviewer should be able
to read just this section and know whether to dig in.

## Data model changes

(Include this section only when the PR touches persistence. Omit
entirely otherwise. Every bullet is mandatory when the section is
present — "N/A — <reason>" is allowed, omission is not.)

- **Change:** <DDL or one-sentence description>
- **Migration:** <online with existing tooling / offline / N/A>
- **Constraints/indexes affected:** <list, or "none">
- **Query patterns affected:** <reads/writes whose plan changes>
- **Backwards compat:** <how old code keeps working during deploy>
- **Backfill:** <required? batched? estimated rows> or "N/A — <reason>"
- **Rollback:** <one-line undo path>

## Files to touch

### path/to/file.ext

<One to three sentences describing what changes and why. For genuinely
novel files (new module, new API surface, novel error model), add key
signatures or shapes inline — only when they're load-bearing. Otherwise
trust the implementer to read the code.>

### path/to/other.ext

<…>

## Edge cases

- <case>: <expected behaviour>
- …

## Verification

- Run: <check command>
- Tests to add/update: <names + what they assert>
- Manual: <browser steps, API calls, etc.>
- Done when: WHEN <event> THEN <observable outcome>
  (or GIVEN/WHEN/THEN if setup matters)

## Decisions and assumptions

- Decision: <decision>. Source: code @ <file:line> | user-confirmed | default.
- Assumption: <assumption>. Source: …

## Standards / common-mistakes referenced

- <path> — why it applies

## Estimated scope

S | M | L

## Open questions (CONSIDER from review)

- … (filled by the self-review pass; empty initially)
