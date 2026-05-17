# {{Title}}

## What & why

One paragraph: problem, approach, scope. A non-implementer should
finish this paragraph knowing whether to dig further.

## Increment DAG

- Inc 1 — Foundation (S) — depends on: none — unblocks: 2, 3
- Inc 2 — Schema (M) — depends on: 1 — unblocks: 4, 5
- Inc 3 — API (M) — depends on: 1 — unblocks: 5
- …

(Optional ASCII diagram if the DAG isn't linear.)

## Top 3 risks

- <risk, one sentence, with mitigation or "accept">
- <risk, one sentence, with mitigation or "accept">
- <risk, one sentence, with mitigation or "accept">

## Files

- [data-model.md](data-model.md) — schema & migrations
- [plan.md](plan.md) — increment list
- [decisions.md](decisions.md) — architectural choices
- [verification.md](verification.md) — acceptance scenarios
- (contracts.md if APIs change)
