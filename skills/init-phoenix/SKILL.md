---
name: init-phoenix
description: Initialize a full Phoenix project from an AI-scaffold repo. Generates Docker environment, Makefile, standards, and config with all BEAM/macOS/Docker gotchas pre-solved. Invoked directly, not routed from coding-process.
---

# Initialize a Phoenix Project

Bootstrap a fully working Docker-based Phoenix dev environment from a bare AI-scaffold repo (one containing `.agents/`, `.claude/`, `.cursor/`, `.plans/`, `AGENTS.md`, `CLAUDE.md`). This skill captures every gotcha discovered during manual bootstrapping so they never need to be rediscovered.

## Process

### Phase 1: Gather Requirements

1. **Ask the user** for the following (provide sensible defaults where noted):

   | Parameter | Example | Default |
   |-----------|---------|---------|
   | Project name (snake_case) | `hermes` | — (required) |
   | One-line description | "Parallel dialer platform" | — (required) |
   | Elixir version | `1.19.5` | Latest stable |
   | Erlang/OTP version | `28.4.1` | Latest stable compatible with Elixir |
   | Alpine Linux version | `3.23.3` | Latest stable |
   | Node.js version (for esbuild/tailwind) | `24.14.1` | Latest LTS |
   | Phoenix version | `1.8.5` | Latest stable |
   | `mix phx.new` flags | `--live --binary-id` | `--live --binary-id` |
   | Infrastructure services | Postgres 18, OpenSearch 3.5.x | Postgres (latest stable) |
   | Extra mix deps | libcluster, oban, dialyxir, credo | dialyxir, credo |
   | Host port for Phoenix | `4000` | `4000` |
   | Host ports for other services | Postgres: `5432` | Standard defaults |

2. **Record all values** — they parameterize every template in subsequent phases.

### Phase 2: Set `.tool-versions` and Generate Phoenix

1. Write `.tool-versions`:
   ```
   erlang <erlang_version>
   elixir <elixir_version>-otp-<otp_major>
   nodejs <node_version>
   ```

2. Generate Phoenix project in `/tmp` (NEVER in the target directory):
   ```bash
   mix archive.install hex phx_new <phoenix_version> --force
   mix phx.new /tmp/<app_name> --app <app_name> <phx_new_flags> --no-install --no-agents-md
   ```

3. Copy generated files into repo root, preserving existing scaffold files:
   ```bash
   rsync -av --exclude='.git' \
     --exclude='AGENTS.md' --exclude='CLAUDE.md' \
     --exclude='.agents/' --exclude='.claude/' \
     --exclude='.cursor/' --exclude='.plans/' \
     /tmp/<app_name>/ ./
   ```

4. Clean up: `rm -rf /tmp/<app_name>`

### Phase 3: Add Extra Dependencies

1. Edit `mix.exs` — add to the `deps` function:
   - `{:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}`
   - `{:credo, "~> 1.7", only: [:dev, :test], runtime: false}`
   - `{:typed_ecto_schema, "~> 0.4"}` (ALWAYS included — all schemas use `typed_schema`)
   - Any user-requested deps (libcluster, oban, etc.)

2. Run `mix deps.get > /tmp/hawk-init-phoenix-deps.log 2>&1` and `rg -n 'error|fail' /tmp/hawk-init-phoenix-deps.log | head -50` to confirm clean.

3. Run `mix compile > /tmp/hawk-init-phoenix-compile.log 2>&1` and `rg -n 'warning|error' /tmp/hawk-init-phoenix-compile.log | head -50` (compile warnings can be voluminous).

### Phase 4: Create Docker Environment

1. **Verify the Docker base image tag exists** before writing any file:
   ```bash
   docker pull hexpm/elixir:<elixir_version>-erlang-<erlang_version>-alpine-<alpine_version>
   ```
   If the pull fails, try adjacent Alpine patch versions (e.g., `3.21.2`, `3.21.0`) until one succeeds. Use the working tag for all subsequent steps.

2. Write `Dockerfile.dev` — see [Reference: Dockerfile.dev](#reference-dockerfiledev).

3. Write `docker-compose.yml` — see [Reference: docker-compose.yml](#reference-docker-composeyml).

4. Write `.dockerignore` — see [Reference: .dockerignore](#reference-dockerignore).

### Phase 5: Configure Dev Environment

1. **`config/dev.exs`** — apply these changes:
   - Endpoint binds to `{0, 0, 0, 0}` (all interfaces, required for Docker)
   - DB hostname from `System.get_env("DB_HOST") || "localhost"`
   - Live reload backend: `backend: :fs_poll, backend_opts: [interval: 500]` — **macOS only** (native fs events don't cross the VM boundary). On Linux, native inotify works across bind mounts; leave the default and skip this.
   - If libcluster: add Gossip topology config

2. **`config/test.exs`** — DB hostname from `System.get_env("DB_HOST") || "localhost"`, exactly as in `dev.exs`. The test Repo also runs inside the container and must reach Postgres at host `db`. If you skip this, `make up` and `make setup` still pass but `make check` fails at the test step with `tcp connect (localhost:5432): connection refused`.

3. **`lib/<app_name>/application.ex`** — if libcluster is included:
   - Replace the `DNSCluster` child spec with:
     ```elixir
     topologies = Application.get_env(:<app_name>, :cluster_topologies, [])
     {Cluster.Supervisor, [topologies, [name: <AppModule>.ClusterSupervisor]]}
     ```

4. **`config/runtime.exs`** — verify `PHX_HOST` and `DATABASE_URL` are read from env for prod.

### Phase 6: Create Makefile

Write `Makefile` — see [Reference: Makefile](#reference-makefile).

Key gotchas baked into the Makefile:
- `setup` and `console` use `-e ERL_FLAGS=""` to clear inherited flags from the container env — without this, `mix ecto.setup` and `iex --remsh` fail because they try to reuse the app's `--sname` flag and get a name conflict.
- `console` uses `--sname console --remsh <app_name>@<app_name>` — the hostname matches the static `hostname:` in docker-compose.yml, which is required because BEAM node names include the hostname.
- All dev operations go through `make` — this is the single entry point.

### Phase 7: Create Credo Config

Write `.credo.exs` — see [Reference: .credo.exs](#reference-credoexs).

### Phase 8: Create Standards Files

1. Write `.agents/standards/backend/elixir.md` — see [Reference: Elixir Standards](#reference-elixir-standards).
2. Write `.agents/standards/backend/phoenix.md` — see [Reference: Phoenix Standards](#reference-phoenix-standards).
3. Write `.agents/standards/backend/testing.md` — see [Reference: Testing Standards](#reference-testing-standards).
4. Write `.agents/standards/index.yml` — see [Reference: Standards Index](#reference-standards-index).

### Phase 9: Update AGENTS.md

Rewrite `AGENTS.md` with project-specific content:
- Stack section with exact versions
- Docker-based commands (all via `make`)
- Architecture paths (`/lib/<app_name>/`, `/lib/<app_name>_web/`, etc.)
- Conventions (conventional commits, one concern per PR, tests required)
- Verification steps (format, test, compile with warnings-as-errors)

Also update `CLAUDE.md` to match the same content.

### Phase 10: Verify, Conform, and Init Git

Each verification step writes its output to `/tmp/hawk-init-phoenix-<step>.log` (with `2>&1`). Inspect with `rg -n 'error|warning|fail|FAIL' /tmp/hawk-init-phoenix-<step>.log | head -50` rather than streaming the raw output.

Run these steps in order:

1. `make up > /tmp/hawk-init-phoenix-up.log 2>&1` — all containers start, healthchecks pass.

2. `make setup > /tmp/hawk-init-phoenix-setup.log 2>&1` — fetches deps, creates the DB, runs migrations, installs the tailwind/esbuild binaries.

   **Known failure — asset binary download.** `mix tailwind.install` / `esbuild.install` fetch binaries via Erlang `:httpc`, which fails on IPv6-broken Docker networks (`{:failed_connect, [..., {:inet6, [:inet6], :nxdomain}]}`) even when `curl` inside the container works. If `make setup` fails here, pre-place the binaries — read the exact versions from `config/config.exs` (`config :tailwind, version:` and `config :esbuild, version:`):
   ```bash
   docker compose exec -e ERL_FLAGS="" app sh -c '
     cd /app && mkdir -p _build
     curl -sSL4 -o _build/tailwind-linux-x64-musl \
       https://github.com/tailwindlabs/tailwindcss/releases/download/v<tailwind_version>/tailwindcss-linux-x64-musl
     chmod +x _build/tailwind-linux-x64-musl
     curl -sSL4 https://registry.npmjs.org/@esbuild/linux-x64/-/linux-x64-<esbuild_version>.tgz \
       | tar -xz -C /tmp
     cp /tmp/package/bin/esbuild _build/esbuild-linux-x64 && chmod +x _build/esbuild-linux-x64'
   ```
   Then re-run `make setup` — `*.install --if-missing` detects the binaries and skips the download.

3. `curl -s -o /dev/null -w "%{http_code}" http://localhost:<phoenix_port>` — expect `200` (output is tiny, inline)
4. Verify BEAM console connectivity:
   ```bash
   docker compose exec -e ERL_FLAGS="" app \
     erl -noshell -sname probe -setcookie <app_name>_dev_cookie \
     -eval "case net_adm:ping('<app_name>@<app_name>') of pong -> io:format(\"connected~n\"), halt(0); pang -> io:format(\"failed~n\"), halt(1) end"
   ```
5. **Conform the generated scaffold to `credo --strict`.** `mix phx.new` emits framework boilerplate that does not satisfy the strict `.credo.exs` from Phase 7 — generated functions lack `@spec`s, and `<app_name>_web.ex` has an alias-ordering issue. Do **not** weaken the credo config to compensate; bring the generated files up to standard instead. This is near-mechanical. Run `make credo > /tmp/hawk-init-phoenix-credo.log 2>&1` for the exact current list (Phoenix's generated set shifts between versions — the live report is the source of truth, not this table), then resolve every issue:

   - **Missing `@spec` (`Credo.Check.Readability.Specs`)** — add a `@spec` directly above the function (above the *first* clause for multi-clause functions; after `@doc` if present). The shape is uniform per file category:

     | Generated file(s) | Function shape | `@spec` to add |
     |---|---|---|
     | `core_components.ex`, `components/layouts.ex` | function components — `def name(assigns)` | `@spec name(map()) :: Phoenix.LiveView.Rendered.t()` |
     | `<app_name>_web.ex` | 0-arity macro helpers (`controller`, `html`, `router`, `live_view`, …) | `@spec name() :: Macro.t()` |
     | `controllers/page_controller.ex` | `def action(conn, _params)` | `@spec action(Plug.Conn.t(), map()) :: Plug.Conn.t()` |
     | `controllers/error_html.ex` / `error_json.ex` | `def render(template, _assigns)` | check the body — `error_html` returns a `String.t()`, `error_json` a `map()` |
     | `telemetry.ex` | `start_link/1`, `metrics/0` | `@spec start_link(keyword()) :: Supervisor.on_start()`, `@spec metrics() :: [Telemetry.Metrics.t()]` |
     | `test/support/*_case.ex` | `setup_sandbox/1`, `errors_on/1`, … | write from the actual signature |

     For anything the table does not cover, read the function body and write a precise spec — never a `term() :: term()` placeholder; that defeats the standard and can fail Dialyzer.

   - **`Credo.Check.Readability.AliasOrder`** — generated `<app_name>_web.ex` lists `alias Phoenix.LiveView.JS` before `alias <AppModule>Web.Layouts`; swap the two `alias` lines into alphabetical order.

   - **`Credo.Check.Design.AliasUsage`** — for each flagged fully-qualified nested module, add an `alias` at the top of the module and use the short name.

   Re-run `make credo` until it reports **0 issues**, then `make format` (newly added specs and aliases may need reformatting).

6. `make check > /tmp/hawk-init-phoenix-check.log 2>&1` (format/compile/credo/test/dialyzer — dialyzer output is voluminous, redirect is mandatory).
7. `git init && git add -A && git commit -m "feat: initialize <app_name> Phoenix project"`

If any step fails, `rg` the relevant /tmp log for the actual error and fix before proceeding. When a fix edits `Dockerfile.dev` or `docker-compose.yml`, recreate with `docker compose up -d --build --force-recreate` — a plain `docker compose up -d --build` may leave the old container running, so the change does not take effect.

---

## Rules

- **Big-output discipline.** Heavy command output (project check, full `git diff`, repo-wide search, long log, large fetch) goes to `/tmp/hawk-init-phoenix-<step>.log`, then `rg -n '<pattern>' /tmp/hawk-init-phoenix-<step>.log | head -50` extracts what you need. `Read` the file only with `offset`/`limit`. See README → Big-output discipline. `mix compile`, `mix test`, `mix dialyzer`, `make check`, `make setup`, `make up`, and `docker compose logs` all redirect.
- **ALWAYS** verify the Docker base image tag exists before writing the Dockerfile — Alpine patch versions are unpredictable and change without notice
- **ALWAYS** set a static `hostname` on the app container in docker-compose.yml — BEAM node names depend on it and container IDs are dynamic
- **ALWAYS** use `-e ERL_FLAGS=""` for `docker compose exec` commands that run mix tasks or iex — the container's `ERL_FLAGS` (which set `--sname` for the running app) conflict with new BEAM instances spawned by exec
- **ALWAYS** use `-sname` (not `-name`) for dev clustering — simpler, no FQDN needed in local dev
- **ALWAYS** use `fs_poll` backend for live reload in Docker on macOS — native filesystem events do not cross the VM boundary
- **ALWAYS** use named volumes for `deps/` and `_build/` — bind-mounting these from macOS kills performance due to the osxfs/virtiofs overhead
- **ALWAYS** mount the Postgres volume at `/var/lib/postgresql`, not `/var/lib/postgresql/data` — Postgres 18+ refuses to start with a `/data` mount
- **ALWAYS** bake the distribution cookie into `/root/.erlang.cookie` in the Dockerfile — Elixir 1.19's CLI launcher does not reliably apply `-cookie` from ERL_FLAGS, so the cookie file is the only dependable source; `make console` depends on it
- **ALWAYS** apply the `System.get_env("DB_HOST")` lookup to BOTH `config/dev.exs` and `config/test.exs` — the test Repo runs inside the container and must reach Postgres at host `db`
- **NEVER** pin `MIX_ENV` in `docker-compose.yml` — mix defaults to `:dev` anyway, and pinning it forces `mix test` into `:dev`, skips `config/test.exs`, and breaks `make check`
- **NEVER** weaken `.credo.exs` to make a freshly generated scaffold pass — the strict config is intentional; conform the generated framework code instead (Phase 10)
- **NEVER** run `mix phx.new` in the target directory — generate in `/tmp` and rsync, preserving existing scaffold files (`.agents/`, `.claude/`, `.cursor/`, `.plans/`)
- **NEVER** hardcode versions in Dockerfile or compose without verifying they exist first
- The Makefile is the single entry point for all dev operations — every command should have a `make` target
- Standards files go in `.agents/standards/backend/` — always update `index.yml` to index them

---

## Reference: Dockerfile.dev

```dockerfile
# <app_name>/Dockerfile.dev
ARG ELIXIR_VERSION=<elixir_version>
ARG ERLANG_VERSION=<erlang_version>
ARG ALPINE_VERSION=<alpine_version>

FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${ERLANG_VERSION}-alpine-${ALPINE_VERSION}

# Install system dependencies
RUN apk add --no-cache \
    build-base \
    git \
    inotify-tools \
    postgresql-client \
    curl

# Set working directory
WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Cache dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get && mix deps.compile

# Copy application code
COPY . .

# Stable Erlang distribution cookie. Elixir 1.19's CLI launcher does not
# reliably apply `-cookie` passed through ERL_FLAGS, so without this the app
# node uses a random per-container cookie and `make console` cannot attach.
RUN printf '<app_name>_dev_cookie' > /root/.erlang.cookie && \
    chmod 400 /root/.erlang.cookie

# Default command
CMD ["mix", "phx.server"]
```

## Reference: docker-compose.yml

```yaml
# <app_name>/docker-compose.yml
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile.dev
    hostname: <app_name>
    ports:
      - "${PHX_PORT:-<phoenix_port>}:4000"
    volumes:
      - .:/app
      - deps:/app/deps
      - build:/app/_build
    environment:
      # Do NOT pin MIX_ENV here. mix defaults to :dev, so the server still runs
      # in dev — but pinning it forces `mix test` into :dev too, which silently
      # skips config/test.exs (the SQL Sandbox pool) and fails `make check`.
      - DB_HOST=db
      - PHX_HOST=localhost
      # ERL_FLAGS sets only the node name. The distribution cookie comes from a
      # baked .erlang.cookie file (see Dockerfile.dev) — Elixir 1.19's CLI
      # launcher does not reliably apply `-cookie` passed via ERL_FLAGS.
      - ERL_FLAGS=-sname <app_name>
    depends_on:
      db:
        condition: service_healthy
    stdin_open: true
    tty: true
    networks:
      - <app_name>_net

  db:
    image: postgres:<postgres_version>-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "${DB_PORT:-<db_port>}:5432"
    volumes:
      # Postgres 18+ stores data in a major-version subdirectory and refuses to
      # start if the volume is mounted at /data. Mount the parent directory.
      # (See docker-library/postgres#1259.)
      - pgdata:/var/lib/postgresql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5
    networks:
      - <app_name>_net

  # --- Add additional services below as needed ---
  # Example: OpenSearch
  # opensearch:
  #   image: opensearchproject/opensearch:<opensearch_version>
  #   environment:
  #     - discovery.type=single-node
  #     - DISABLE_SECURITY_PLUGIN=true
  #     - OPENSEARCH_INITIAL_ADMIN_PASSWORD=<generated_password>
  #   ports:
  #     - "${OPENSEARCH_PORT:-9200}:9200"
  #   volumes:
  #     - opensearch_data:/usr/share/opensearch/data
  #   healthcheck:
  #     test: ["CMD-SHELL", "curl -s http://localhost:9200/_cluster/health | grep -q '\"status\":\"green\\|yellow\"'"]
  #     interval: 10s
  #     timeout: 5s
  #     retries: 10
  #   networks:
  #     - <app_name>_net

volumes:
  deps:
  build:
  pgdata:
  # opensearch_data:

networks:
  <app_name>_net:
    driver: bridge
```

## Reference: .dockerignore

```
_build/
deps/
.git/
.elixir_ls/
.agents/
.claude/
.cursor/
.plans/
*.md
.tool-versions
```

## Reference: Makefile

```makefile
# <app_name>/Makefile
.PHONY: up down setup console logs restart test format credo dialyzer check

# Start all services
up:
	docker compose up -d

# Stop all services
down:
	docker compose down

# Setup database, deps, and assets (first-time or reset)
setup:
	docker compose exec -e ERL_FLAGS="" app mix deps.get
	docker compose exec -e ERL_FLAGS="" app mix ecto.setup
	docker compose exec -e ERL_FLAGS="" app mix assets.setup

# Remote IEx console attached to running app node
console:
	docker compose exec -e ERL_FLAGS="" app \
		iex --sname console --cookie <app_name>_dev_cookie --remsh <app_name>@<app_name>

# Tail logs
logs:
	docker compose logs -f

# Restart the app container only
restart:
	docker compose restart app

# Run tests
test:
	docker compose exec -e ERL_FLAGS="" app mix test

# Format code
format:
	docker compose exec -e ERL_FLAGS="" app mix format

# Run Credo
credo:
	docker compose exec -e ERL_FLAGS="" app mix credo --strict

# Run Dialyzer
dialyzer:
	docker compose exec -e ERL_FLAGS="" app mix dialyzer

# Full check: format + compile + credo + test + dialyzer
check:
	docker compose exec -e ERL_FLAGS="" app mix format --check-formatted
	docker compose exec -e ERL_FLAGS="" app mix compile --warnings-as-errors
	docker compose exec -e ERL_FLAGS="" app mix credo --strict
	docker compose exec -e ERL_FLAGS="" app mix test
	docker compose exec -e ERL_FLAGS="" app mix dialyzer
```

## Reference: .credo.exs

```elixir
# <app_name>/.credo.exs
%{
  configs: [
    %{
      name: "default",
      strict: true,
      files: %{
        included: [
          "lib/",
          "src/",
          "test/"
        ],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      plugins: [],
      requires: [],
      parse_timeout: 5000,
      checks: %{
        enabled: [
          # Consistency
          {Credo.Check.Consistency.ExceptionNames, []},
          {Credo.Check.Consistency.LineEndings, []},
          {Credo.Check.Consistency.ParameterPatternMatching, []},
          {Credo.Check.Consistency.SpaceAroundOperators, []},
          {Credo.Check.Consistency.SpaceInParentheses, []},
          {Credo.Check.Consistency.TabsOrSpaces, []},

          # Design
          {Credo.Check.Design.AliasUsage, [priority: :low, if_nested_deeper_than: 2, if_called_more_often_than: 0]},
          {Credo.Check.Design.DuplicatedCode, [excluded_macros: [], mass_threshold: 16]},
          {Credo.Check.Design.TagFIXME, []},
          {Credo.Check.Design.TagTODO, [exit_status: 0]},

          # Readability
          {Credo.Check.Readability.AliasOrder, []},
          {Credo.Check.Readability.FunctionNames, []},
          {Credo.Check.Readability.LargeNumbers, []},
          {Credo.Check.Readability.MaxLineLength, [priority: :low, max_length: 120]},
          {Credo.Check.Readability.ModuleAttributeNames, []},
          {Credo.Check.Readability.ModuleDoc, []},
          {Credo.Check.Readability.ModuleNames, []},
          {Credo.Check.Readability.ParenthesesInCondition, []},
          {Credo.Check.Readability.PredicateFunctionNames, []},
          {Credo.Check.Readability.PreferImplicitTry, []},
          {Credo.Check.Readability.RedundantBlankLines, []},
          {Credo.Check.Readability.Semicolons, []},
          {Credo.Check.Readability.SinglePipe, []},
          {Credo.Check.Readability.Specs, [priority: :high]},
          {Credo.Check.Readability.StrictModuleLayout, []},
          {Credo.Check.Readability.StringSigils, []},
          {Credo.Check.Readability.TrailingBlankLine, []},
          {Credo.Check.Readability.TrailingWhiteSpace, []},
          {Credo.Check.Readability.UnnecessaryAliasExpansion, []},
          {Credo.Check.Readability.VariableNames, []},
          {Credo.Check.Readability.WithSingleClause, []},

          # Refactoring
          {Credo.Check.Refactor.ABCSize, [max_size: 30]},
          {Credo.Check.Refactor.AppendSingleItem, []},
          {Credo.Check.Refactor.CondStatements, []},
          {Credo.Check.Refactor.CyclomaticComplexity, [max_complexity: 10]},
          {Credo.Check.Refactor.DoubleBooleanNegation, []},
          {Credo.Check.Refactor.FilterCount, []},
          {Credo.Check.Refactor.FilterFilter, []},
          {Credo.Check.Refactor.FunctionArity, [max_arity: 5]},
          {Credo.Check.Refactor.LongQuoteBlocks, []},
          {Credo.Check.Refactor.MapJoin, []},
          {Credo.Check.Refactor.MatchInCondition, []},
          {Credo.Check.Refactor.NegatedConditionsInUnless, []},
          {Credo.Check.Refactor.NegatedConditionsWithElse, []},
          {Credo.Check.Refactor.Nesting, [max_nesting: 3]},
          {Credo.Check.Refactor.PipeChainStart, []},
          {Credo.Check.Refactor.RedundantWithClauseResult, []},
          {Credo.Check.Refactor.RejectReject, []},
          {Credo.Check.Refactor.UnlessWithElse, []},
          {Credo.Check.Refactor.WithClauses, []},

          # Warnings
          {Credo.Check.Warning.ApplicationConfigInModuleAttribute, []},
          {Credo.Check.Warning.BoolOperationOnSameValues, []},
          {Credo.Check.Warning.Dbg, []},
          {Credo.Check.Warning.ExpensiveEmptyEnumCheck, []},
          {Credo.Check.Warning.IExPry, []},
          {Credo.Check.Warning.IoInspect, []},
          {Credo.Check.Warning.MissedMetadataKeyInLoggerConfig, []},
          {Credo.Check.Warning.OperationOnSameValues, []},
          {Credo.Check.Warning.OperationWithConstantResult, []},
          {Credo.Check.Warning.RaiseInsideRescue, []},
          {Credo.Check.Warning.SpecWithStruct, []},
          {Credo.Check.Warning.UnsafeExec, []},
          {Credo.Check.Warning.UnusedEnumOperation, []},
          {Credo.Check.Warning.UnusedFileOperation, []},
          {Credo.Check.Warning.UnusedKeywordOperation, []},
          {Credo.Check.Warning.UnusedListOperation, []},
          {Credo.Check.Warning.UnusedPathOperation, []},
          {Credo.Check.Warning.UnusedRegexOperation, []},
          {Credo.Check.Warning.UnusedStringOperation, []},
          {Credo.Check.Warning.UnusedTupleOperation, []},
          {Credo.Check.Warning.WrongTestFileExtension, []}
        ],
        disabled: []
      }
    }
  ]
}
```

## Reference: Elixir Standards

```markdown
# Elixir Language Standards

Sources: Official Elixir docs (naming conventions, library guidelines, anti-patterns, typespecs, writing documentation), Christopher Adams' elixir_style_guide, Credo checks.

---

## Documentation

- **Every module** MUST have `@moduledoc`. Use `@moduledoc false` only for internal implementation modules.
- **Every public function** MUST have `@doc` with a description and `## Examples` section using `iex>` prompts (verified by doctests).
- **Every custom type** MUST have `@typedoc`.
- First paragraph of `@moduledoc`/`@doc` must be a concise one-line summary — tools extract it.
- Reference modules in backticks: `` `MyApp.Hello` ``. Reference functions with arity: `` `world/1` ``. Use `c:` for callbacks, `t:` for types.
- Use second-level headers (`##`) in docs; first-level is reserved for module/function names.
- Document multi-clause functions before the first clause only.
- NEVER use `@doc` on private functions.

## Typespecs

- **Every public function** MUST have `@spec`.
- **Every private function** MUST have `@spec` (project rule — stricter than community norm).
- Place `@spec` directly before the function definition, after `@doc`, with no separating blank line.
- Name the main type for a module `t`: `@type t :: %__MODULE__{...}`.
- Use named arguments for clarity: `@spec days_since_epoch(year :: integer, month :: integer, day :: integer) :: integer`.
- NEVER use `string()` — use `String.t()`, `binary()`, or `charlist()`.
- Reserve `no_return()` only for functions that truly never return.
- Use `@impl true` on all callback implementations.

## Naming

- `snake_case` for: variables, functions, module attributes, atoms, file names.
- `CamelCase` for: modules. Keep acronyms uppercase: `SomeXML`, `ExUnit.CaptureIO`.
- Trailing `?` for boolean-returning functions: `valid?/1`.
- `is_` prefix ONLY for guard-compatible boolean checks: `is_admin/1`. Never for non-guard checks.
- Trailing `!` for functions that raise on failure; always pair with a tuple-returning variant.
- `size` = O(1), `length` = O(n).
- `get` returns nil/default on miss; `fetch` returns `{:ok, val}` or `:error`; `fetch!` raises.
- Private functions must NOT share names with public functions — use more descriptive names.
- No repeated fragments in module names: `Todo.Item` not `Todo.TodoItem`.

## Module Organization

Strict ordering within modules:

1. `@moduledoc`
2. `@behaviour`
3. `use`
4. `import`
5. `require`
6. `alias` (alphabetically sorted)
7. Module attributes (`@attr`)
8. `defstruct`
9. `@type` / `@typep` / `@opaque`
10. `@callback` / `@macrocallback` / `@optional_callbacks`
11. Public functions (`def`)
12. Private functions (`defp`)

Blank line between each group. One module per file unless a module is only used internally.

## Pipe Operator

- **NEVER** use a single pipe. One function call = normal syntax: `String.downcase(val)`.
- **ALWAYS** start pipe chains with a raw value (variable, string, struct), never a function call.
- Use parentheses for ALL functions in pipe chains, including zero-arity.
- One pipe per line in multiline chains.
- Never pipe into anonymous functions or blocks.

## Pattern Matching

- Use `map.key` (dot syntax) for required keys that must exist. Use `map[:key]` only for optional keys.
- When operands are expected to be booleans, use `and/or/not` instead of `&&/||/!`.
- Extract only pattern/guard-related variables in function heads. Use body-level matching for the rest.
- Prefer pattern matching in function heads over `case` when possible.
- Use `with` for happy-path chaining; avoid complex `else` blocks.

## Error Handling

- Return `{:ok, result}` or `{:error, reason}` tuples for expected failures.
- Provide bang (`!`) variants that raise alongside tuple-returning versions.
- Use `case` + pattern matching for error tuples — NEVER `try/rescue` for control flow.
- Exception module names must end with `Error`.
- Lowercase error messages, no trailing punctuation: `raise ArgumentError, "invalid input"`.

## Control Flow

- Never use `unless` with `else` — rewrite with positive case first.
- Always use parentheses for zero-arity function calls: `do_stuff()` not `do_stuff`.
- Prefer `cond` over nested `if/else`.

## Collections

- Use dot access (`map.key`) for required keys; bracket access (`map[:key]`) for optional keys.
- Prefer `[item | list]` over `list ++ [item]`.
- Structs must stay under 32 fields.
- Never create atoms from untrusted input; use `String.to_existing_atom/1`.

## Anti-Patterns to Avoid

1. **Exceptions for control flow** — use ok/error tuples.
2. **Boolean obsession** — use atoms/enums instead of multiple boolean flags.
3. **Primitive obsession** — model domain concepts with structs, not bare strings/integers.
4. **Alternative return types** — don't use options to change return types; create separate functions.
5. **Unsupervised processes** — all long-running processes must be in supervision trees.
6. **Unnecessary macros** — use functions instead when possible.
7. **Application config for libraries** — accept config via function parameters.
8. **Long parameter lists** — group related args in maps/structs/keyword lists.

## Comments

- Write self-explanatory code first; comments are a last resort.
- Use `TODO:`, `FIXME:`, `OPTIMIZE:`, `HACK:`, `REVIEW:` annotations with capitalized descriptions.
- One space between `#` and comment text.
```

## Reference: Phoenix Standards

```markdown
# Phoenix & Ecto Standards

Sources: Phoenix contexts guide, Phoenix controllers guide, Ecto.Changeset docs, Nimble HQ conventions.

---

## Context Boundaries

- Contexts encapsulate a domain area's data access and validation.
- Context names reflect business domains, not technical concerns (e.g., `Accounts`, `Billing`).
- Controllers and LiveViews ONLY call context functions — never access `Repo` or `Ecto` directly.
- When multiple contexts coordinate, use a dedicated service module.
- Organize internals with subdirectories: `queries/`, `schemas/`, `helpers/`.

## Controllers

- Standard CRUD actions only: `index`, `show`, `new`, `create`, `edit`, `update`, `delete`.
- All actions take exactly two parameters: `conn` and `params`.
- Pattern match params in function signatures.
- Use `~p` sigil paths with `:to` for internal redirects; `:external` for external URLs.
- Controller and view must share the same root name.

## Schemas & Changesets

- **ALWAYS** use `typed_ecto_schema` instead of `Ecto.Schema` — use `typed_schema` and `typed_embedded_schema` macros. This provides compile-time type derivation from schema definitions, eliminating manual `@type t` boilerplate and keeping types in sync with fields.
- Use `cast/4` for external data (forms, APIs) — performs type conversion with explicit field permissions.
- Use `change/2` for internal application data — assumes already valid.
- Pipeline pattern: `struct |> cast(params, fields) |> validate_required(required) |> validate_* |> unique_constraint(...)`.
- Create multiple changeset functions per schema for different operations: `changeset/2`, `create_changeset/2`, `registration_changeset/2`.
- Validations (no DB) run before constraints (require DB).

## LiveView

- `_live` suffix on LiveView modules.
- `_component` suffix on LiveComponent modules.
- LiveComponents go in `components/` subdirectory.
- HEEx templates alongside their live modules.
- Strings for event names in `handle_event/3`; atoms for internal messages in `handle_info/2`.
- Extract logic into context modules when LiveViews grow large.

## Ecto Queries

- Prefer pipe-based syntax over keyword-based.

## Routes

- Separate `scope` per `pipe_through`.

## Templates

- Standard HTML templates in `snake_case`.
- Partial files prefixed with underscore: `_card.html.heex`.
```

## Reference: Testing Standards

```markdown
# Testing Standards

Sources: ExUnit docs, Phoenix testing guide, community conventions.

---

## Organization

- Tests in `test/` mirroring `lib/` structure.
- Files named `*_test.exs` (`.exs`, not `.ex`).
- Use `async: true` whenever possible. When async is impossible, add a comment explaining why.

## Naming

- `describe` blocks use function name with arity: `describe "list/1" do`.
- Order `describe` blocks matching the source module's function order.
- Test names start with preconditions: `"with valid params, returns the user"`, `"given no input, raises an error"`.

## Assertions

- Expression under test on the LEFT, expected value on the RIGHT: `assert actual == expected`.
- Use `==` for exact value checks; pattern matching only for partial matches.
- Use `assert value == nil` rather than `refute value`.

## Phoenix Testing

- Controller tests for isolated logic; request tests for full plug pipeline.
- Controller describe blocks use action name with arity.
- Request test describe blocks use HTTP method + route: `describe "GET /keywords" do`.

## Doctests

- All public functions with `@doc` should include `## Examples` with `iex>` prompts.
- ExUnit's `doctest MyModule` verifies examples stay correct.
```

## Reference: Standards Index

```yaml
# Standards Index
# Read this first to find which standards apply to your task.
# Each entry maps to a file in .agents/standards/[area]/[name].md

backend:
  elixir:
    file: backend/elixir.md
    description: Elixir language conventions — naming, docs, specs, pipes, pattern matching, error handling, module layout
  phoenix:
    file: backend/phoenix.md
    description: Phoenix/Ecto conventions — contexts, controllers, schemas, changesets, LiveView, routes
  testing:
    file: backend/testing.md
    description: ExUnit testing conventions — organization, naming, assertions, doctests, async
```
