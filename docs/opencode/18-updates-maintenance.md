# OpenCode updates and operational maintenance

## Update channels and automatic updates

OpenCode's update behavior is a single global config key, `update`, with three
values:

- `disable` — never update.
- `notify` — report when a newer version is available, but do not install.
- `auto` — install updates automatically.

A legacy `autoupdate: true | false | "notify"` is migrated to `update`. This is
user/global state (`~/.config/opencode/opencode.json`), not project state: the
project `opencode.json` must not own `update` (enforced by
`.bin/check-dev-config.sh`). This repo sets no custom service config
(`opencode service get` returns `{}`), so the installed default applies.

For a controlled development environment, prefer `notify` or `disable` over
`auto`: an unattended major upgrade can run database migrations (below) that make
the binary hard to downgrade. Take upgrades deliberately.

## Upgrading and rollback

`opencode upgrade [version] --method <curl|npm|pnpm|bun|yarn|vp|brew>` installs
the latest or a specific version through the chosen installation method. Because
the version is pinnable, "rollback" is just `opencode upgrade <older-version>`
with the same method — subject to the migration caveat below.

`opencode uninstall` (`--dry-run`, `--force`) removes the binary but **keeps
session data, configuration, and state**. Uninstalling and reinstalling does not
lose sessions, config, or the database.

The installed version here is OpenCode v2.0.26 (`opencode --version`).

## Database schema evolution

The shared database (`<data>/opencode.db`, from area 10) carries an ordered set
of migrations applied automatically at server startup:

- A `migration` table records applied migration ids; application is idempotent.
  A module-local semaphore serializes initializers **within one process**;
  cross-process serialization of normal starts comes from the managed-server
  protocol (one server at a time), not from the database lock. Running
  independent server processes against the same database could still race
  migrations.
- An empty database is bootstrapped to the current schema; an existing database
  applies only the migrations it is missing. Legacy Drizzle-journal installs are
  seeded into the new journal once.
- A dedicated v1→v2 migration path exists for databases from OpenCode 1.
- There are **49 registered migrations** and **no down-migrations**.

The operational consequence: migrations are **forward-only**. Upgrading applies
any new migrations on first start; **downgrading the binary below a migration
that has already run is unsafe**, because the old binary does not understand the
evolved schema. Before a major upgrade on a machine whose sessions matter, make a
true rollback copy: the database runs in SQLite **WAL mode**, so stop the service
(and any other process using the database) and copy `opencode.db` together with
its `opencode.db-wal` and `opencode.db-shm` sidecars — copying `opencode.db`
alone can omit committed data still in the WAL. Do not rely on
`upgrade <older-version>` alone.

## Restart, reload, and config application

Two mechanisms apply configuration changes, and they are not interchangeable:

- `opencode reload` reloads configuration into the running server. Use it for
  config edits the server can pick up live — but not for agent-file changes:
  `docs/SETUP.md` directs a restart after editing `.opencode/agents/*.md`,
  because reload can disconnect local MCP child processes in the running session.
- `opencode service restart` replaces the server process. Use it for changes
  read only at startup, and for agent-file changes. A restart needs the MCP
  environment loaded (`direnv allow`) or the local MCP servers fail as a group
  (area 12, `docs/SETUP.md`), and it must be run between working sessions, never
  from inside an active one.

The managed-server protocol admits one server at a time: a successor spawns only
after the previous process is confirmed dead, so a restart does not produce two
competing owners of the database (area 11).

## Recovery and health checks

On startup the server runs the boot recovery sweep from area 11: orphaned
executions resume under a durable per-turn attempt budget, running background
subagents resume, and running background shells are reported cancelled. Recovery
is at-least-once, so a tool side effect can repeat after a crash — prefer
idempotent long-running commands.

Health and drift checks for this environment:

- `opencode service status` — the server is up and reports its loopback URL.
- `opencode debug config` — the loaded configuration sources (area 17).
- `opencode debug agents` — the resolved agent roster; use it to catch agent
  drift after editing `.opencode/agents/*.md`.
- `opencode debug paths` — data/config/cache/state/db locations.
- `opencode mcp list` — configured MCP servers and their status; use it to catch
  MCP drift (a server that failed to start after a restart).
- `make doctor` — the workstation-only check of the active service and local
  toolchain. It is deliberately excluded from public CI (area 2 /
  `.bin/check-dev-config.sh`).

## Plugin and MCP drift

This project adds no external or custom OpenCode plugins; it runs on OpenCode's
built-in plugin surface only (area 8). Managed plugin drift is therefore not a
concern — `.bin/check-dev-config.sh` fails if the project config grows a
`plugins` key or experimental hooks — but an OpenCode upgrade can still change
built-in plugin behavior, which is another reason to take upgrades deliberately.
MCP servers are the moving part: after an upgrade or restart, confirm the roster
with `opencode mcp list` and that the expected set matches the eight servers the
dev-config check pins. A restart without `direnv allow` is the most likely cause
of a suddenly-missing MCP group.

## Decisions

- Keep OpenCode updates deliberate: use `update: notify` or `disable`, not
  `auto`, so migrations never run unattended. Take upgrades between sessions.
- Before a major upgrade on a machine with sessions worth keeping, stop the
  service and copy `opencode.db` with its `-wal` and `-shm` sidecars (WAL mode)
  as the rollback point; treat migrations as forward-only.
- Apply config changes with `reload` only for changes that are not agent-file
  edits; use `service restart` for agent-file edits and startup-only changes,
  always with `direnv allow`, and only between sessions.
- After any upgrade or restart, run the health checks (`service status`,
  `debug agents`, `mcp list`) to catch agent or MCP drift before working.

## Runtime evidence

CLI-verified on OpenCode v2.0.26: `upgrade` is version-pinnable with an explicit
`--method`; `uninstall` keeps data/config/state; `reload` and `service
restart`/`status`/`get`/`set` behave as documented (`service get` is `{}`).
Source-confirmed the forward-only migration model (49 registered migrations, a
`migration` journal table, startup application under a lock, a v1→v2 path, no
down-migrations) and the `update` config key (`disable`/`notify`/`auto`, with the
legacy `autoupdate` shim). No configuration change was made in this area.
