---
name: plan-large
description: Plan a multi-PR feature, migration, or architectural change before writing code. Writes a `.plans/<slug>/` directory of HTML documents (with inline UI mockups and a review-tracking layer) — a 1-page `overview.html` for human review, a mandatory `data-model.html` that locks the schema before anything else, a terse `plan.html` of dependency-ordered increments, an ADR-style `decisions.html`, and a `verification.html` acceptance script. Use whenever the user says "plan this feature", "scope out the migration", "/plan-large", "architect this rollout", "I need a plan covering schema and API", "design this across multiple PRs", or "break this work up". Also use whenever the work touches a database migration, even if it's only two PRs — schema-first is the gate. Runs a blind self-review subagent before presenting. Do NOT use for single-PR changes — bail to `plan-small` at Step 0. Do NOT use to start implementing — that's `/implement-plan` after the plan is approved.
---

# Plan a Large Feature

A large plan is a DAG of increments, each `plan-small`-sized. Output is a `.plans/<slug>/` directory of **HTML** documents (canonical format — they render with mockups and review-tracking through the shared design system at `.plans/_assets/`). Each file has a specialised job:

- `overview.html` — one page; what a human reviewer reads first.
- `data-model.html` — schema, migrations, rollback. Mandatory when persistence is touched.
- `plan.html` — tight increment list with explicit dependencies and acceptance checks; machine fields ride on `data-*` attributes (see `references/contract.md`).
- `decisions.html` — ADR-lite log of architectural decisions and assumptions.
- `verification.html` — end-to-end acceptance scenarios a human runs.
- `contracts.html` — optional; only when the feature exposes new or changed APIs.

A reviewer asking "is the schema right?" opens `data-model.html` and is done in 30 seconds. That's the point of the split. HTML is canonical because plans embed UI mockups inline and carry a lightweight review-tracking layer; the document contract that keeps them machine-readable for `/implement-plan` lives in `references/contract.md`.

## Process

### Step 0 — Right-size

If the answer to **all four** of these is "no", hand off to `plan-small` and stop:

- Requires a database migration?
- Ships as more than one PR?
- Has sequenced dependencies between increments?
- Has architectural surface a future engineer needs to understand without reading the diff?

If at least two are "yes", continue.

### Step 1 — Gather the design

Extract the minimum viable inputs:

- The problem and for whom.
- The leaning approach.
- Constraints (stack, timeline, team, deploy story).
- **Data-model intuition** — entities, relationships, where data already lives. Highest-leverage input; don't skim.
- Known open questions.

For initial codebase investigation, dispatch up to 3 `Explore` subagents in parallel (existing patterns, related components, testing patterns). Each Explore brief includes the big-output discipline rule and writes captures to `/tmp/hawk-plan-large-explore-<n>.log`, returning only narrowed findings.

### Step 2 — Load context

- Standards from `.agents/standards/` (read `index.yml`, narrow long files with `rg`).
- Common-mistakes from `.agents/common-mistakes/`.
- Project check command.

### Step 3 — Question gate (three tracks, schema first)

One `AskUserQuestion` call, capped at **5 questions total**, drawing from three tracks. Order matters: schema first, because it constrains everything below.

**Track 1 — data model.** Ask the user; schema determines what's possible at every layer above. "Each user belongs to multiple teams, or exactly one?" "When a workflow is deleted, do historical runs cascade or stay?" "Is `customer_id` a UUID or the legacy bigint?"

**Track 2 — product / scope.** Ask the user. "Per-team or per-org metrics by default?" "Feature-flagged for internal users first, or straight to GA?" "What's MVP vs follow-up for v1?"

**Track 3 — code architecture.** Search code first. Promote to the user only what code can't resolve. "I'm planning a new `billing/` module rather than extending `payments/` — confirm or override." "Migration uses the existing `pgmigrate` setup — confirm or override."

**In-repo PRDs and design docs count as "code can answer" by analogy** — search `docs/` before asking Track 2 questions whose answer might already be written down.

Skip the call if there are no Track 1 questions and architectural assumptions are trivial.

### Step 4 — Adversarial pre-write pass

Stress-test the design before writing anything:

- Top 3 risks or failure modes.
- One alternative architecture worth considering, and its strongest argument.
- Gaps: migration, backwards compat, observability, rollback, backfill, feature flag, telemetry.
- What to prototype first to de-risk the rest.

Alternatives don't land in the plan; the chosen approach's rationale and accepted risks do (in `decisions.html`).

### Step 5 — Lock the data model

Write `data-model.html` before drawing the increment DAG. If the feature touches persistence at all, this file is mandatory. Stub unused sections as "N/A — <one-sentence reason>" rather than omitting them — writing "N/A" forces the decision instead of leaving it forgotten. The reviewer rejects "N/A" on constraints or query patterns; those sections must be concrete.

Required sections (full template at `references/templates/data-model.html`):

1. **Entities & relationships** — Mermaid ER or DDL. Pick one and commit.
2. **Constraints & indexes** — uniqueness, FKs, NOT NULL, check constraints, indexes.
3. **Query patterns** — 3–5 specific reads/writes. If you can't list them, the schema isn't ready.
4. **Sample rows** — one realistic row per table.
5. **Migration plan** — ordered DDL, online vs offline, lock implications, expected duration.
6. **Backwards-compat window** — dual-write? view shim? rollback path *during* migration?
7. **Backfill** — required? batched? idempotent? ordering? duration?
8. **Rollback** — undo at each migration step.

If Step 6 reveals a schema gap, return here and update — `data-model.html` is canonical for schema decisions throughout.

### Step 6 — Decompose into ordered increments

Each increment must:

- Be a single PR that passes CI independently.
- Move the feature measurably forward.
- Have explicit dependencies and what it unblocks.
- Have an observable done criterion (a command, query, or visible behaviour — not "the code is correct").
- Be estimated S / M / L.

No file-by-file specs unless the increment introduces genuinely novel architecture. For 9 of 10 increments, the implementer in a fresh session needs only: dependencies, file list, and a testable done check. They open the actual code for signatures.

For the rare increment that does need a deep spec (new module structure, non-obvious integration, novel error model), drop the detail in a sibling `inc-<N>-notes.md` and reference it from the increment block. Keeps `plan.html` scannable.

### Step 7 — Write the files

Slug: kebab-case, ≤ 4 words. If `.plans/<slug>/` exists, append `-2`, `-3`.

**Bootstrap the shared assets first.** If `.plans/_assets/` does not exist, copy
`plan.css`, `mockup.css`, `plan.js`, and `serve.js` from this skill's
`references/assets/` into `.plans/_assets/`. If it exists, leave it untouched —
the user may have tweaked the styles.

HTML templates live at `references/templates/`:

- `overview.html` — ≤ 1 page (~500 words).
- `plan.html` — one `<section class="increment">` per increment, ≤ 10 lines of prose each.
- `data-model.html` — eight sections from Step 5.
- `decisions.html` — ADR-lite plus sourced assumption log.
- `verification.html` — GIVEN/WHEN/THEN or EARS acceptance scenarios.
- `contracts.html` — only if APIs change.

Copy each template to `.plans/<slug>/<name>.html` and fill it. Authoring rules,
all in `references/contract.md`:

- Keep every `data-section-id`; give each increment its required `data-*`
  attributes (`data-inc`, `data-size`, `data-depends`, `data-files`, `data-done`)
  — comma-lists with no surrounding whitespace.
- **HTML-encode all filled content** — `&`→`&amp;`, `<`→`&lt;`, `>`→`&gt;`, and
  `"`→`&quot;` inside attributes. Code artifacts (`Promise<User>`, `x <> y`) and
  user text break the markup or open an XSS hole otherwise. Bare `<word>` tokens
  in placeholders are grammar docs, never literal output. See `references/contract.md`.
- **Mockups:** draw a `.mock-*` wireframe (vocabulary in `assets/mockup.css`)
  **only for an increment that renders or changes UI**. Backend / schema / CLI
  increments get no mockup — a wireframe of nothing is noise.
- Don't inline `<style>`; all styling comes from the shared assets.
- EARS and GIVEN/WHEN/THEN are required for done criteria — both grammars
  disqualify weasel words by leaving nowhere to put them.

### Step 8 — Self-review

Call `plan-reviewer` with `Posture: plan-large`. The agent owns the dimensions (eight standard plus plan-large extensions: schema completeness, DAG correctness, per-increment observability, noise budget, review experience).

```
Agent(subagent_type="plan-reviewer", prompt=<USER PROMPT>)
```

Where `<USER PROMPT>` is:

```
## Posture
plan-large

## Plan files (reviewer view — HTML, mockups elided)
### overview.html
{{full content}}

### data-model.html
{{full content}}

### plan.html
{{full content}}

### decisions.html
{{full content}}

### verification.html
{{full content}}

### contracts.html (if present)
{{full content}}

## Standards
{{full content of relevant .agents/standards/ files, narrowed via rg if long}}

## Common mistakes
{{full content of relevant .agents/common-mistakes/ files}}
```

The reviewer is blind to `.plans/` — paste contents inline. Paste the **reviewer
view**: keep all prose, headings, and `data-*` attributes verbatim, but replace
each `<div class="mock-*">…</div>` subtree with a one-line placeholder comment
(`<!-- mockup: <description> -->`). Mockup markup is token-heavy and the reviewer
critiques content, not pixels (see `references/contract.md`).

### Step 9 — Apply findings

Apply MUST-FIX directly. Apply SHOULD-FIX unless it conflicts with a Step 3 decision (downgrade to CONSIDER and flag). Append CONSIDER items to the `open-questions` section of `decisions.html`.

If any MUST-FIX changes the DAG, update **both** `plan.html` and the DAG block in `overview.html` — they must stay consistent. Edit them as a pair, not sequentially with a check-in between.

### Step 10 — Present

Print, in order:

- The plan directory path.
- The text of `overview.html`'s `what-why` and `dag` sections, read back from the file (canonical).
- A one-line pointer to each other file with what it contains.
- The CONSIDER items appended in Step 9.

Do not start implementing. Suggest `/implement-plan` (or `/implement-plan-audited mode=auto` for hours-long unattended runs).

### Step 11 — Serve and open (always the last thing)

The final action, every run: launch the tracker, which auto-picks a free port and opens the plan in the browser itself. One command, as a **persistent background process** (it must keep serving after the command returns):

```
node .plans/_assets/serve.js --open "<slug>/overview.html" > /tmp/hawk-plan-serve.log 2>&1 &
```

`serve.js` prefers port 7777 and falls back to the next free port if it's taken (so two repos never collide), then opens `<slug>/overview.html` (the reviewer's entry point) via the OS opener (`xdg-open` / `open` / `start`). It prints the chosen URL as a `PLAN_SERVER_URL=…` line in the log — surface that to the user in case no browser opener is available.

## Failure modes

- **`data-model.html` becomes "N/A" all the way down.** That's the lazy-patch case. If a feature touches persistence at all, entities, constraints, query patterns, and migration must be concrete. "N/A" on rollback or backfill is sometimes legitimate; "N/A" on constraints or query patterns is the model dodging — the reviewer will catch it as MUST-FIX.
- **`plan.html` DAG and `overview.html` DAG drift.** This will happen after Step 9 if you edit them sequentially. Always edit as a pair. The reviewer's DAG-correctness check spots drift but only if it spots it.
- **A reviewer pass keeps changing the DAG.** Stop and surface the conflict to the user — usually a Step 3 schema decision and a Step 6 increment ordering are incompatible. Re-running review won't resolve it.
- **An increment grows past 10 lines.** Either split it or create a sibling `inc-<N>-notes.md` — never inline a deep spec into `plan.html`.
- **Step 6 reveals a schema gap.** Return to Step 5 and update `data-model.html` before continuing. Don't paper over it in the increment block; the gap will surface again at implementation time when it's more expensive.
- **The orchestrator says "I'll come back to this section" and writes a stub.** Stubs in plan files survive review because they look like template scaffolding. Either fill it or delete the section.

## Big-output discipline

Heavy command output goes to `/tmp/hawk-plan-large-<step>.log`; extract with `rg -n '<pattern>' /tmp/hawk-plan-large-<step>.log | head -50`. `Read` with `offset`/`limit`. Explore briefs and the reviewer prompt include this rule verbatim; long standards files are narrowed via `rg` before pasting.
