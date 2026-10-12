# Test Strategy

This document is the canonical test strategy for `points`. The authoritative
behavioral design is `docs/spec/points.target.spec.tex`; tests translate that
model into executable evidence at progressively wider system boundaries.

## Current State

The repository currently contains a CLI scaffold and one table-driven exit-code
test in `cmd/points/main_test.go`. The functional suites described below are the
required target as implementation proceeds. A layer is not considered present
until its automated tests exist and pass.

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
4. **Failure is non-destructive.** Every refused or interrupted operation must
   leave the prior configuration intact.
5. **Tests are deterministic.** Unit and default integration tests do not call
   live vendors, depend on wall-clock timing, or share mutable home directories.
6. **Real integrations require real evidence.** Acceptance of generated config
   is established by running the actual harness; model routing is established by
   harness telemetry and wire-level evidence, not by a response arriving.
7. **Build the pyramid for every slice.** Each user-visible increment lands with
   focused unit cases, fewer real-boundary integration or contract tests, and at
   least one installed-binary end-to-end workflow. Do not postpone integration
   and end-to-end evidence until all horizontal modules are complete.

## Traceability

Every modeled behavior follows this chain:

```text
Z operation or invariant → TTF partition → Go test case → implementation
```

Case names or adjacent comments identify the originating partition. A behavior
change updates the Z specification first, re-runs fuzz and ProB verification,
updates the partition matrix, and then changes tests and implementation.

The core matrix includes at least:

- Successful route and unroute operations
- Source unreachable
- Provider or model not served by the selected source
- Harness/source protocol mismatch
- Missing credential
- Authentication mode not accepted by the source
- Subscription authentication outside its entitlement
- Malformed existing configuration
- Non-Claude model selected for Claude Code
- Partial or incoherent Claude tier aliases and overrides
- Routable picker contents and rejection of unroutable choices
- Verification pass and structured verification failures

## Test Layers

### 1. Pure Core

`internal/route` computes configuration content from operator selection without
filesystem, environment, network, or process I/O. This is the largest and
fastest layer.

Table-driven tests cover:

- Source and harness compatibility
- Default-model and provider validation
- Authentication rules
- Route and unroute state transitions
- Claude canonicalization, overrides, background model, and tier aliases
- Stable refusal codes and structured details
- Deterministic output for identical input

Pure unit test files have no build tag and perform no I/O.

### 2. Harness Writers and Delivery Backends

Tests for `internal/harness` and `internal/backend` use `t.TempDir()` and explicit
dependencies. They cover Claude Code, Codex, Pi, OpenCode, launcher output,
direnv, mise, and Nix.

Assertions include:

- Exact decoded semantic content for JSON and TOML
- Stable rendered text where formatting is user-visible
- Exact generated artifact paths and counts
- Required file and directory permissions
- Atomic replacement and rollback after a staged failure
- Preservation of unrelated user configuration
- Removal of stale managed state without deleting user state
- Idempotence when applying the same selection twice

Golden files are appropriate only for final text representation. Semantic
behavior is asserted against decoded structures.

### 3. Catalog and Source Integration

`internal/catalog` tests use an injected HTTP client and `httptest.Server`; they
never depend on live Bifrost, OpenRouter, Anthropic, or OpenAI.

Cases include:

- Successful provider and model discovery
- Timeout and context cancellation
- Authentication failure
- Malformed or empty responses
- Source unavailable
- Cache hit, miss, expiry, and corruption
- Served provider with absent model
- Picker filtering and deterministic ordering

These service-boundary tests remain in the default suite when they use local
test servers. Tests requiring real external services use the `integration` build
tag and run in a separate CI stage.

### 4. Verification Engine

`internal/verify` returns structured findings consumed by human and JSON output.
Tests assert finding codes and fields rather than matching only prose.

The engine detects:

- Missing route state
- Disagreement among managed files and environment content
- Protocol or authentication incompatibility
- Unroutable defaults
- Missing or partial Claude aliases and overrides
- Malformed or stale managed configuration
- Unreachable upstreams

### 5. CLI Contract

`cmd/points` tests cover the public process boundary:

- Commands, arguments, and flag combinations
- Help and version output
- Stable exit statuses
- stdout versus stderr separation
- Human-readable and machine-readable output
- Non-interactive behavior when stdin is not a terminal
- Context cancellation and signal handling

The current `TestRunExitCodes` test pins only the scaffold contract. It does not
substitute for command behavior tests.

### 6. Interactive TUI

If the planned Huh-based wizard is added, it is a thin adapter over the same
route core. Tests cover form-to-request mapping separately from terminal
interaction.

Mapping tests cover harness, source, authentication, and model selections plus
cancellation. Terminal smoke tests cover keyboard navigation, validation
feedback, small terminals, non-TTY fallback, and interruption without writes.
No routing rule may exist only in TUI code.

### 7. Installed-Binary Acceptance

End-to-end tests build and execute the real binary as a subprocess in an
isolated temporary home:

```text
HOME=<temporary directory>
XDG_CONFIG_HOME=<temporary directory>
```

They drive complete user workflows through `points route`, `points status`,
`points verify`, and `points unroute`. Tests assert exit status, stdout, stderr,
the exact generated artifact set, configuration round trips, rollback, and the
absence of writes outside the isolated home.

Go files that drive the complete executable use the `e2e` build tag. Slower
acceptance criteria that do not represent a full executable flow use the
`acceptance` tag. Test types are not mixed in one file.

### 8. Real-Harness Acceptance

Selected release-gate tests run Claude Code, Codex, Pi, and OpenCode against the
generated configuration. They prove each supported harness accepts the output
and reaches the selected source.

A route-switch sequence is mandatory:

```text
route A → run harness → observe A → route B → run harness → observe B
```

For model-routing claims, ground truth is the actual outbound model/provider and
the harness's own usage telemetry. A successful answer alone is not proof that
the selected model served it. Claude tier aliases, background requests, and
OpenCode title or small-model requests are included because a working foreground
request can hide a failed side request.

Real-vendor tests are separately tagged and credential-gated. Missing credentials
produce an explicit skip in local runs and a hard failure in the release job
that promises to run them.

## Fault and Security Testing

Configuration writing is security-sensitive. Tests cover:

- Path traversal and symlink attacks
- Unsafe ownership or permissions
- Read-only and missing parent directories
- Interrupted and partial writes
- Concurrent invocations and lock behavior
- Hostile source, model, and provider identifiers
- Corrupt caches and malformed existing files
- Cancellation and bounded network operations
- Secret redaction in errors, status, verification, and logs
- Rollback when one operation in a multi-file update fails

Property and fuzz tests should target parsers, merge logic, path handling, and
state transitions after deterministic table coverage is in place.

## Go Test Conventions

- Use table-driven tests and `t.Run` for input variations.
- Use `testify/assert` for result assertions and `testify/require` for
  preconditions once the approved dependency enters `go.mod`.
- Use `t.TempDir()` for filesystem tests.
- Call `t.Helper()` in test helpers that report failures.
- Mirror source and test files where practical.
- Keep default unit tests free of live network and process dependencies.
- Use exactly one of `integration`, `e2e`, or `acceptance` on non-default test
  files; unit tests have no build tag.

## Quality and CI Gates

Every default automated Go test invocation uses:

```text
go test -race -count=1 ./...
```

`make check` additionally runs:

- Pinned golangci-lint with `govet`, `staticcheck`, `unused`, `errcheck`,
  `ineffassign`, `misspell`, and `gocyclo`
- Go formatting verification
- Markdown lint
- GitHub Actions lint through `actionlint`

CI runs the default suite on Linux and macOS. `govulncheck` runs on pull
requests, pushes to `main`, and weekly. Release CI adds installed-artifact,
tagged acceptance, real-harness, and distribution checks when those suites
exist.

## Coverage Policy

`make coverage` is diagnostic. There is no percentage merge gate. A percentage
does not demonstrate that important state partitions, refusals, and error paths
were tested.

Completeness is enforced through specification traceability, required tests with
new behavior, exact artifact assertions, review for omitted failure paths,
installed-binary workflows, race detection, and real-harness evidence.

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
