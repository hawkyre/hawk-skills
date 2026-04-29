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

To remove what you installed, run `./uninstall.sh` from a checkout — interactive picker, with `--dry-run`, `--all`, and `--prefix <p>` flags. It only touches directories whose `SKILL.md` description matches what we ship, so unrelated skills with colliding names are left alone.

## The idea: blind, parallel, independent subagents

Most of the heavy skills here fan out to subagents that work **in parallel**, with a deliberately **narrow brief**, and **no context on the overall goal**. They don't read the plan. They don't know what feature this is. They see only the code, the standards, and their specialist brief.

> A reviewer who knows the goal will rationalize the implementation toward the goal.
> A reviewer who only has the diff and a specialist brief evaluates the code on its own merits.

```
                 ┌──────────────────┐
                 │  diff / files    │
                 └────────┬─────────┘
                          │
        ┌─────────┬───────┼───────┬─────────┐
        ▼         ▼       ▼       ▼         ▼
    ┌───────┐ ┌──────┐ ┌─────┐ ┌──────┐ ┌──────┐
    │ logic │ │ sec  │ │ simp│ │ rsrch│ │ arch │   ← five specialists,
    │ + edge│ │      │ │     │ │      │ │      │     fresh sessions, no
    └───┬───┘ └──┬───┘ └──┬──┘ └──┬───┘ └──┬───┘     plan, no goal context
        │        │        │        │        │
        └────────┴────────┼────────┴────────┘
                          ▼
                    ┌───────────┐
                    │  merged   │
                    │  FIX/NOTE │   → applied (cleanup) or reported (report)
                    └───────────┘
```

The five `code-audit` specialists:

|     | Specialist             | Looks for                                                                                                                    |
| --- | ---------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| 1   | **Logic & edge cases** | off-by-one, null/NaN, empty inputs, concurrency, ordering, error paths, boundary values                                      |
| 2   | **Security**           | input validation, authn/authz, injection, XSS, SSRF, prompt injection, trust boundaries                                      |
| 3   | **Simplification**     | long functions, deep nesting, dead code, duplication, names that don't match behavior                                        |
| 4   | **Online research**    | verifies third-party APIs against current docs via WebSearch + WebFetch — flags deprecated APIs and version-specific gotchas |
| 5   | **Architecture**       | layer separation, file placement, import direction, type-safety, public API stability                                        |

Same pattern shows up in `code-audit-hardcore`, `implement-plan-audited`, and the self-review passes inside `plan-small` and `plan-large`.

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
| [`implement-plan-audited`](skills/implement-plan-audited/SKILL.md) | Same, but the five audit specialists run at strategic checkpoints (after a few S, two M, or one L — annotated into the plan up front). `mode=auto` runs unattended for hours; falls back to manual on repeated failure. |

### Quality

| Skill                                                        | Job                                                                                                                                                                                                                           |
| ------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`code-audit`](skills/code-audit/SKILL.md)                   | Five blind specialists in parallel. `mode=report` (default) or `cleanup`. `agents=light` drops the research pass.                                                                                                             |
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

## Layout

```
hawk-skills/
├── install.sh          # one-shot installer (TUI + curl-pipe support)
├── uninstall.sh        # interactive uninstaller
├── README.md
├── LICENSE
└── skills/
    ├── code-audit/SKILL.md
    ├── code-audit-hardcore/SKILL.md
    ├── coding-process/SKILL.md
    └── ...
```

## License

MIT — see [LICENSE](./LICENSE).
