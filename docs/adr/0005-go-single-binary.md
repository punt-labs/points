# ADR-0005: Go, distributed as a single static binary

- Status: Accepted
- Date: 2026-10-10

## Context

`points` is a public, standalone system CLI whose job is frictionless
environment/config management, and which handles credentials (virtual keys, auth
tokens). The work is I/O-bound (fetch a catalog, parse/merge config, write files),
so raw performance is irrelevant; the decision is about distribution, dependency
friction, ecosystem fit, and authoring cost.

The closest precedents vote single-binary: **direnv is Go**, **mise is Rust** —
both ship as one static binary via brew/curl/release, no runtime. Nix is the
outlier (a C++ system installed by a script), but Nix is a *backend we target*,
not a model for how we ship.

## Decision

Implement `points` in **Go**, distributed as a single static binary
(brew / `go install` / release downloads).

Rationale over the alternatives:

- **vs. Node**: a tool that fixes your environment setup should not first require
  you to sort out a Node runtime. Go's native output is a dependency-free binary;
  Node's single-binary story is a bolt-on.
- **vs. Rust**: Rust's correctness edge (exhaustive `match`, `serde`) is real and
  relevant given the predecessor's edge-case failures, but the organization has
  many Go projects and zero Rust ones. A public, credential-touching product is
  the wrong place to also learn a new language. Rust's correctness is recoverable
  in Go with discipline + the spec-derived table-driven test matrix.

## Consequences

- Single static binary, cross-compiled; parity with direnv/mise distribution.
- Small, auditable dependency tree (matters for a credential-handling tool).
- The exhaustiveness Rust would enforce at compile time is enforced here by the
  Z spec's TTF partitions as a table-driven test suite (see ADR-0007).

## Build system note

The verified build is the **Makefile + Go toolchain**. **Bazel** scaffolding
(`MODULE.bazel`, `BUILD.bazel`) is present per a stated migration goal but is
**unverified** — bazelisk is not yet installed on the build host. A `bazel-verify`
bead tracks running `bazel run //:gazelle` + `bazel build //...` once it is.
