# OpenCode CLI and automation surface

## Command surface

`opencode <subcommand> [flags] [directory]`. The subcommands relevant to this
project's automation:

| Command | Purpose |
| --- | --- |
| `run` | Run a single message non-interactively; the automation entry point |
| `api` | Call the running server by OpenAPI operation ID or `METHOD path` |
| `session` | `list`, `delete`, `export`, `import` (see area 10) |
| `service` | `start`, `restart`, `status`, `stop`, `get`, `set`, `unset` the background server |
| `serve` | Start the v2 API and web server (`--hostname/--port/--cors/--stdio/--service`) |
| `debug` | `agents`, `config`, `paths` — read resolved state |
| `models` | List available models (507 in the current catalog) |
| `mcp` | `list`, `add`, `auth`, `logout` MCP servers |
| `auth` | `list`, `login`, `logout`, `export`, `import`, `switch` credentials |
| `reload` | Reload configuration |
| `pair` | Print one-time browser/app connect links |
| `upgrade` / `uninstall` | Update or remove OpenCode (area 18) |

There is no top-level `agent` subcommand: `opencode agent …` falls through to the
root help. List agents with `opencode debug agents`.

## Non-interactive runs

`opencode run [flags] <message…>` is the scripting entry point:

- `--format default|json` — `json` emits a newline-delimited stream of events,
  not a single JSON document. Each line has top-level `type`, `timestamp`, and
  `sessionID`; event-specific detail (including `messageID`, part `id`, and
  `time`) is nested under a `part` object and is not present on every event type.
  Parse it line by line (`jq -c`, `grep`) and read nested fields from `part`, as
  this audit did.
- `--session, -s <id>` continues (or creates) a specific session; `--continue, -c`
  continues the last; `--fork` forks before continuing.
- `--model`, `--agent`, `--title`, `--file`, `--thinking` select model/agent,
  title the session, attach a file, and surface reasoning.
- `--auto` auto-approves every permission that is not explicitly denied — see the
  automation-safety note below.

### Exit statuses

Verified behavior: `run` exits `0` on success and `1` on failure (unknown agent,
and other run failures). `api` exits `1` on an unknown path, and unknown flags
exit `1`. Automation can gate on a non-zero exit, but should not assume distinct
codes per failure class — treat non-zero as "failed".

Read the failure reason from the right stream for the format in use. With
`--format json`, a runtime failure is emitted to **stdout** as a JSON `error`
event (`{"type":"error",…,"error":{"message":…}}`) and stderr is empty, so parse
the stdout stream for the `error` event. In `default` format, read stderr.

## Server and service

`run`, `api`, and the clients all talk to one shared background server (area 12).
`opencode service` manages its lifecycle (`start`/`restart`/`stop`/`status`) and
holds service configuration (`get`/`set`/`unset`). `opencode serve` starts the
v2 API/web server directly; `--standalone` on any command runs a private server
instead of the shared one.

Restarting the service applies configuration that is only read at startup (for
example the maintenance-model change from area 15). A restart needs the MCP
environment (`direnv allow`), or the local MCP servers fail as a group (area 12,
`docs/SETUP.md`). Do not restart the shared service from inside an active working
session; schedule it between sessions.

## Reading configuration and resolved state

`opencode debug` is the trustworthy way to inspect what OpenCode loaded, rather
than inferring from the config files — but note what each subcommand returns:

- `debug config` — the **ordered configuration sources** as JSON, each with its
  path and contents, not a single merged/effective config. A higher-priority
  source can still override a global entry, so read it as "what each source
  declares," not "the effective value." In this repo the global source shows
  `default_agent: build` and the maintenance models
  (`title → bedrock/gpt-5.6-luna`, `compaction`/`summary → bedrock/gpt-5.6-terra`),
  confirming the area-15 title fix is present in that source.
- `debug paths` — `home`, `data`, `cache`, `config`, `state`, `tmp`, `bin`,
  `log`, `repos`, and `db` (`<data>/opencode.db`, the shared session store from
  area 10).
- `debug agents` — the resolved agent roster (this one is the effective result,
  after merging).

Prefer these over hand-parsing config when verifying an environment change, and
use `api` for structured session/state queries.

## Automation safety

Two surfaces are footguns in scripts and must be used deliberately:

- `--auto` disables interactive permission prompts and approves anything not
  explicitly denied. For this project the deny rules in `opencode.json` and the
  specialists' deny-all baselines still hold, but `--auto` removes the human
  `ask` gate (for example `git push`, `sudo`, network tools). Use it only in a
  trusted, sandboxed automation path, never as a default convenience.
- `opencode auth export` prints stored credentials **including secrets** as JSON.
  Never run it into shared output, a log, an issue, or a PR. It is a legitimate
  backup/migration tool, not a debugging command, and it reinforces the
  unredacted-output caveat from area 16.

Because tool and shell output is unredacted (area 16), non-interactive runs that
touch credentials can leak them into the JSON stream and the on-disk capture
files. Keep secrets out of commands and prompts, and gate credential-touching
automation behind explicit, reviewed scripts.

## Decisions

- Use `opencode run --format json` with line-by-line parsing for automation, and
  `opencode api` for structured session/state operations; both target the shared
  service.
- Gate automation on `run`/`api` exit status (`0` success, non-zero failure);
  do not depend on specific non-zero codes.
- Verify environment changes with `opencode debug config`/`agents`/`paths`, not
  by re-reading config files.
- Restart the service only between sessions, and only with the MCP environment
  loaded (`direnv allow`).
- Treat `--auto` and `auth export` as privileged: never default to `--auto`, and
  never run `auth export` into shared output.

## Runtime evidence

Enumerated the full CLI surface and probed behavior directly on OpenCode
v2.0.26: `run --format json` emits a JSONL part-event stream; `run`/`api` exit
`0` on success and `1` on unknown agent, unknown API path, and unknown flag;
`debug config` lists the global source with the corrected maintenance models
(including `title → bedrock/gpt-5.6-luna`); `debug paths` lists the data/config/
cache/state/db locations; `models` lists 507 entries; `service` and `debug`
expose the subcommands documented above. No configuration change was made in this
area.
