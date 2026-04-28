# hawk-skills

Opinionated [Claude Code](https://claude.com/claude-code) skills for shipping
real software with AI: planning, auditing, implementing, and fixing — built
around independent subagents that don't know what feature they're working on,
so they evaluate code on its own merits.

## What's in here

| Skill | What it does |
|-------|--------------|
| `coding-process` | Entry point. Reads the task, routes to the right skill below. |
| `plan-small` | Plan a one-PR change. Searches the code before asking questions, surfaces assumptions alongside questions, writes the plan to `.plans/<slug>/plan.md`, then runs an independent self-review subagent that improves the plan before showing it to you. |
| `plan-large` | Plan a multi-PR feature as an increment DAG. Same code-search-first question gate and self-review pass, plus explicit ordering/dependency review. |
| `review-plan` | Adversarial review of a plan file. |
| `implement-plan` | Execute an approved plan, increment by increment, with parallel subagents for independent increments. |
| `implement-plan-audited` | Execute a plan with five parallel audit specialists running after every increment. `mode=auto` runs end-to-end without stopping — designed for hours of unattended execution. Falls back to manual on repeated failure. |
| `code-audit` | Five parallel independent specialists (logic & edge cases, security, simplification, online research, architecture) that don't know what feature they're reviewing. Modes: `report`, `cleanup`. Light mode drops the research pass. |
| `code-audit-hardcore` | Whole-repo deep clean. Five specialists run in waves with explicit license to override repo conventions in favor of cleanliness/safety/simplicity. Auto-fixes small issues; routes large ones (>5 files, schema changes, public API changes) through `/plan-small` or `/plan-large`. |
| `fix-bug` | Hypothesis-first root cause analysis with explicit triggers for online research (third-party errors, library used <3 times, version-specific behavior, "should work per docs"). |
| `refactor` | Single-dimension refactors (readability, modularity, performance, type safety, dedup). |
| `remove-code` | Trace-then-delete for features, dead code, dropped dependencies. |
| `review-large-pr` | Chunked parallel review of 30+ file PRs. |
| `learn-system` | Explore and explain a system — entry points, mental model, traced scenarios. |
| `design-master` | Build a design system from first principles — color, typography, spacing, motion. |
| `init-phoenix` | Bootstrap a Docker-based Phoenix project with the BEAM/macOS gotchas pre-solved. |

## The core idea: blind, parallel, independent subagents

Most of the heavy skills here (`code-audit`, `code-audit-hardcore`,
`implement-plan-audited`, `plan-small`, `plan-large`) fan out to subagents that
work in parallel, with a deliberately narrow brief, and **no context on the
overall goal**. They don't read the plan. They don't know what feature this is.
They see only the code, the standards, and their specialist brief.

That blindness is the point: a reviewer who knows the goal will rationalize the
implementation toward the goal. A reviewer who only has the diff and a
specialist brief is forced to evaluate the code on its own merits.

The five `code-audit` specialists:

1. **Logic & edge cases** — off-by-one, null/NaN, empty inputs, concurrency,
   ordering, error paths, boundary values.
2. **Security** — input validation, authn/authz boundaries, injection, XSS,
   SSRF, prompt injection, trust boundaries.
3. **Simplification & readability** — long functions, deep nesting, dead code,
   duplication, names that don't match behavior.
4. **Online research** — verifies third-party API assumptions against current
   docs via WebSearch + WebFetch. Flags deprecated APIs and version-specific
   gotchas. (Cheapest pass to skip in light mode.)
5. **Architecture & conventions** — layer separation, file placement, import
   direction, type-safety regressions, public API stability.

## Install

```bash
git clone https://github.com/<you>/hawk-skills.git
cd hawk-skills
./install.sh                      # install every skill
./install.sh --dry-run            # show what would happen
./install.sh --only code-audit    # install one skill (repeatable)
```

The script copies each folder under `skills/` into `~/.claude/skills/`,
replacing any folder with the same name. Re-run after a `git pull` to refresh.

## Usage

Once installed, the skills are available in Claude Code:

```
/coding-process    # let it route
/plan-small        # one-PR change
/plan-large        # multi-PR feature
/code-audit        # review a diff
/code-audit-hardcore  # whole-repo deep clean
/implement-plan-audited mode=auto   # unattended execution
/fix-bug           # hypothesis-first bug fix
```

Each skill's full prompt is in `skills/<name>/SKILL.md` — read them, fork
them, change anything you don't like.

## Conventions these skills assume

- **`.plans/<slug>/plan.md`** — plan files. `plan-small` and `plan-large` write
  here; `implement-plan*` reads from here.
- **`.agents/standards/`** — your house conventions. Skills look up
  `index.yml` and read relevant files.
- **`.agents/common-mistakes/`** — repo-specific gotchas. Same lookup pattern.
- **Project check command** — skills look this up (e.g. `bun run c`,
  `pnpm typecheck`, `mix test`); they don't assume.

The `.agents/` and `.plans/` conventions are simple to bootstrap — `index.yml`
lists files by topic, the files are plain markdown.

## Layout

```
hawk-skills/
├── README.md
├── LICENSE
├── install.sh
└── skills/
    ├── code-audit/SKILL.md
    ├── code-audit-hardcore/SKILL.md
    ├── coding-process/SKILL.md
    └── ...
```

## License

MIT — see [LICENSE](./LICENSE).
