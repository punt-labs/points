# ADR-0007: the formal Z specification is the design source

- Status: Accepted
- Date: 2026-10-10

## Context

The predecessor broke repeatedly on edge cases that were discovered only when a
user hit them — there was no invariant being checked. Before reimplementing, the
design was captured as a formal Z specification, type-checked with `fuzz` and
model-checked with ProB, and put through two adversarial peer-review rounds that
found and closed real holes (a tautological "core guarantee," a weakened theorem
hypothesis, an operator-transposition bug that made an operation dead, and a
coverage gap where guarantees passed vacuously).

## Decision

The Z specification in `docs/spec/` is the **authoritative design source** for
`points`, and its TTF partition analysis is the **source of the test matrix**. The
implementation is written against it, not the other way round.

- `points.target.spec.tex` — the target design (multi-source routing tool).
- `points.current.spec.tex` — a faithful model of the predecessor (for contrast).
- `points.fleet.spec.tex` / `points.claude.spec.tex` — the two-concern split.

## Consequences

- Edge-case handling is enumerated up front (the spec's partitions:
  source-unreachable, missing credential, malformed config, non-Claude-to-Claude,
  partial tiers, …) and becomes the table-driven Go test suite — recovering in
  tests the exhaustiveness a dependently-typed language would give at compile time.
- Design changes are made in the spec first, re-verified (fuzz + ProB), then
  implemented.
- The spec ships in the repo as a deliverable, not internal scratch.

## Consequences to watch

- The spec and code can drift. Mitigation: the test suite is derived from the
  spec's partitions, and design changes go spec-first; a doc note in `DESIGN.md`
  points readers to the spec as source of truth.
