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
| OpenCode | OpenAI | explicit OpenCode V2 JSON (ignores env) | no |

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

## Slice 1: explicit-file OpenCode routing

The first end-to-end slice deliberately supports only:

```text
points route --harness opencode --source bifrost --model MODEL \
  --config PATH --base-url ROOT [--allow-insecure-http] [--json]
points status --harness opencode --config PATH [--json]
points verify --harness opencode --config PATH \
  [--allow-insecure-http] [--json]
```

`PATH` and the deployment `ROOT` are explicit; there is no discovery or endpoint
override during verification. The exact initial fixture is
`bedrock/gpt-5.6-sol` and `openai/gpt-6-astra`. A same-provider model that is not
in that fixture is still unsupported. Route is offline, status reads the file
only, and verify combines local coherence with one bounded authenticated catalog
request.

### OpenCode V2 representation and ownership

The writer owns these route/default leaves:

- Root `model`, qualified as `bifrost/<model-id>`.
- `providers.bifrost.package`, using the OpenAI-compatible Responses provider.
- `providers.bifrost.env`, containing `BIFROST_VK`.
- `providers.bifrost.settings.baseURL`, derived as `<root>/openai/v1`.
- `providers.bifrost.settings.apiKey`, the literal `{env:BIFROST_VK}` reference.
- The selected `providers.bifrost.models.<id>` registration's `modelID`,
  `disabled`, and `capabilities.tools` leaves.

Registration is not a picker filter. Selecting B after A retains A's
registration, and the writer never invents cost, context, or variant metadata.
The normalizer removes route-affecting provider/model/variant overlays that
could bypass the selected endpoint or credential, but preserves unrelated
metadata and registrations. It also preserves all agents and maintenance-agent
model pins, sessions, history, permissions, MCP, other providers, unrelated
root fields, and arbitrary JSON numbers exactly. The tool does not certify
layered effective configuration or mutate separate agent files.

The normalizer is pure and returns the candidate plus sorted RFC 6901 changed
and conflict paths. Wrong-type relevant containers are errors, not permission to
replace user objects. A byte-identical no-op does not inspect an irrelevant
backup path and preserves bytes, inode, mtime, and artifact count.

For bounded checking, the formal normalizer uses a finite native-document
projection: owned leaves have absent/canonical/conflicting states, native
registration presence is separate from the certified managed registration
projection, and agents, maintenance pins, unrelated JSON, other providers, and
exact-number bytes are protected sentinels. Thus an unsupported or unselected
native declaration is retained without being certified as selectable, while an
existing selected declaration with a missing `modelID`, enabled, or tools leaf
is repaired. Its changed and conflict paths are extensional images of those
states, the backup trigger is an exact biconditional, and the post-state
establishes the coherent selected route. This abstraction does not reduce the
implementation's preservation duties for arbitrary JSON.

### Correctable conflicts and the commit boundary

An existing owned routing/registration value that normalization must change or
remove is correctable, not a refusal. Before committing such a candidate,
`points` preserves the exact original bytes and supported POSIX mode at:

```text
<config-path>.points.bak
```

The backup path is exclusive: any existing entry blocks a required backup and
is never followed, reused, rotated, truncated, or replaced. Root-default-only
changes and missing-field additions do not require a backup.

The ordered operation is:

```text
validate → observe → normalize → stage candidate
→ stage/link/sync backup when required → revalidate snapshot
→ atomically publish config → sync publication → clean transient names → report
```

Backup publication and config publication are separate directory entries; the
design does **not** claim atomicity across both. A required backup is complete,
file-synced, exclusively linked, directory-synced, and has its stage deletion
directory-synced before config publication is allowed. Existing config uses a
same-directory atomic rename; absent config uses exclusive hard-link
publication. Publication success is the commit point. Directory durability,
cleanup, and reporting are later and separately reported facts.

Before commit, cancellation or failure enters an abort phase that disables
staging, backup publication, revalidation, and config commit while still
permitting identity-safe cleanup and its directory sync. Config publication is
enabled only by an explicit successful revalidation milestone and an uncancelled,
running invocation. Process death and power loss are terminal. After commit
there is no automatic rollback: later cancellation does not suppress mandatory
durability confirmation or cleanup, and the result truthfully reports committed
state, confirmed or uncertain config durability, retained backup, warnings, and
cleanup residue. A conflicting commit transfers the backup from abort-cleanup
obligation to retained recovery result; later cancellation or errors never
authorize deleting it.

Ownership evidence and deletion permission are separate. Each transient name
has an active cleanup obligation; rename-source and successful-unlink deletions
remain tombstones until a parent-directory sync confirms absence. Cleanup
unlinks only the invocation-owned identity still present at a cleanup-due path,
never a replacement and never a retained config or committed backup. A
successful directory sync discharges the owned-identity obligation when that
identity is absent, including when a different identity now occupies the path,
but preserves the replacement/anomaly note for reporting. Process restart
inherits no cleanup authority.

The finite recovery model represents at most six pending indivisible namespace
deltas in explicit slots. A crash independently takes or skips each active slot
in order and then chooses one reached image per referenced identity. This avoids
an unbounded recursive powerset while retaining empty, partial, and full replay
choices. `FileImage` is an initial finite carrier whose total selectors are
bijective with bytes/mode/owner/content-state tuples; identity-to-image state is
written directly as partial functions rather than through a product alias. A
fresh stage begins with the unique empty image, and each write replaces its
finite dirty alternatives with exactly the actual byte prefixes reached so far,
never future intended bytes. Every lifecycle transition is fully framed and
running/phase guarded: stage create/write/sync/close, both backup directory-sync
milestones, explicit revalidation, existing/absent commit, cancellation,
identity-checked cleanup, sync success/failure, abort, process death, and paired
power loss. Final publication requires the complete synced intended image; a
backup additionally requires exact snapshot bytes, mode, and owner.

### Bounded formal-tool evidence

Formal checking uses cooperative, reviewed developer tooling behind named Make
targets. `make spec-prob` remains the assertion baseline for the complete target
document. `make spec-prob-a-smoke` is a narrower walking skeleton: a standard-
library generator copies the marked transaction library, supplies only the
finite Scenario A valuation and wrapper glue, and asks installed ProB for one
concrete initialization and one successful full-invariant lifecycle witness.
Each invocation owns a unique evidence directory under `.tmp/opencode/` and
records exact inputs, hashes, commands, tool identity, state graphs, and trace.

That smoke proves initialization and the existence of one required accepted-
write path. It does not claim exhaustive exploration, complete operation
coverage, mutation sensitivity, crash behavior, backup behavior, or refinement.
Those stronger evidence levels remain separate increments. Repository review,
deterministic regeneration, explicit verdict checks, positive state/transition
counts, and interruption cleanup address ordinary developer-tool failures; the
harness is not an adversarial capability or same-UID containment boundary.

### Filesystem and transport assumptions

The immediate parent must already exist and be safely owned. Descriptor-relative
operations reject symlink traversal, unsafe ownership/permissions/ACL effects,
hard-linked targets, special files, and unsupported no-replace or durability
semantics. Route holds a nonblocking exclusive parent lock from snapshot through
cleanup; read commands take a shared lock while snapshotting. Final
revalidation compares existence, identity, bytes, owner, link count, mode, and
supported access metadata. An external change is retained and reported rather
than overwritten or restored from a stale snapshot.

HTTPS and literal loopback HTTP are normal. Non-loopback HTTP requires fresh
`--allow-insecure-http` consent on every route or verify invocation. Consent is
never persisted, does not disable TLS checks, and does not enable redirects.
The verify client performs no redirect follow-up, retry, or environment-proxy
use; applies a ten-second total deadline and four-MiB decoded-body cap; and never
prints credentials, response bodies, or raw URL-bearing errors.

### Observation and verification limits

Raw decoded state is distinct from coherent state. Status can therefore report
absent, unreadable, malformed, unmanaged, incoherent, or coherent explicit-file
state. Unmanaged status succeeds without claiming coherence. Verify gates local
checks before credential access and network; it passes only if the explicit
file is coherent and an authenticated `/v1/models` response advertises the
exact selected token. This proves advertised availability at probe time, not
generation identity, agent/session behavior, plugin layering, or every retained
model declaration.

Public route/status/verify outputs are closed discriminated schemas with stable
finding and warning codes, deterministic ordering and nullability, explicit
not-run reasons, and exact exit mapping. Reporting failure never causes rollback
or turns partial JSON into success.

Their formal discriminators are derived from independent terminal facts. Route
findings are exactly the image of recorded typed events, and a committed route
without config-sync acknowledgement necessarily records the durability event.
That historical durability event remains recorded if a later successful cleanup
sync confirms the config; final durability follows the later acknowledgement.
Local/live causes determine complete URL/status/model truth tables: cancellation
before observation has a null catalog URL, while cancellation after local pass
and URL derivation retains the derived URL, and both expose the public
cancelled-before-request reason. Status and verify each have total,
pairwise-exclusive observed/refused/failed producers, so reporting failure cannot
retain a pass or refusal.

## Bounded Slice 1 delivery

The product work follows the accepted predecessor as five sequential bounded
missions in one end-to-end PR, not horizontal component deliveries:

1. A first installed route → status → live-verify path for both fixture models.
2. Conflict correction and exact recoverable backup.
3. Complete observation, transport, output, and route-producer contracts.
4. Failure, cancellation, identity-safe cleanup, and durability boundaries.
5. Actual OpenCode loading and correlated upstream/model identity evidence.

Each node keeps the real CLI connected through pure normalization, filesystem,
HTTP, and output seams; reruns the connected path when a seam changes; and
returns governing contradictions to the formal predecessor. Independent QA and
security review run against the exact candidate. Product Go remains blocked
until the formal predecessor is accepted with fuzz and ProB evidence.

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
