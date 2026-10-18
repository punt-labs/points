# Project Instructions for AI Agents

This file provides instructions and context for AI coding agents working on this project.

## Project and Role

`points` is a public Go CLI that configures Claude Code, Codex, Pi, and OpenCode
to route through operator-selected sources. It writes static configuration and
exits; it is not a proxy or daemon.

The primary OpenCode `build` agent is the orchestrator. It decomposes work,
maintains specifications, dispatches bounded work to the gstack specialists,
evaluates evidence, and owns branches, staging, commits, pushes, pull requests,
and merges. Specialists return edits and evidence but never mutate Git. Delegate Go
implementation to `gstack-implementer`; do not bypass the worker/evaluator map
in `docs/WORKFLOW.md`. Open-weight models may work, but Ethos evaluators must be
separate agents on preferred Bedrock OpenAI models.

Treat discovered defects as work to resolve or track in Beads, not as a
"pre-existing" excuse. Stay within the active task unless the defect threatens
correctness, security, or completion; link follow-up work with `discovered-from`.

## Product Invariants

- `docs/spec/points.target.spec.tex` is authoritative. Make modeled design
  changes there first and re-verify before implementation.
- `points` owns routing and a default model, never user-authored per-agent model
  choices.
- Routing is per harness and may use Bifrost, direct vendors, or aggregators.
- File writing is universal; environment delivery backends apply only where a
  harness supports them.
- The specification partitions in `docs/TESTPLAN.md` are the test matrix.
- `DESIGN.md` and `docs/adr/` record architecture and tradeoffs.

`AGENTS.md` is the sole active OpenCode project-instruction authority.
`CLAUDE.md` is a compatibility pointer for other harnesses and must not carry a
second copy of project policy.

OpenCode V2 is the default development harness. Claude Code, Pi, and Codex are
occasional compatibility surfaces; do not let their configuration override or
duplicate OpenCode project policy.

## Issue Tracking with bd (beads)

Use Beads as the only task tracker; do not create Markdown checklists or a
second issue system. Use `--json` for agent-driven commands.

- Start with `bd ready --json` and atomically claim the selected issue.
- Record acceptance criteria and design context on substantive issues.
- Link discovered work with `discovered-from:<parent-id>`.
- Close completed work with an evidence-based reason; defer, supersede, or flag
  human decisions instead of leaving ambiguous status.
- Beads writes auto-commit to its Dolt database; do not manually maintain the
  passive `.beads/issues.jsonl` export.

Use `bd --help` and `docs/WORKFLOW.md` for command details and lifecycle policy.

## Session Completion

Before ending a work session: file remaining work, run applicable gates, update
Beads, commit the intended changes, pull with rebase, push, and verify the branch
is current with its remote. Do not leave completed work only in a local tree.


## Build & Test

```bash
make build
make check
make check-dev
make doctor
./points --help
```

`make check` runs pinned `golangci-lint`, a Go format diff, race-enabled
uncached tests, Markdown lint, `actionlint`, and development-policy checks. It
must pass before review or commit. Run `make tools` once to install the pinned
local linters. Run `make check-dev` after changing OpenCode, MCP, agent, Ethos,
or local development-environment configuration.

## Architecture Overview

`points` is a Go config writer, not a proxy or daemon. The authoritative design
is `docs/spec/points.target.spec.tex`. The planned implementation separates the
pure route calculation from source catalogs, per-harness writers, delivery
backends, and verification; see `internal/doc.go` and `DESIGN.md`.
Those are architecture boundaries, not the delivery sequence: evolve and harden
them through thin end-to-end increments.

## Conventions & Patterns

- Make design changes in the Z specification first, then re-verify and
  implement them.
- Keep routing and default-model configuration separate from user-owned agent
  model choices.
- Derive table-driven tests from the specification partitions.
- Use the `incremental-delivery` skill before decomposing epics or dispatching
  substantive feature implementation. Prefer spikes and thin running slices
  through the real CLI over completing horizontal modules before integration.
- Use the built-in OpenCode `build` agent as primary orchestrator and the six
  `.opencode/agents/gstack-*.md` specialists for delegated work.
- Treat specialist shell permissions as workflow guardrails, not security
  containment: write-enabled code can influence build/test execution. Keep
  secrets out of worker prompts/output and review every tool trace and diff.
- Treat `docs/SETUP.md` as the canonical OpenCode 2, MCP, and tooling setup
  reference.
- Follow `docs/WORKFLOW.md` for the Beads graph, Ethos mission loop, gstack
  worker/evaluator assignments, evidence gates, and return paths.
