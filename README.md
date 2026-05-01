<div align="start">

```
   _                    _          _    _ _ _
  | |                  | |        | |  (_) | |
  | |__   __ ___      _| | __  ___| | ___| | |___
  | '_ \ / _` \ \ /\ / / |/ / / __| |/ / | | / __|
  | | | | (_| |\ V  V /|   <  \__ \   <| | | \__ \
  |_| |_|\__,_| \_/\_/ |_|\_\ |___/_|\_\_|_|_|___/
```

**blind · parallel · independent**
Opinionated [Claude Code](https://claude.com/claude-code) skills for shipping real software with AI.

[Install](#install) ·
[Skills](#skills) ·
[The idea](#the-idea-blind-parallel-independent-subagents) ·
[Conventions](#conventions)

</div>

---

## Install

One line:

```bash
curl -fsSL https://raw.githubusercontent.com/hawkyre/hawk-skills/main/install.sh | bash
```

Or pick which skills you want:

```bash
curl -fsSL https://raw.githubusercontent.com/hawkyre/hawk-skills/main/install.sh | bash -s -- --select
```

```
   ❯ [✓] code-audit
     [✓] code-audit-hardcore
     [✓] coding-process
     [ ] design-master
     [✓] fix-bug
     ...
   ↑/↓ move · space toggle · a all · n none · enter confirm
```

The installer drops every selected skill into `~/.claude/skills/`. Re-run any time to refresh.

The interactive flow also offers to install the **hawk statusline** (`statusline/statusline.sh`) — a compact project · branch · context-% line for Claude Code. It's optional. From a one-liner, pass `--statusline` to opt in or `--no-statusline` to skip the prompt. The script is copied to `~/.claude/hawk-statusline.sh` and `~/.claude/settings.json` is updated to point at it (jq required for safe in-place edits; otherwise the snippet is printed).

To remove what you installed, run `./uninstall.sh` from a checkout — interactive picker, with `--dry-run`, `--all`, `--prefix <p>`, and `--statusline` / `--no-statusline` flags. It only touches directories whose `SKILL.md` description matches what we ship, so unrelated skills with colliding names are left alone.

## The idea: blind, parallel, independent subagents

Most of the heavy skills here fan out to subagents that work **in parallel**, with a deliberately **narrow brief**, and **no context on the overall goal**. They don't read the plan. They don't know what feature this is. They see only the code, the standards, and their specialist brief.

> A reviewer who knows the goal will rationalize the implementation toward the goal.
> A reviewer who only has the diff and a specialist brief evaluates the code on its own merits.

```
                ┌──────────────────┐
                │  diff / files    │
                └────────┬─────────┘
                         │
                         ▼
                ┌─────────────────┐
                │  audit-triage   │  ← haiku, ~1-2s
                │ (light/std/deep)│    classifies scope, picks subset
                └────────┬────────┘
                         │
        ┌────────┬───────┼───────┬────────┐
        ▼        ▼       ▼       ▼        ▼
   ┌───────┐ ┌──────┐ ┌─────┐ ┌──────┐ ┌──────┐
   │ logic │ │ sec  │ │simp │ │rsrch │ │ arch │  ← sonnet, parallel,
   └───┬───┘ └──┬───┘ └──┬──┘ └──┬───┘ └──┬───┘    fresh sessions,
       │        │        │        │        │       no plan, no goal
       └────────┴────────┼────────┴────────┘
                         ▼
                   ┌───────────┐
                   │  merged   │
                   │  FIX/NOTE │  → applied (cleanup) or reported (report)
                   └───────────┘
```

Each specialist is its own `audit-*` subagent file under
`agents/`, defined once and called from every audit-using skill:

|     | Specialist             | Looks for                                                                                                                    |
| --- | ---------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| 1   | **`audit-logic`**      | off-by-one, null/NaN, empty inputs, concurrency, ordering, error paths, boundary values                                      |
| 2   | **`audit-security`**   | input validation, authn/authz, injection, XSS, SSRF, prompt injection, trust boundaries                                      |
| 3   | **`audit-simplification`** | long functions, deep nesting, dead code, duplication, names that don't match behavior                                    |
| 4   | **`audit-research`**   | verifies third-party APIs against current docs via WebSearch + WebFetch — flags deprecated APIs and version-specific gotchas |
| 5   | **`audit-architecture`** | layer separation, file placement, import direction, type-safety, public API stability                                      |

Plus **`audit-triage`** — a haiku-powered classifier that reads the
diff and picks the specialist subset for the job. Light tasks get 2
specialists; risky ones get all five. The triage decision is
internal — you don't see it unless you ask.

The same pattern is reused by `code-audit-hardcore`,
`implement-plan-audited`, and `review-large-pr`. The plan skills
(`plan-small`, `plan-large`) use a separate **`plan-reviewer`**
agent for their self-review pass — same shape, plan-shaped brief.

## Skills

### Planning

| Skill                                              | Job                                                                                                                                                                                                                                          |
| -------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`coding-process`](skills/coding-process/SKILL.md) | Entry point. Reads the task, routes to the right skill below.                                                                                                                                                                                |
| [`plan-small`](skills/plan-small/SKILL.md)         | One-PR change. Searches the code before asking questions, surfaces assumptions/decisions alongside questions, writes `.plans/<slug>/plan.md`, then runs an independent self-review subagent that improves the plan before showing it to you. |
| [`plan-large`](skills/plan-large/SKILL.md)         | Multi-PR feature. Same code-search-first question gate, plus an increment DAG and explicit ordering review.                                                                                                                                  |
| [`review-plan`](skills/review-plan/SKILL.md)       | Adversarial review of a plan file.                                                                                                                                                                                                           |

### Execution

| Skill                                                              | Job                                                                                                                                              |
| ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| [`implement-plan`](skills/implement-plan/SKILL.md)                 | Execute an approved plan, increment by increment. Runs independent increments in parallel.                                                       |
| [`implement-plan-audited`](skills/implement-plan-audited/SKILL.md) | Same, but the `audit-*` specialists run at strategic checkpoints (after a few S, two M, or one L — annotated into the plan up front). `audit-triage` right-sizes per checkpoint. `mode=auto` runs unattended for hours; falls back to manual on repeated failure. |

### Quality

| Skill                                                        | Job                                                                                                                                                                                                                           |
| ------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`code-audit`](skills/code-audit/SKILL.md)                   | Blind specialists in parallel; subset chosen by `audit-triage`. `mode=report` (default) or `cleanup`. `tier=auto\|light\|standard\|deep` to right-size or force the specialist subset.                                        |
| [`code-audit-hardcore`](skills/code-audit-hardcore/SKILL.md) | Same scope as `code-audit`, expanded to tangibly-related code (setup, wiring, siblings). Always-improve posture: when there's a choice between leaving relevant code as-is and improving it, it improves. Big refactors route through `/plan-small` or `/plan-large`. |
| [`fix-bug`](skills/fix-bug/SKILL.md)                         | Hypothesis-first root cause analysis. Always considers online research at the hypothesis stage; applies it when triggers match (third-party error, library used <3 times, version-specific behavior, "should work per docs"). |
| [`refactor`](skills/refactor/SKILL.md)                       | One-dimension refactors: readability, modularity, performance, type safety, dedup.                                                                                                                                            |
| [`remove-code`](skills/remove-code/SKILL.md)                 | Trace-then-delete for features, dead code, dropped deps.                                                                                                                                                                      |
| [`review-large-pr`](skills/review-large-pr/SKILL.md)         | Chunked parallel review of 30+ file PRs.                                                                                                                                                                                      |

### Discovery & meta

| Skill                                            | Job                                                                              |
| ------------------------------------------------ | -------------------------------------------------------------------------------- |
| [`learn-system`](skills/learn-system/SKILL.md)   | Explore and explain a system — entry points, mental model, traced scenarios.     |
| [`design-master`](skills/design-master/SKILL.md) | Design system from first principles — color, typography, spacing, motion.        |
| [`init-phoenix`](skills/init-phoenix/SKILL.md)   | Bootstrap a Docker-based Phoenix project with the BEAM/macOS gotchas pre-solved. |

### Git

| Skill                            | Job                                                                                                  |
| -------------------------------- | ---------------------------------------------------------------------------------------------------- |
| [`cap`](skills/cap/SKILL.md)     | Stage, commit with a short message matching the repo's commit style, and push. No fuss.             |

## Quick taste

Once installed, just type:

```
/coding-process       ← let it route the task
/plan-small           ← one-PR change
/plan-large           ← multi-PR feature
/code-audit           ← review a diff
/code-audit-hardcore  ← aggressive cleanup of the changes + tangibly-related code
/implement-plan-audited mode=auto   ← hours of unattended execution
/fix-bug              ← hypothesis-first bug fix
```

Read any skill's full prompt at `~/.claude/skills/<name>/SKILL.md`. Fork it, change anything you don't like.

## Conventions

These skills assume three lightweight conventions:

| Path                       | What it is                                                                   |
| -------------------------- | ---------------------------------------------------------------------------- |
| `.plans/<slug>/plan.md`    | Plan files. `plan-*` writes them; `implement-plan*` reads them.              |
| `.agents/standards/`       | Your house conventions. Skills look up `index.yml` and read what's relevant. |
| `.agents/common-mistakes/` | Repo-specific gotchas. Same lookup pattern.                                  |

The `index.yml` files are plain YAML with topic → file mappings. Bootstrap them empty; the skills will tell you when they want one.

The project check command (`bun run c`, `pnpm typecheck`, `mix test`, etc.) is looked up — never assumed.

### Big-output discipline

Heavy command output blows the agent's context window and stays
expensive for every subsequent turn. Every skill in this repo follows
the same recipe:

1. **Redirect** any command whose output may exceed ~200 lines —
   project check command, full `git diff`, repo-wide search, long log,
   `WebFetch` of a long page — to a predictable file:

   ```bash
   <command> > /tmp/hawk-<skill>-<step>.log 2>&1
   ```

   Use `${TMPDIR:-/tmp}` if `/tmp` is unavailable. Pick a stable
   `<step>` (e.g. `check`, `diff`, `inc3`, `chunk2`) so the same path
   is reused by the inspection call. **Do not** use `$$` — Claude
   Code starts a new shell per Bash call, so `$$` differs between
   calls.

2. **Inspect** with `rg -n` (or `grep -nE` if `rg` is missing), capped:

   ```bash
   rg -n '<pattern>' /tmp/hawk-<skill>-<step>.log | head -50
   ```

3. **Read** the capture file with `offset`/`limit` only after `rg`
   has identified line ranges, or to bound the slice (≤200 lines).
   Never `Read` an unbounded /tmp capture.

**In scope** (always redirect): typecheckers, test runners, linters,
dialyzer, full `git diff`, `git diff <range>` with code, repo-wide
`rg`/`grep`, `docker compose logs`, `WebFetch` payloads >~10KB
(capture via `curl -sSL <url> -o /tmp/hawk-<skill>-fetch.html`).

**Out of scope** (inline is fine): `git status`, `git log --oneline`,
`git diff --name-only`, `git diff --stat`, `git rev-parse HEAD`,
focused `Read` of a known file, narrow `rg` over a small subdir.

**Subagents inherit the rule.** When a skill fans out to subagents,
the orchestrator pastes narrowed slices (not raw captures) into the
subagent prompt, and the prompt template includes this same Rules
bullet so the subagent applies the recipe to its own commands.

Files are prefixed `hawk-<skill>-` so a session can prune with
`rm -f /tmp/hawk-*` when finished.

## Layout

```
hawk-skills/
├── install.sh           # one-shot installer (TUI + curl-pipe support)
├── uninstall.sh         # interactive uninstaller
├── README.md
├── LICENSE
├── statusline/
│   └── statusline.sh    # optional Claude Code statusline
├── agents/              # subagent definitions (one .md per agent)
│   ├── audit-triage.md  # haiku-powered tier classifier
│   ├── audit-logic.md   # specialist briefs — referenced by skills
│   └── ...
└── skills/
    ├── code-audit/SKILL.md
    ├── code-audit-hardcore/SKILL.md
    ├── coding-process/SKILL.md
    └── ...
```

The audit-style skills (`code-audit`, `code-audit-hardcore`,
`implement-plan-audited`, `review-large-pr`) call the `audit-*`
subagents directly — `Agent(subagent_type="audit-logic", …)` and
similar. The plan skills (`plan-small`, `plan-large`) call
`plan-reviewer` the same way. Each specialist's brief, anti-bias
contract, tool-usage policy, and output schema live in the agent
file once instead of being inlined across every skill — update the
agent and every skill that uses it gets the new behavior on the
next call. Install-time `--prefix` rewrites both the agent filenames
and every concrete `subagent_type=` reference in installed skills,
so namespaced installs stay wired.

## License

MIT — see [LICENSE](./LICENSE).
