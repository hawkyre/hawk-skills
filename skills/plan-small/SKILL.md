---
name: plan-small
description: Plan a single-PR change end-to-end before writing code. Writes a terse `.plans/<slug>/plan.html` (HTML, with inline UI mockups where a screen changes, rendered through the shared design system) covering files to touch, data-model changes, edge cases, verification, and decisions/assumptions sourced to code or user. Use whenever the user says "plan this", "scope this out", "write up a plan for X", "/plan-small", "let's plan the new flag", or "plan before we start". Also use whenever the user describes a small feature without explicitly asking to plan — propose a plan before coding. Asks only what code can't answer (in-repo PRDs count), surfaces planned assumptions alongside questions, then runs a blind self-review subagent before presenting. Do NOT use for multi-PR work, schema migrations beyond adding a nullable column, or sequenced increments — bail to `plan-large` at Step 0. Do NOT use to start implementing — that's `/implement-plan` after the plan is approved.
---

# Plan a Small Feature

Output: a terse `.plans/<slug>/plan.html` an implementer can execute in a fresh session and a reviewer can scan in one screen — HTML so a UI change can carry an inline mockup and the plan gets review-tracking through the shared `.plans/_assets/` design system. Soft length budget: ≤ 400 words of prose for a typical plan. If it blows that, the work is probably `plan-large`.

## Process

### Step 0 — Right-size

Bail to `plan-large` if any of these hold:

- Touches persistence beyond adding a nullable column.
- Touches more than ~5 files or crosses more than one architectural boundary (e.g. auth + billing).
- Has sequenced dependencies — must ship A before B can begin.
- Obviously won't fit one PR.

If the user explicitly invoked `plan-small`, trust them — but flag a triggered criterion in one line and hand off.

### Step 1 — Understand intent

Read the request. Identify WHAT, not HOW. Capture explicit and implicit requirements (scale, error tolerance, observability).

### Step 2 — Load context

- Relevant `.agents/standards/` (read `index.yml` first; narrow long files with `rg`).
- Relevant `.agents/common-mistakes/` (read `index.yml` first).
- The project check command (look it up — don't assume).

### Step 3 — Question gate (two tracks)

Generate the top 3–6 questions whose answers will shape the plan, then sort into two tracks.

**Track A — product / feature-design.** Ask the user. These are questions only they can answer: MVP scope, real-time vs batch, in-app vs email, which user segment, what counts as success, acceptable failure modes. Default to asking unless the request already pins them down.

**Track B — code architecture.** Search code first. Look for existing functions/helpers, config files, schemas, types, migrations, neighbouring-feature patterns. **In-repo PRDs and design docs count as "code can answer" by analogy** — search `docs/`, `*.md` files near the relevant module, before promoting.

If code answers, record under `## Decisions and assumptions` as `Source: code @ <file:line>` and don't ask. If code is silent, promote to the user.

In **one** `AskUserQuestion` call, present:

- Track A questions plus any unanswered Track B questions.
- The core assumptions and decisions the skill is currently planning to take, each framed as a confirmable choice.

Example shapes:

- _(Track A — scope)_ "Export includes archived items, or only active?"
- _(Track A — assumption)_ "On send failure, I'm planning a toast vs silent retry vs blocking the form — confirm or override."
- _(Track B — assumption, code silent)_ "I'm planning to put the new endpoint at `/api/v1/widgets` — confirm or override."

If there are no Track A questions, no unanswered Track B questions, and no non-trivial assumptions, skip the call.

### Step 4 — Write the plan file

Slug: kebab-case from the request, ≤ 4 words. If `.plans/<slug>/` exists, append `-2`, `-3`. Plan path: `.plans/<slug>/plan.html`.

**Bootstrap assets first.** If `.plans/_assets/` does not exist, copy `plan.css`,
`mockup.css`, `plan.js`, and `serve.js` from this skill's `references/assets/`
into it. If it exists, leave it untouched.

Copy `references/plan-template.html` to `.plans/<slug>/plan.html` and fill it.
Section order is fixed — the `summary` section lands first so a reviewer hits the
elevator pitch before reference material. The full document contract (section
ids, asset links, mockup vocabulary) is `references/contract.md`.

Four template invariants:

- **The `data-model` section is mandatory when persistence is touched.** Even a single-column change deserves the seven-bullet treatment — writing "N/A — <reason>" for backfill is itself a decision. Omission is not. Delete the section entirely when no persistence is touched.
- **Per-file blocks are prose, not bullet lists.** The implementer reads the code for signatures. Reserve inline detail for genuinely novel files (new module, new API surface, novel error model).
- **Mockups only for UI.** If the change renders or changes a screen, sketch it in the `files` section with the `.mock-*` vocabulary (`assets/mockup.css`). No UI change → no mockup.
- **HTML-encode all filled content.** `&`→`&amp;`, `<`→`&lt;`, `>`→`&gt;` in element content; also `"`→`&quot;` in attributes. Code artifacts (`Promise<User>`, `x <> y`) break the markup or open an XSS hole otherwise. See `references/contract.md`.
- **"Done when" uses EARS or GIVEN/WHEN/THEN.** Both grammars disqualify weasel words by leaving nowhere to put them.

### Step 5 — Self-review

Call `plan-reviewer` with `Posture: plan-small`. The agent owns the dimensions (eight standard plus plan-small extensions: noise budget, source-checking, done-criteria observability, data-model section).

```
Agent(subagent_type="plan-reviewer", prompt=<USER PROMPT>)
```

Where `<USER PROMPT>` is:

```
## Posture
plan-small

## Plan content (reviewer view — HTML, mockups elided)
{{full content of .plans/<slug>/plan.html, with each <div class="mock-*">…</div>
replaced by a one-line <!-- mockup: <description> --> placeholder}}

## Standards
{{full content of relevant .agents/standards/ files, narrowed via rg if long}}

## Common mistakes
{{full content of relevant .agents/common-mistakes/ files}}
```

The reviewer is blind to `.plans/` — paste content inline.

### Step 6 — Apply findings

- Apply every **MUST-FIX** directly to the plan file.
- Apply every **SHOULD-FIX** directly. If a SHOULD-FIX conflicts with a Step 3 user-confirmed decision, downgrade to CONSIDER and flag to the user rather than overriding.
- Append every **CONSIDER** as a list item in the `open-questions` section of the plan file.

### Step 7 — Present

Print:

- The plan path.
- The text of the `summary` section, read back from the file (the file is canonical).
- The `data-model` section verbatim if present (schema decisions get front-of-presentation visibility).
- The decisions/assumptions list.
- The CONSIDER items appended in Step 6.
- The review-tracking hint: `node .plans/_assets/serve.js`, then open the printed URL.

Do not start implementing. The user decides when to invoke `/implement-plan` or `/implement-plan-audited`.

## Failure modes

- **The reviewer keeps finding MUST-FIX after two passes.** Stop applying patch-fix-patch. Surface the open MUST-FIX list to the user — the underlying disagreement is usually a Step 3 decision the plan went around.
- **Step 3 reveals the work is actually `plan-large`.** Don't keep writing — bail mid-Step. The sunk cost of a partial plan is small; a mis-sized plan compounds across implementation.
- **The plan says "the code is correct" or "handles errors gracefully" instead of an observable done-criterion.** This is the lazy-patch case. Replace with a runnable command, a query result, an HTTP response, or a UI state — never prose. The reviewer's done-criteria observability check will catch this; fix it before re-running rather than arguing.
- **Scope creeps mid-write.** If a new requirement surfaces in Step 4 that doesn't fit, split into a follow-up plan in `.plans/<slug>-followup/` rather than ballooning this one.
- **A schema decision conflicts with a user answer.** The user wins. Update the plan, record the override in `## Decisions and assumptions` with `Source: user-confirmed`, and re-run Step 5.

## Big-output discipline

Heavy command output goes to `/tmp/hawk-plan-small-<step>.log`; extract with `rg -n '<pattern>' /tmp/hawk-plan-small-<step>.log | head -50`. `Read` with `offset`/`limit`. Long standards files are narrowed via `rg` before pasting into the reviewer prompt.
