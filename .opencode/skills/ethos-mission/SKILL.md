---
name: Ethos Mission
description: Create and run a bounded Ethos worker/evaluator mission for implementation, design, review, or acceptance work in points. Use when delegating a task with explicit inputs, write set, success criteria, evidence, and correction rounds, or when the user asks to dispatch/pair workers and evaluators. Leader-only; do not use for casual exploration.
---

# Ethos mission

## Decision framework

Use a mission when one bounded graph node has a clear artifact, admissible write
set, observable criteria, one worker, and one independent evaluator. Decompose
epics first. Do not dispatch exploratory research that has no concrete output.

Select worker and evaluator from the map in `docs/WORKFLOW.md`. They must be
distinct. Evaluators are restricted to `gstack-architect` and
`gstack-reviewer`, both on preferred Bedrock OpenAI models. Never use
open-weight `gstack-qa` as evaluator; create a separate Bedrock OpenAI evaluator
if the map lacks the required expertise.

Build the contract from the active Bead and cited artifacts:

- one purpose and output;
- exact inputs and repository-relative write set;
- criterion-level pass/fail evidence requirements;
- bounded correction rounds;
- selected worker and evaluator.

Use the Ethos MCP mission tool when available. Use `ethos mission --help` for
CLI-only operations rather than copying command syntax. After dispatch, spawn
the named OpenCode subagent separately, verify it started, and have it read the
stored contract. Project specialists cannot mutate Ethos: the worker returns a
structured round result to the leader, who records it in Ethos with the worker
as author. The worker does not author a reflection. After independent review,
the evaluator returns the round reflection/verdict to the leader, who records it
with the evaluator as author. Evaluator `stop` means the leader may accept and
close, `continue`/`pivot` permits a correction advance, and `escalate` returns
the decision to the operator. This ordering prevents a worker's terminal
reflection from making later evaluator findings impossible to correct. Accept
only observable evidence. Keep result, evaluator reflection, and closure in
Ethos; do not create a second checks file.

## Prerequisites

Confirm `ethos doctor` is clean, the gstack team resolves, and the active Bead
has acceptance criteria. The primary `build` agent owns dispatch and lifecycle;
children cannot delegate.

## Resources

- Canonical mission contract and pairing map: `docs/WORKFLOW.md`
- Deposited operational guide: `.punt-labs/ethos/CLAUDE.md`
- One-time setup and recovery: `.punt-labs/ethos/ETHOS-SETUP.md`
