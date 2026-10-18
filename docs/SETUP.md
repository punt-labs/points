# points — development setup

This is the canonical post-clone procedure for developing `points`. Run every
command from the repository root. The supported agent harness for this workflow
is OpenCode 2 and it is the default harness for daily work;
`opencode --version` must report `v2.x`. Claude Code, Pi, and Codex remain
occasional compatibility surfaces. Configuration ownership and precedence are
documented in `docs/opencode/07-config-precedence.md`.

The repository commits shared policy and configuration. A clone must still
create local Git hooks, approve direnv, start user services, and resolve its own
credentials.

## Prerequisites

Install these commands before continuing:

- `direnv`
- OpenCode 2 (`opencode`)
- Go at the version declared in `go.mod`
- `bd`, `ethos`, `quarry`, `lux`, `biff`, `vox`, and `beadle-email`
- Node.js 22 or newer and `npx` for the Brave Search MCP
- `gh` and `qodo`
- `make`, `markdownlint-cli2`, and optionally `staticcheck`

Verify the important versions and authentication:

```sh
opencode --version
go version
gh auth status
qodo --version
```

Install the project's pinned Go and workflow linters:

```sh
make tools
```

This also installs the pinned `gopls` used by the project-scoped OpenCode Go
diagnostics. The LSP and formatter decision is documented in
`docs/opencode/14-lsp-formatters-diagnostics.md`.

OpenCode 1 and 2 both install as `opencode`. If the first command reports
`v1.x`, upgrade explicitly and restart OpenCode:

```sh
opencode upgrade --major
```

## 1. Environment

Copy the canonical environment from the Punt Labs meta-repository, then approve
it for this checkout:

```sh
cp ../.bin/envrc-canonical.template ./.envrc
direnv allow
direnv exec . env | grep '^BEADS_DOLT_SERVER_HOST='
```

`.envrc` supplies the hosted Beads connection, resolves contributor secrets,
sets the repository-local `.tmp/` directory, and loads the gitignored
`.envrc.local` last. Never put credentials in committed configuration.

## 2. Beads

The committed `.beads/` metadata uses the `points` issue prefix. Verify the
OpenCode integration and hosted Dolt connectivity:

```sh
bd setup opencode
bd setup opencode --check
bd ready --json
bd list --status open --json
```

The expected issues carry the `repo:points` label. A Dolt timeout is a service
or network failure, not permission to use another issue tracker; retry after
connectivity is restored.

## 3. Ethos and the gstack team

Enable Ethos to install or refresh its per-clone Git hooks:

```sh
ethos enable
ethos doctor
ethos whoami
```

This project uses the vendored `gstack` team. Check the committed repository
selection in `.punt-labs/ethos.yaml`:

```yaml
agent: claude
team: gstack
active_bundle: gstack
```

If that selection is missing, run the interactive setup from a terminal:

```sh
ethos setup --bundle gstack
```

For non-interactive automation, pass `--file <identity.yaml>` as documented by
`ethos setup --help`; do not commit the identity input file. Verify the result:

```sh
ethos team show gstack --json
ethos doctor --json
```

`ethos enable` is intentionally safe to rerun. Restart OpenCode after upgrading
or reinstalling Ethos so its MCP process uses the new binary.

Run the deterministic configuration gate after editing project instructions,
agents, MCP configuration, or Ethos pairing policy:

```sh
make check-dev
```

Run the live workstation check after service or credential changes:

```sh
make doctor
```

## 4. Enable repository tools

These commands create or refresh reviewed repository markers and local runtime
hooks. They are idempotent unless the command reports otherwise:

```sh
lux enable
biff enable
vox enable
beadle-email enable
```

Commit reviewed shared markers, deposited compatibility guides, and the Biff CI
workflow they produce. OpenCode project policy belongs in `AGENTS.md`; deposited
`CLAUDE.md` files and `@file` imports do not configure OpenCode V2. Do not commit
`.envrc.local`, credentials, service state, or files ignored by `.gitignore`.
Git hooks and user services are per-clone even when their enabling marker is
committed.

Quarry may already cover this checkout through a registered parent directory.
Inspect registrations first:

```sh
quarry --json list registrations
```

If a parent such as `/home/<user>/Coding/punt-labs` is registered, do not add a
duplicate child registration. Otherwise enable this checkout:

```sh
quarry enable .
```

Run the tool health checks:

```sh
ethos doctor
quarry doctor
lux doctor
biff doctor
vox doctor
beadle-email doctor
```

## 5. OpenCode 2 MCP servers

The committed `opencode.json` uses OpenCode 2's native `mcp.servers` structure.
Servers set `disabled: false`; Quarry uses separate catalog and execution
timeouts because loading its local index can exceed the default.

The configured servers are:

| Server | Transport | Endpoint |
| --- | --- | --- |
| `ethos` | local stdio | `direnv exec . ethos serve` |
| `quarry` | local stdio | `direnv exec . quarry mcp` |
| `biff` | local stdio | `direnv exec . biff mcp` |
| `vox` | local stdio | `direnv exec . vox mcp` |
| `beadle` | local stdio | `direnv exec . beadle-email serve` |
| `lux` | streamable HTTP | `http://127.0.0.1:8430/mcp` |
| `context7` | streamable HTTP | `https://mcp.context7.com/mcp` |
| `brave-search` | local stdio | `npx -y @brave/brave-search-mcp-server` |

Lux is not a stdio MCP. Its `luxd` Hub must be running on port 8430:

```sh
lux hub status
# Run only when status reports that the Hub is stopped:
lux hub start
```

After changing `opencode.json`, enabling a tool, or reinstalling an MCP CLI,
quit and restart OpenCode. Configuration and MCP processes are loaded at
startup, not hot-reloaded.

Context7 reads `CONTEXT7_API_KEY` from the canonical `.envrc` secret lookup and
sends it as a bearer token. The committed config contains only an environment
reference, never the credential.

Brave Search reads `BRAVE_API_KEY` from the same canonical environment. On
Linux the key lives at `pass show brave/api-key`; on macOS it uses the
`BRAVE_API_KEY` Keychain service. The separate `~/.local/bin/brave-search`
wrapper uses the same environment-first, platform-secret fallback and does not
print the key during normal search operation.

Do not run the official MCP server with `--help` while `BRAVE_API_KEY` is set:
version 2.1.4 renders the environment-derived key as an option default. Rotate
the key if it is exposed in terminal or agent logs.

Verify the native resolved config and all eight connections:

```sh
opencode debug config
opencode mcp list
```

Expected MCP status:

```text
✓ beadle  connected
✓ biff    connected
✓ brave-search connected
✓ context7 connected
✓ ethos   connected
✓ lux     connected
✓ quarry  connected
✓ vox     connected
```

MCP servers initialize asynchronously. After a restart or config change, allow
the local servers time to load before treating a partial list as a failure; run
`opencode mcp list` again after startup settles.

The project gives MCP initialization a 120-second startup budget and a
60-second catalog budget. OpenCode's 30-second startup default is too short when
multiple active locations cold-start separate local MCP process sets at once;
late initialization responses then appear as unknown request IDs after the
original connection has already timed out. Preserve the explicit V2
`mcp.timeout.startup` setting rather than relying on legacy scalar timeout
normalization.

Protect the shared local service with the pass-backed password procedure in
`docs/opencode/12-server-clients.md`. An unauthenticated `/api/info` request must
return HTTP 401 while normal OpenCode CLI and Desktop clients continue to work.

Also call Lux's MCP `ping` tool from the agent session. A CLI `lux status` check
only proves that the display process exists; MCP `ping` proves the agent can
reach the Hub tool surface.

### MCP troubleshooting

- **Most or all local stdio servers fail together:** run `direnv status` first.
  OpenCode launches them with `direnv exec .`; after `.envrc` changes or a fresh
  checkout, run `direnv allow` before restarting the service. Remote Context7
  and Lux may connect while every local server times out, which is a strong
  signal that repository environment authorization is missing.
- **A server is absent:** confirm `opencode debug config` includes the project
  document `opencode.json` and its `mcp.servers`, then restart OpenCode from the
  repository root.
- **Inspecting loaded config:** never print or save raw `/api/config`; provider
  substitutions may contain resolved credentials. Pipe directly to a narrow
  `jq` projection and emit only the non-secret fields required for diagnosis.
- **Context7 fails authentication:** confirm `CONTEXT7_API_KEY` is non-empty in
  `direnv exec . env` without printing its value, then verify the secret-store
  entry documented by the canonical `.envrc`.
- **Brave Search fails authentication:** confirm `BRAVE_API_KEY` is non-empty
  without printing it. On Linux, store it with `pass insert brave/api-key`; on
  macOS, use the `BRAVE_API_KEY` Keychain service.
- **A local server fails:** run its command from `opencode.json` manually with
  `direnv exec .`, then run that tool's `doctor` command.
- **Quarry reports `mcp.server.mcpserver` missing:** its installed uv environment
  has MCP 1.x while Quarry requires MCP 2.x. Refresh it with
  `uv tool upgrade punt-quarry`, then restart OpenCode.
- **Lux is absent or disconnected:** run `lux hub status`; the configured URL
  assumes port 8430. Start or repair the Hub before restarting OpenCode.
- **An upgraded MCP behaves like the old version:** restart OpenCode. Existing
  MCP child processes continue running the binary image with which they started.

## 6. Build and verify

### OpenCode agent exemplars

The committed `.opencode/agents/` files are hand-authored OpenCode 2 exemplars
for the six Ethos `gstack` specialists. OpenCode derives each agent ID from its
filename, which must exactly match the Ethos handle; native V2 files deliberately
omit the legacy `name` frontmatter key. OpenCode's built-in `build` agent remains
the default primary orchestrator. The specialists use role-specific
Bifrost models and cannot delegate. Preferred assignments use explicit Bedrock
OpenAI routes; QA exercises Bedrock GPT-OSS 120B as an open-weight model. All
except `gstack-implementer` are
read-only.

OpenCode 2 moved the top-level V1 `subagent_depth` field to
`experimental.subagent_depth` (default `1`), which caps subagent nesting by
walking the `parentID` chain. The exemplar leaves it at the default and does not
rely on the cap alone: every specialist runs on a deny-all permission baseline
with no `subagent` grant, so a specialist cannot delegate regardless of depth.
See `docs/opencode/11-background-concurrency.md` for the full concurrency model.

These files are temporary authored sources until Ethos can generate OpenCode 2
agents. Future generation must flow from the Ethos registry to
`.opencode/agents/`; Ethos must never infer configuration by parsing these
generated targets.

After changing an agent file, restart OpenCode, then verify the resolved roster.
Do not use `opencode reload` for this workflow: reloading can disconnect local
MCP child processes in the running session.

```sh
opencode debug agents
```

The roster must include `gstack-architect`, `gstack-implementer`,
`gstack-reviewer`, `gstack-qa`, `gstack-security`, and `gstack-product` as
subagents while `build` remains the default primary agent. The Quarry-first
`researcher` is an active subagent with scoped local, MCP, and web research
access.

Smoke-test each specialist through OpenCode's real agent execution path after
changing generation or model assignments. Give each test a read-only task and
require a unique sentinel, for example:

```sh
opencode run --agent gstack-architect \
  "Read README.md; reply ARCHITECT_OK and the authoritative spec path."
opencode run --agent gstack-implementer \
  "Read go.mod; reply IMPLEMENTER_OK and the module path. Do not edit."
opencode run --agent gstack-reviewer \
  "Read Makefile; reply REVIEWER_OK and the quality gate command."
opencode run --agent gstack-qa \
  "Read cmd/points/main_test.go; reply QA_OK and the test function."
opencode run --agent gstack-security \
  "Read .gitignore; reply SECURITY_OK and the local secret override."
opencode run --agent gstack-product \
  "Read README.md; reply PRODUCT_OK and whether points is a proxy."
```

Confirm all six sentinels and check `git status` afterward. The implementer has
edit permission by design, so its smoke prompt must explicitly forbid edits.

## 7. Build and verify

Run the full local gate and the installed binary smoke test:

```sh
make build
make check
./points --help
```

`make check` runs pinned `golangci-lint` (including `govet`, `staticcheck`,
`unused`, `errcheck`, `ineffassign`, `misspell`, and `gocyclo`), a Go format
diff, race-enabled uncached tests, Markdown lint, and `actionlint`. It must
finish with zero errors before review or commit.

## 8. Optional Bazel verification

`MODULE.bazel` and `BUILD.bazel` are scaffolded but not yet verified. After
installing Bazelisk:

```sh
bazel run //:gazelle
bazel build //...
bazel test //...
```

Track completion in Beads rather than adding a Markdown task list.
