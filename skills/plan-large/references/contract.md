# HTML plan document contract

Canonical spec for the structure of HTML plan documents. **Authoring** skills
(`plan-small`, `plan-large`) emit documents that satisfy it; **executor** skills
(`implement-plan`, `implement-plan-audited`, `review-plan`) read it; `serve.js`
parses and validates it. If any of those disagree, this file wins.

## File layout

```
.plans/
├── _assets/                 # copied once per repo from this skill's references/assets/
│   ├── plan.css  mockup.css  plan.js  serve.js
└── <slug>/
    ├── plan.html            # plan-small: the whole plan in one doc
    │   ── OR ──             # plan-large: one doc per section:
    ├── overview.html  data-model.html  plan.html
    ├── decisions.html  verification.html  contracts.html
    ├── state.json           # operational state (review + increments) — NOT hand-authored
    └── worklog.md           # executor's append-only journal — NOT hand-authored
```

Every plan doc links the shared assets by **relative** path:

```html
<link rel="stylesheet" href="../_assets/plan.css">
<link rel="stylesheet" href="../_assets/mockup.css">
<script src="../_assets/plan.js" defer></script>
```

(The in-tree `references/examples/example-plan.html` links `../assets/` instead,
because it lives next to the source assets; runtime docs always use `../_assets/`.)

## Sections

Every reviewable unit is a section:

```html
<section class="plan-section" data-section-id="<unique-id>"> … </section>
```

- `data-section-id` is **unique within the plan** — across *all* HTML files in
  the `.plans/<slug>/` directory, not just one document (serve.js dedupes the
  whole slug and returns 422 on a cross-file collision). It is the stable key the
  tracker hashes for NEW / MODIFIED / REVIEWED. Conventional ids: `summary`,
  `data-model`, `decisions`, `verification`, `inc-1`, `inc-2`, `decision-d3`.
- Do not reuse an id across a rename or across files — a new id reads as a
  brand-new section (correct); reusing an id silently inherits another section's
  review state.

## Increment sections

An increment is a section that also carries machine fields as `data-*`:

```html
<section class="plan-section increment" data-section-id="inc-3"
         data-inc="3" data-size="M" data-depends="1,2"
         data-files="api/widgets.ts,api/routes.ts"
         data-done="WHEN GET /widgets THEN 200 with a JSON list">
  <h3>Inc 3 — API layer <span class="badge badge--size">M</span></h3>
  …prose, dl, optional mockup…
</section>
```

| attribute      | format                                   | empty value |
| -------------- | ---------------------------------------- | ----------- |
| `data-inc`     | integer, unique in doc                   | required    |
| `data-size`    | `S` \| `M` \| `L`                        | required    |
| `data-depends` | comma-list of inc ids, no spaces         | `""` (none) |
| `data-files`   | comma-list of repo-relative paths, no spaces | required |
| `data-done`    | EARS / GIVEN-WHEN-THEN string            | required    |

Delimiter rule: comma, no surrounding whitespace. Paths and ids never contain a comma.

There is **no `data-audit-checkpoint` attribute** and **no outcome record** in
the HTML. Implementation state (status, attempts, audit checkpoints) lives in
`state.json` (executor-owned); narrative lives in `worklog.md`. The HTML doc is
hand-authored and human-owned — machines read its `data-*` but never write into it.

## HTML encoding (mandatory)

Plan docs are served to a browser by `serve.js`, and their content is derived
from user descriptions and code artifacts that routinely contain `<`, `>`, `"`,
and `&` (e.g. `Promise<User>`, `CHECK (name <> '')`, JSON with quotes). Unencoded,
these break out of attributes or open stray tags — malformed HTML at best, stored
XSS in the local viewer at worst. So, when filling any slot:

- **In element content** (including `<pre>` blocks): encode `&`→`&amp;`, `<`→`&lt;`,
  `>`→`&gt;`.
- **In attribute values** (`data-done`, `data-files`, `title`, …): additionally
  encode `"`→`&quot;`.
- Template placeholders that contain bare `<word>` tokens (e.g. `<event>`) are
  **grammar documentation only** — never copy the literal angle brackets into the
  output; write the real value, encoded.

`serve.js` also sets a strict `Content-Security-Policy` and `X-Content-Type-Options:
nosniff`, and encodes any `state.json` value it reflects into served HTML — but
encoding at authoring time is the first line of defence, not the only one.

## Mockups

Draw UI with the `.mock-*` vocabulary (see `assets/mockup.css`) inside the
relevant section. Author a mockup **only for an increment that renders or
changes UI**; backend/schema/CLI increments get none. A mockup is a sketch of
intent, not a pixel spec.

## Reviewer view (what gets pasted into plan-reviewer)

The reviewer is blind to `.plans/` and critiques content, not pixels. When
pasting a doc into `plan-reviewer`, replace each `<div class="mock-*">…</div>`
subtree with a one-line placeholder comment
(`<!-- mockup: settings screen — sidebar + form + toast -->`) and keep all prose,
headings, and `data-*` attributes verbatim.

## The tracking server (serve.js)

Run `node .plans/_assets/serve.js [--port 7777]` (loopback-only, default port
7777). It validates and serves the `.plans/` directory.

**Validation** (HTTP 422 + the offending id): duplicate `data-section-id` (across
the whole slug), duplicate `data-inc`, a non-integer/negative `data-inc`, a
non-integer `data-depends` token, or an increment missing a required
`data-size` / `data-files` / `data-done`.

**HTTP API:**

- `GET /api/state/<slug>` → `{ schemaVersion, slug, sections: { <id>: { status:
  "new"|"modified"|"reviewed", currentHash, reviewedHash } }, increments, incrementOrder }`.
- `GET /api/plan/<slug>` → `{ slug, increments: [{ id, size, depends[], files[], done }] }`
  — the increment DAG parsed from `data-*`, the parser-of-record executors
  cross-check their own text extraction against.
- `POST /api/review/<slug>` body `{ sectionId }` or `{ all: true }` → marks
  section(s) reviewed; writes `review.*` under the lock; returns `{ reviewed, count }`.

**state.json schema (`v1`):**

```
{ schemaVersion: 1, slug,
  review:     { <sectionId>: { reviewedHash, reviewedAt } },   // SERVER-owned
  increments: { <incId>:     { status, attempts, evidence, files[],
                               auditCheckpoint, planOverride?, updatedAt } } }  // EXECUTOR-owned
```

`review.*` is written only by serve.js; `increments.*` only by the executor
skills. Both do a full read-modify-write under `state.json.lock`, touching only
their own subtree. `currentHash` is never stored — serve.js recomputes it per
request (sha256 of the section's normalized text, first 12 hex).
