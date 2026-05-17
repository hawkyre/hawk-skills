# Data model

(Mandatory when the feature touches persistence at all. Stub unused
sections as "N/A — <one-sentence reason>" rather than omitting them.
Writing "N/A" forces the decision; "N/A" on constraints or query
patterns will be rejected by the reviewer — those sections must be
concrete.)

## Entities & relationships

Pick one: a small Mermaid ER diagram OR actual DDL. Don't write prose.

## Constraints & indexes

- **Uniqueness:** …
- **Foreign keys:** …
- **NOT NULL:** …
- **Check constraints:** …
- **Indexes:** …

Most schema bugs from AI-generated code are missing constraints or
wrong indexes. Be explicit.

## Query patterns

List 3–5 specific reads/writes the feature needs. This justifies the
design and lets a reviewer say "you didn't index for X." If you can't
list them, the schema isn't ready.

- READ: …
- READ: …
- WRITE: …

## Sample rows

One realistic row per table. Makes ambiguity obvious.

- `table_a`: `{ id: ..., ... }`
- `table_b`: `{ ... }`

## Migration plan

Ordered DDL, online vs offline, expected lock implications, estimated
duration on production-scale data.

1. …
2. …

## Backwards-compatibility window

Dual-write? Read-then-write? View shim? What's the rollback path
*during* migration (not just after)?

## Backfill

Required? Batched? Idempotent? Ordering constraints? Estimated
duration on production-scale data? (Or "N/A — <reason>".)

## Rollback

What does undoing this look like at each migration step?
