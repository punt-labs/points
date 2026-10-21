# Test Strategy

This document is the canonical test strategy for `points`. The authoritative
behavioral design is `docs/spec/points.target.spec.tex`; tests translate that
model into executable evidence at progressively wider system boundaries.

## Principles

1. **The specification defines the matrix.** Derive cases from the target Z
   specification's Test Template Framework partitions, not from implementation
   branches discovered after coding.
2. **Test the narrowest authoritative boundary first.** Pure domain behavior
   belongs in unit tests; representation belongs in writer tests; user outcomes
   belong in installed-binary and real-harness tests.
3. **Configuration snapshots are necessary but insufficient.** A valid-looking
   file does not prove a harness accepts it or that the intended upstream model
   serves the request.
4. **Failure is commit-aware.** Refusals do not mutate the namespace and
   pre-commit failures never publish a config. A publication that wins a race
   remains committed; durability, cleanup, backup, and reporting remain
   truthful rather than being reported as rolled back.
5. **Tests are deterministic.** Default tests do not call live vendors, depend
   on wall-clock timing, or share mutable home directories.
6. **Real integrations require real evidence.** Harness telemetry and
   wire-level evidence establish routing, not merely receipt of a response.
7. **Build the pyramid for every slice.** Each user-visible increment includes
   focused unit cases, fewer real-boundary tests, and an installed-binary flow.

## Traceability

Every modeled behavior follows this chain:

```text
Z operation or invariant → TTF partition → Go test case → implementation
```

Case names or adjacent comments identify the originating partition. A behavior
change updates the Z specification first, re-runs fuzz and ProB verification,
updates the partition matrix, and then changes tests and implementation.

## Slice 1 Formal Partitions

Slice 1 is the explicit-file OpenCode/Bifrost refinement in the target spec.
Every row requires table-driven pure and CLI cases where applicable; a named
operation or event boundary is not covered merely because it shares a public
error code with another row.

| Partition | Required coverage |
|---|---|
| `R-FIXTURE`, `R-INPUT` | Both exact models; same-provider unsupported model; missing, unknown, duplicate, conflicting, and invalid scalar flags; unsupported harness/source combination |
| `R-FILE`, `JSON.Strict` | Absent/readable/unreadable/malformed; wrong-type relevant containers; decoded duplicate keys; invalid encoding; comments, trailing data, multiple documents, non-object root |
| `R-FRAME`, `Conflict.Preservation` | Agents and maintenance pins, sessions, separate files, other providers, unrelated root fields, unselected metadata, and exact arbitrary numbers |
| `R-NORMALIZE-FINITE` | Every finite owned-leaf state; exact changed/conflict pointers; backup-trigger biconditional; native and certified registration distinction; retention and repair rules; protected sentinels unchanged |
| `R-SWITCH`, `Switch.AB` | A→B, B→A, A→A, endpoint change, unsupported request after success, and previous-registration retention |
| `Conflict.None` | Missing/canonical values, missing registration, and root-default-only changes without backup |
| `Conflict.Provider`, `Conflict.ModelVariant` | Every owned provider/model/variant overlay, inherited bypass, and selected registration correction |
| `Conflict.Headers`, `Conflict.Body` | Every named header, prefix, scope, and body-model override; unrelated leaves retained |
| `Backup.Exact`, `Backup.Secrets` | Original bytes and supported mode exactly; diagnostics never disclose original values or credentials |
| `Backup.Collision`, `Backup.LateCollision` | Every destination entry type; early refusal without mutation; late operational abort and identity-safe cleanup |
| `Path.Safe` | Unsafe ancestry, symlinks, owner/mode/ACL, hard links, special entries, missing parent, unsupported safe-operation semantics |
| `Write.StageFaults`, `Write.BackupFaults` | Every nonce/create/write/short-write/mode/access/file-sync/close/link/parent-sync/unlink boundary |
| `Write.CommitFaults`, `Write.PostCommit` | Rename/no-replace/revalidation failure; publication sync, cleanup, cancellation, and report failure after commit |
| `Write.CleanupDurability` | Visible deletion versus directory-synced deletion and permitted crash resurrection |
| `Cancel.Boundaries`, `Crash.Boundaries` | Early and post-local cancellation; every transaction boundary; publication race; pre-commit barrier; post-commit sync/cleanup; process death; paired crash choice |
| `Concurrency.Cooperating`, `Concurrency.External` | Lock contention; external target edit retained; replacement identity never deleted |
| `HTTP.Policy`, `HTTP.Redirect`, `HTTP.Bounds` | TLS, literal/mapped loopback, exact localhost, fresh consent, no redirect follow-up, deadline, body limit, no proxy/retry |
| `V-LOCAL`, `V-LIVE`, `V-COMBINE` | Every local state, live finding, ordered gate and not-run reason; no credential/request after blocking local failure |
| `V-TRUTH-TABLE` | Every cause-to-variant row; cancellation URL nullability; HTTP ranges; status/model nullability; report-failure precedence; total/exclusive producers |
| `Status.Scope` | Every local state; unmanaged success; explicit-file label; no network, effective-layer, session, or generation claim |
| `Output.Warning`, `Output.Contract`, `Output.EPIPE` | Every union/nullability/order/escaping/exit branch; warning cardinality; partial output and fallback diagnostic |
| `Repeat.NoOp` | Exact bytes, inode, mtime, and artifact count; irrelevant backup collision bypassed |
| `FS.Persistence` | Ordered delta subsequences; directory-sync outcomes; `FileImage` selectors; partial maps; finite reached-prefix alternatives with no future bytes |
| `FS.Identity` | Destination ownership, cleanup obligations, retained results, tombstones, replacement-safe discharge with persistent anomaly notes, and restart without authority |
| `FS.Transitions` | Fully framed phase-guarded operations; backup milestones; revalidation; commits; cancellation; cleanup inspection/sync; abort; process death; no operation from ended life |
| `FS.BackupAbort` | Abort after backup-ready; replacement; unlink plus failed cleanup sync |
| `FS.CrashImages` | Paired namespace/images, empty/partial/complete-unsynced stages, complete published config/backup, shared hard-link image |
| `Output.RouteProducer` | Every I1–I6, L1–L7, W1–W9, D1, C1–C5, X1–X4, and O1–O2 event and every parameterized operation |

### Route-producer combinations

Cover refusal plus reporting failure; no-op plus cancellation/reporting failure;
stage failure with successful and failed cleanup; backup-ready abort;
publication plus cancellation; config-sync failure followed by successful sync;
confirmed commit plus cleanup/report failure; independent refusal findings; and
early versus publication-time backup collisions. Assert the complete variant,
selection, commit/durability facts, backup, warnings, findings, residue, phase,
exit, and streams. A registry test fails for any unmapped producer event.

### Schema-negative matrix

Reject inconsistent commit/durability, warning, verification, credential,
cleanup, collision, selection, reporting, event, registration, cancellation,
revalidation, stage-image, and replacement-cleanup combinations. In
particular, reject future/unwritten crash bytes, transitions after ended life,
an inexact normalizer changed/conflict set, and any result discriminator that
disagrees with its independent facts.

## Test Layers

### Pure core

`internal/route` tests are table-driven and perform no I/O. They cover source
and harness compatibility, defaults, authentication, transitions, stable
refusals, deterministic output, observations, normalization/conflicts/frame,
registration/picker independence, route-event classification, result producer
properties, and unroute preconditions/effects.

### Harness writers and delivery backends

Tests use `t.TempDir()` and explicit dependencies. They assert decoded semantic
content, stable user-visible rendering, exact paths and artifact counts,
permissions, atomic replacement, durable backups, truthful commit outcomes,
preservation, idempotence, ownership/cleanup obligations, and crash-oracle
namespace/image pairing.

### Catalog, source, and verification integration

Injected clients and local servers cover discovery, timeout, cancellation,
authentication, malformed responses, exact request shape, redirects, retries,
proxy exclusion, deadline/body bounds, structured local/live findings, and
catalog membership. Default tests do not call live vendors.

### CLI, installed binary, and real harness

CLI tests cover arguments, help/version, exits, streams, human/JSON output,
noninteractive behavior, cancellation, and signals. Installed-binary tests use
isolated `HOME` and `XDG_CONFIG_HOME` and assert round trips, artifacts,
pre-/post-commit truth, and write confinement. Real-harness acceptance uses the
actual OpenCode configuration and correlated upstream telemetry; tests do not
override the root model or protected agent pins.

## Fault and Security Testing

Cover path traversal, symlinks, unsafe ownership/permissions, missing or
read-only parents, partial/interrupted writes, concurrency, hostile identifiers,
malformed files, cancellation, bounded network operations, and secret
redaction. Property and fuzz tests follow deterministic table coverage.

## Formal Verification Gate

`docs/spec/points.target.spec.tex` is authoritative. Run formal checks through
the named Make targets; `make spec` is fuzz type-checking and is not ProB
evidence. Record ProB identity, exact commands and valuations, explored
states/transitions, truncation status, reports, and witness/counterexample
traces. Deliberate completed/process-dead states are not erroneous deadlocks.

### Scenario A smoke gate

Run the bounded walking skeleton only through its named targets:

```sh
make test-spec-prob
make spec-prob-a-smoke
```

`test-spec-prob` covers malformed, missing, wrong-kind, and reordered source
markers; deterministic generation; missing and duplicate persistent state
assignments; missing checker verdicts; zero-state pseudo-success; checker
failure; timeout; interruption; and concurrent evidence-directory isolation.
`spec-prob-a-smoke` creates a unique run-owned directory beneath
`.tmp/opencode/`, independently regenerates and type-checks the model, asks ProB
for one concrete full-invariant initialization, and searches for one successful
accepted-write lifecycle witness. It rejects setup failure, zero-state output,
incomplete or duplicate valuations, incomplete inventories, missing goal
verdicts, timeouts, invariant failures, empty traces, and incomplete exports.

The smoke is intentionally not exhaustive evidence. It does not check M1/M2,
all operation coverage, all terminal branches, backup, crash,
external-disappearance, or normalizer/result refinement. Those partitions stay
deferred. `CheckCleanupAlreadyAbsent` remains excluded until the modeled
environment transition tracked by `points-yy5.1.4.1.1` exists.

The checked model has exactly 60 transaction fields plus 24 monitor fields, 31
wrapper operations, and six pending-delta slots. Its projection excludes the
unused routing carriers and has Scenario A carrier cardinalities of 1 JSON
pointer, 4 paths, 1 identity, 1 owner, 1 mode, 3 byte strings, 4 deltas, and 6
file images. `Invariant` includes `ScenarioAFilesystemSemantics`, `TxnSafety`,
and `MonitorSafety`; no operation assumes either safety predicate as a
postcondition. Exact commands, inputs, hashes, tool identity, generated model,
state graphs, and trace remain in the reported run directory.

The tracked generator supersedes the historical embedded prototype recipe.
Git history retains that provenance; the two named Make targets above are the
only supported harness entry points. The generator requires the authoritative
source markers' exact ordered identifiers and kinds.

## Slice 1 Test Placement and Incremental Gates

- `internal/route/opencode_test.go`: fixture/URL policy, observations,
  normalization/conflicts/frame, exact numbers/pointers, route producers.
- `cmd/points/main_test.go`: one case per event/boundary and public result,
  dependency fault injection, output and exits; no production fault flags.
- `internal/harness/transaction_test.go`: descriptors, locks, links, renames,
  sync ordering, identity ownership, syscall faults, and crash oracle.
- `internal/verify/opencode_test.go`: local TLS/HTTP/redirect fixtures, auth,
  bounds, proxy/retry, catalog, and consent.
- `tests/e2e/opencode_test.go` (`e2e`): installed binary workflows.
- `tests/acceptance/opencode_test.go` (`acceptance`): actual harness loading,
  tool turn, protected pins, and correlated identity.

Delivery remains one completed Slice 1 PR through bounded nodes: walking
skeleton; conflict/backup; observation/transport/output; failure/cleanup; actual
harness. Every node installs the current binary and reruns the connected path.

## Go Test Conventions

- Use table-driven tests and `t.Run` for input variations.
- Use `testify/assert` for result assertions and `testify/require` for
  preconditions once the approved dependency enters `go.mod`.
- Use `t.TempDir()` for filesystem tests and `t.Helper()` in helpers.
- Mirror source and test files where practical.
- Keep default tests free of live network and process dependencies.
- Use exactly one of `integration`, `e2e`, or `acceptance` on non-default test
  files; unit tests have no build tag.

## Quality, CI, and Coverage

Every default automated Go test invocation uses:

```text
go test -race -count=1 ./...
```

`make check` also runs pinned Go lint/format checks, Markdown lint, and
`actionlint`. CI runs the default suite on Linux and macOS; release CI adds
installed-artifact, tagged acceptance, real-harness, and distribution checks
when those suites exist.

`make coverage` is diagnostic, not a percentage merge gate. Completeness comes
from specification traceability, required partition tests, exact artifacts,
failure-path review, installed-binary workflows, races, and real-harness
evidence.

## Intended Layout

```text
internal/route/*_test.go        pure partition-derived behavior
internal/catalog/*_test.go      local HTTP and cache behavior
internal/harness/*_test.go      native config rendering and writes
internal/backend/*_test.go      delivery rendering
internal/verify/*_test.go       structured coherence findings
cmd/points/*_test.go            CLI contract
tests/acceptance/               tagged acceptance workflows
tests/e2e/                      tagged installed-binary workflows
tests/testdata/                 malformed and representative configs
```

The strategy is complete when the pure core proves the model, writer tests prove
the representation, installed-binary tests prove the product boundary, and
real-harness tests prove the generated configuration works in the systems it is
intended to control.
