---
name: Incremental Delivery
description: Decompose epics and substantive features into spikes, a walking skeleton, and thin end-to-end product increments with unit, integration, and real-entry-point evidence. Use before creating or restructuring Beads, planning implementation, dispatching a feature mission, or whenever proposed work is organized by modules/layers, a large diff may accumulate before it runs, integration is deferred, or the user asks for slices, XP, Agile, spikes, test pyramids, or incremental delivery.
---

# Incremental delivery

## Principle

Prefer a narrow running system over completed horizontal layers. A slice is one
operator-visible behavior through the real entry point and every architectural
seam needed to deliver it. Modules are supporting boundaries extracted and
hardened as slices prove their shape; they are not the default delivery order.

## Decompose

Before implementation or mission dispatch:

1. State the operator outcome: what becomes possible after this increment?
2. Name the highest product, architecture, integration, operational, or security
   uncertainty.
3. Use a spike only when an experiment is cheaper than committing to a design.
   Record its question, timebox, experiment, evidence, decision, and whether its
   code is discarded. A spike closes with knowledge, not hidden production code.
4. Define the walking skeleton: the thinnest production-quality path through the
   real CLI/API/UI, core decision, adapter, persistence/write boundary, and
   observable result.
5. Order later slices by user value and risk retired. Each must merge, run, and
   be independently demonstrable.
6. Link horizontal work to the slice that needs it. Defer abstractions justified
   only by hypothetical future slices; extract common modules after concrete
   cases demonstrate them.

## Required slice contract

For every product-slice Bead, record:

- **Outcome and demo:** exact operator command/flow and observable result.
- **Scope:** one supported happy path and the most important adjacent failure;
  explicit omissions prevent accidental platform-building.
- **Seams exercised:** real components crossed; do not mock away the risk the
  slice exists to test.
- **Risk retired:** why integrating this now changes what the team knows.
- **Test pyramid:** many focused unit cases, fewer real-boundary integration or
  contract tests, and at least one installed-artifact end-to-end test through the
  public entry point. Add real-system smoke evidence when the boundary requires
  it.
- **Execution evidence:** commands and results. Compilation, mocks, snapshots,
  or worker confidence alone do not prove integration.
- **First-running checkpoint:** get the thinnest path green early; report the
  current working-tree state, command, last successful run, and any bypassed
  seam. After review, the leader creates the corresponding green commit.
- **Merge boundary:** one reversible PR, integrated before widening the feature.

Supporting module, documentation, design, and configuration Beads use
proportionate acceptance criteria for their artifact and the slice they support;
they do not invent an installed-product demo. Spikes use the question/evidence/
decision/code-disposition contract above instead of this product-slice contract.

## Detect bad decomposition

Stop and reshape work when it proposes:

- completing core, catalog, writers, backends, then integrating;
- implementing all interfaces or abstractions before one real workflow;
- a large body of code that has never run through the shipped entry point;
- mocked module tests while adapters remain disconnected;
- one integration PR after many module PRs;
- calling compilation, serialization, or unit tests “end to end”;
- a spike quietly becoming production architecture;
- a skeleton that bypasses the riskiest seam.

## Relationship to points workflow

`docs/WORKFLOW.md` owns Beads, Ethos, PR, and evidence lifecycle. Use this skill
to shape its delivery units: slice Beads are primary; module Beads support or
harden them. `docs/TESTPLAN.md` owns the pyramid's detailed test boundaries, and
`docs/spec/points.target.spec.tex` remains authoritative for modeled behavior.
