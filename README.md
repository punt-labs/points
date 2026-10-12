# points

> Configure how AI coding harnesses route to model sources.

[![License](https://img.shields.io/github/license/punt-labs/points)](LICENSE)
[![CI](https://img.shields.io/github/actions/workflow/status/punt-labs/points/ci.yml?label=CI)](https://github.com/punt-labs/points/actions/workflows/ci.yml)
[![Go Reference](https://pkg.go.dev/badge/github.com/punt-labs/points.svg)](https://pkg.go.dev/github.com/punt-labs/points)

`points` is a planned CLI for configuring Claude Code, Codex, Pi, and OpenCode
to route through an operator-selected source such as Bifrost, a direct vendor,
or OpenRouter. It writes static configuration and exits; it is not a proxy or
daemon.

**Status:** pre-release scaffold. Help and version output work. Routing commands
are not implemented yet. The sections marked **Target experience** use a Working
Backwards format: they describe the intended user experience defined by the
verified specification, not functionality available in the current binary.

**Platforms:** macOS and Linux.

## Current Quick Start

Go 1.26 or newer is required while the project is in source-only development.

```bash
make build
```

```bash
./points --help
```

The current binary reports unimplemented routing commands with exit status 2.
Binary releases and an installer will be added when the functional CLI is
ready.

## Target Experience

The operator selects one source and default model per harness. `points` owns the
session-wide endpoint, authentication, and default. User-authored agent model
choices remain untouched.

```text
points route claude codex --source bifrost --model anthropic/claude-sonnet-5
points status
points verify
```

The target guarantee is routability: the configured source serves the selected
model's protocol and authentication mode. The operator can inspect and verify
the resulting state without reading several harness-specific files.

## Target Commands

The following commands are specified but not yet implemented:

| Command | Intended behavior |
| --- | --- |
| `points route <harness...>` | Select a source, default model, and authentication mode |
| `points status` | Show each harness's source and default model |
| `points verify` | Check protocol, authentication, and upstream routability |
| `points list --source <source>` | List providers served by a source |
| `points unroute <harness...>` | Restore vendor-direct defaults |

## Design

The target design is formalized in Z and reviewed separately from the Go
scaffold. The central decisions are:

- Routing is session-wide per harness; per-agent model selection is user-owned.
- The program writes configuration and does not enter the request path.
- Sources are selected per harness, with no precedence or overlap rules.
- Delivery backends may inject environment variables, while harnesses that
  require files always receive native configuration files.

## Documentation

[Target specification](docs/spec/points.target.spec.tex) |
[Architecture](DESIGN.md) |
[Test strategy](docs/TESTPLAN.md) |
[Development workflow](docs/WORKFLOW.md) |
[OpenCode diagnostics](docs/opencode/14-lsp-formatters-diagnostics.md) |
[OpenCode permissions](docs/opencode/02-permissions-safety.md) |
[OpenCode models](docs/opencode/03-models-routing.md) |
[OpenCode skills](docs/opencode/05-skills.md) |
[OpenCode instructions](docs/opencode/06-instructions-context.md) |
[OpenCode config](docs/opencode/07-config-precedence.md) |
[OpenCode plugins](docs/opencode/08-plugins-hooks.md) |
[OpenCode tools](docs/opencode/09-tools.md) |
[OpenCode sessions](docs/opencode/10-sessions-persistence.md) |
[OpenCode concurrency](docs/opencode/11-background-concurrency.md) |
[OpenCode clients](docs/opencode/12-server-clients.md) |
[OpenCode worktrees](docs/opencode/13-worktrees-references.md) |
[Development setup](docs/SETUP.md) |
[Public release readiness](docs/PUBLIC-RELEASE.md) |
[Contributing](CONTRIBUTING.md) |
[Security](SECURITY.md) |
[Changelog](CHANGELOG.md)

## License

MIT
