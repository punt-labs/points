# points — Design

`points` configures AI coding harnesses to route through operator-chosen
sources. This document is the architecture overview; the authoritative,
machine-verified design is the Z specification in `docs/spec/`, and the
decisions are recorded as ADRs in `docs/adr/`.

## Thesis

`points` is a **routing config tool**. The operator selects, per harness, a
*source* to route through and a default model; the tool writes exactly that
configuration and exits. It is not a proxy or router process — see
[ADR-0002](docs/adr/0002-config-writer-not-proxy.md).

## The two axes

| Axis | Scope | Owned by |
|------|-------|----------|
| **Routing** (base URL, auth, source) | session-global per harness | `points` |
| **Model choice** (which model per request/agent) | per-agent, user-authored | the user |

Routing is session-global because no harness supports per-sub-agent base URL or
auth; every sub-agent of a harness shares one endpoint. Model choice is per-agent
and deliberately out of scope — see
[ADR-0001](docs/adr/0001-routing-not-model-setting.md). The guarantee is
**routability**, not model-identity: every model whose provider the chosen source
serves reaches an upstream.

## Sources (multi-source)

A **source** is a route target: a gateway (Bifrost, Envoy, AgentGateway) that
serves many providers by fan-out, a direct vendor (Anthropic, OpenAI) serving one
protocol, or an aggregator (OpenRouter). The operator may have one source serving
everything (the single-gateway case) or several narrow ones with no gateway at
all. Each harness routes through exactly one source that speaks its protocol —
see [ADR-0004](docs/adr/0004-multi-source-per-harness-routing.md).

## The harness asymmetry

| Harness | Protocol | Config vehicle | Canonicalizes? |
|---------|----------|----------------|----------------|
| Claude Code | Anthropic | env (`ANTHROPIC_*`) + `modelOverrides` | yes |
| codex | OpenAI | `config.toml` + env | no |
| pi | OpenAI | `~/.pi/agent/*.json` (ignores env) | no |
| open code | OpenAI | `opencode.json` (ignores env) | no |

Claude Code concentrates nearly all the complexity (canonicalization, the
override map, tier aliases, the `[1m]` marker, the one legitimate subscription
credential path). The design quarantines that into a distinct concern so a change
to the OpenAI harnesses can never regress it and vice versa — see
[ADR-0006](docs/adr/0006-claude-code-quarantined-complexity.md) and the
`points.claude` / `points.fleet` split specs.

## Delivery backends

The core is a pure function `selection → per-harness config content`. Backends
*render* that content:

- **launcher-wrapper** — per-process env injection; drift-proof; preferred.
- **direnv / mise / nix** — shell/project env materialization.
- **file-writing** — universal core for pi/open code (and codex's provider table),
  independent of the env backend.

See [ADR-0003](docs/adr/0003-pluggable-delivery-backends.md).

## Visibility

`status`, `verify`, and `list` are first-class, not afterthoughts: the
predecessor's failures were silent config drift, so the tool must always be able
to show its state and confirm coherence. `verify` is the executable analogue of
the spec's routability invariant.

## Implementation

Go, single static binary — [ADR-0005](docs/adr/0005-go-single-binary.md).
Planned package layout is sketched in `internal/doc.go`. The formal spec is the
design source and the test-matrix source —
[ADR-0007](docs/adr/0007-formal-spec-as-design-source.md).

## ADR index

- [0001 — Routing, not model-setting](docs/adr/0001-routing-not-model-setting.md)
- [0002 — Config-writer, not proxy](docs/adr/0002-config-writer-not-proxy.md)
- [0003 — Pluggable delivery backends](docs/adr/0003-pluggable-delivery-backends.md)
- [0004 — Multi-source, per-harness routing](docs/adr/0004-multi-source-per-harness-routing.md)
- [0005 — Go, single static binary](docs/adr/0005-go-single-binary.md)
- [0006 — Claude Code's quarantined complexity](docs/adr/0006-claude-code-quarantined-complexity.md)
- [0007 — The formal spec as design source](docs/adr/0007-formal-spec-as-design-source.md)
