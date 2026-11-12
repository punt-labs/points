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

Treat discovered defects as work to resolve or track in Linear, not as a
"pre-existing" excuse. Stay within the active task unless the defect threatens
correctness, security, or completion; link follow-up work to its origin issue
with a Linear `related` relation and name the origin in the description.

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

## Issue Tracking

Linear is the tracker of record: the Punt Labs team, issues labelled
`repo:points`, listed in the shared `points` view. Epics are Linear projects
("points: implement the routing config tool (epic)" is the first). Beads
(`bd`) is a read-mostly local mirror; `.punt-labs/punt/CLAUDE.md` has the rules
for which tracker to write to, and `.beads/README.md` has the mirror commands
and the required `bd` build. Do not create Markdown checklists or a second
issue system. Use `--json` for agent-driven `bd` reads.

- Refresh the mirror, then start with
  `bd ready --label-any repo:points --exclude-label deferred --json`; claim the
  selected issue in Linear (state In Progress) and refresh its bead with a by-id
  pull (`bd linear sync --pull --issues <PL id> --team <id>`).
- Create issues in Linear with `repo:points` plus a type label (`Bug`,
  `Feature`, `Improvement`, `Epic`); record acceptance criteria and design
  context on substantive issues there.
- Link discovered work to its origin issue with a Linear `related` relation.
- Finish completed work in Linear (state Done, with an evidence-based comment),
  then refresh its bead with `bd linear sync --pull --issues <PL id> --team
  c1dfbb2c-985e-40cf-b004-5127646efc9d`; park work with the `deferred` label,
  supersede it, or flag human decisions instead of leaving ambiguous status. A
  local `bd update`, `bd close` or `bd create` is undone by the next pull of
  that issue (a local `bd create` instead leaves an orphan bead with no
  `external_ref` that no pull removes).
- Blockers are `blocks` relations in Linear, mirrored with `bd dep add <bead>
  <blocker>` when the refresh ran without `--relations`.
- Do not manually maintain the passive `.beads/issues.jsonl` export.

Use `bd --help` and `docs/WORKFLOW.md` for command details and lifecycle policy.

## Session Completion

Before ending a work session: file remaining work in Linear, run applicable
gates, write issue status in Linear and refresh each changed bead with a by-id
pull (`bd linear sync --pull --issues <PL id> --team
c1dfbb2c-985e-40cf-b004-5127646efc9d`), commit the intended changes, pull with
rebase, push, and verify the branch is current with its remote. Do not leave
completed work only in a local tree. There is no beads sync step.


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
- Follow `docs/WORKFLOW.md` for the Linear work graph, Ethos mission loop,
  gstack worker/evaluator assignments, evidence gates, and return paths.

## Issue tracking

Read `.punt-labs/punt/CLAUDE.md` before planning or writing to the issue tracker. Linear is the tracker of record where this repo is migrated. Beads is a local mirror there and the tracker of record elsewhere.
