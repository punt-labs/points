# Development Workflow

This document instantiates the Punt Labs three-loop workflow for `points`. It
adapts bounded graph execution to the repositories and tools that already own
durable state. It does not introduce parallel graph, check, or progress files.

## The Loop

```text
Backlog loop (Beads)
  select one rollback-coherent unit
    PR loop (Git and GitHub)
      complete a reviewable, reversible change
        Mission loop (Ethos and gstack)
          contract → execute → evaluate → correct until accepted
```

The useful mechanics are bounded nodes, explicit inputs and outputs, independent
execution where safe, evidence-bearing gates, targeted return paths, and durable
resumption. The model is a graph, not one unbounded agent session.

## Authoritative State

Each fact has one owner:

| Concern | Authority |
| --- | --- |
| Work graph, dependencies, status, priority, next ready node | Beads |
| Intended state transitions and invariants | `docs/spec/points.target.spec.tex` |
| Executable acceptance matrix | TTF partitions and `docs/TESTPLAN.md` |
| Delegation contract, worker, evaluator, rounds, results | Ethos mission |
| Files and history | Git |
| Review and merge state | GitHub pull request |
| Architectural decisions | `DESIGN.md` and `docs/adr/` |

Do not create `graph.md`, `checks.md`, `progress.md`, Markdown task lists, or
another issue queue. Those would duplicate Beads, Ethos, or Git and immediately
create reconciliation work.

## Roles

- **Operator:** owns product direction, ratifies substantive design choices, and
  confirms user-facing demos.
- **Primary `build` agent:** leads the loop, maintains Beads state, creates Ethos
  missions, delegates work, verifies evidence, owns Git/GitHub operations, and
  never substitutes its own implementation for required specialist work.
- **Worker:** one gstack subagent that owns one bounded mission result.
- **Evaluator:** a different gstack subagent that checks the result against the
  contract and evidence.

The OpenCode specialist definitions live in `.opencode/agents/`. They deny
nested delegation; all except `gstack-implementer` are read-only. Ethos remains
the identity and mission authority. The hand-authored OpenCode files are the
exemplar for future Ethos generation.

## Backlog Loop: Beads as the Graph

Every non-trivial unit starts as a Beads issue with description, acceptance
criteria, design context, priority, and dependency edges. An issue is one
rollback-coherent result, not a department-sized phase.

Delivery units are thin end-to-end product increments, not horizontal modules.
Use the `incremental-delivery` skill before creating or restructuring a feature
epic. Slice Beads own demonstrable operator outcomes; module Beads may support or
harden a slice but do not form a core → catalog → writer → backend → integration
pipeline. A module dependency is added only when a current slice consumes its
result.

```text
intake → validate → split/link → claim → execute PR loop → close
```

### Entry

An issue may be claimed when:

- The need still exists on current `main`.
- Acceptance criteria describe observable completion.
- Dependencies and blockers reflect reality.
- The issue fits one pull request or has been decomposed into child issues.
- Any required design or formal-spec predecessor is explicit.
- A feature issue states the exact operator demo, real seams exercised, risk
  retired, unit/integration/end-to-end evidence, and explicit omissions.

### Spikes and walking skeletons

Use a timeboxed spike when uncertainty is too high to choose a slice safely. Its
output is evidence and a decision; discard its code by default. A spike records
the question, timebox, smallest experiment, evidence, decision, and code
disposition.

The first feature increment is a walking skeleton: the thinnest production
behavior through the public entry point, domain decision, real adapter or write
boundary, and observable result. It need not support every source, harness, or
failure partition. It must run, merge, and become the base that later slices
widen and refactor.

Use `bd ready --json` to choose unblocked work and `bd update <id> --claim
--json` to acquire it atomically.

### Parallelism

Independent ready issues may run in parallel only when their write sets do not
overlap. Use separate Git worktrees for concurrent writers. A dependency edge
exists only when one node consumes another node's output; ordering preference is
not a dependency.

### Exit

Close an issue only after its PR unit has passed local review and its applicable
acceptance evidence. User-visible product work also requires installed-artifact
verification and the operator demo; other work classes use the proportionate
checks named by their own criteria. If a PR is abandoned, reopen its closed
issue. New work outside the current rollback unit becomes a linked
`discovered-from` issue; defects inside the unit are fixed in the current PR.

## PR Loop: One Reversible Increment

One PR loop owns one branch and produces one mergeable result.

### 1. Establish the Baseline

Before changing the system:

- Run `make check`.
- Reproduce the current user-visible behavior or failure.
- Record the expected outcome in the Beads acceptance criteria.
- Read the governing Z operation, invariant, and TTF partitions.
- For user-visible product work, run the real public entry point for the current
  baseline, even when it only demonstrates a missing capability. Record the
  exact command and result. Documentation, design, spike, and configuration work
  instead reproduces the artifact or uncertainty it actually changes.

A broken baseline is evidence, not noise. Classify it before proceeding.

### 2. Choose the Workflow Class

| Work | Ethos pipeline | Required first node |
| --- | --- | --- |
| New user-facing feature | `product` | Product validation |
| Stateful routing or protocol behavior | `formal` | Z specification and model check |
| Multi-package feature | `standard` | Architecture design |
| Well-understood bounded fix | `quick` | Regression test and implementation |
| Repeated or unclear defect | `coe` or `gstack-debug` | Root-cause investigation |
| Documentation only | `docs` | Documentation design |
| Release readiness | `gstack-ship` | Full-diff review |

Use `full` when a change genuinely requires product, formal, implementation,
security, acceptance, and retrospective stages. Do not select a larger pipeline
to signal importance; select the smallest pipeline that contains the required
gates.

### 3. Execute Mission Nodes

Create and finish one bounded Ethos mission at a time unless nodes are provably
independent. Each mission follows the node contract below.

### 4. Full-Diff Gates

After accepted mission results accumulate:

1. Run `make check` on the complete diff.
2. Run `gstack-reviewer`; require zero material findings.
3. Run `gstack-security` when routes, credentials, config writes, dependencies,
   or trust boundaries changed.
4. Run `gstack-qa` against the user workflow and failure cases.
5. For user-visible product work, install or build the exact artifact being
   shipped and exercise it through its public entry point. Other work classes
   run the proportionate real check named by their acceptance criteria.
6. Ask the operator to confirm user-facing behavior where machine evidence is
   insufficient.

### 5. Ship

Push the branch, open the PR, and require all CI legs and review conversations to
clear. A changed commit restarts the gate. Merge only the verified unit, then
update Beads and return to the backlog loop.

### Automated PR review loop

Treat review as an iterative convergence loop, not a one-shot check. A normal
pull request takes two to six rounds:

```text
push → wait for CI + Qodo + Bugbot + Copilot
  → triage every finding and thread
  → fix real issues; explain and resolve non-issues
  → push the correction
  → wait for reviews of the exact new head
  → repeat until clean → merge
```

- **Qodo:** read authoritative structured state with `qodo read
  pr-review-session findings --pr-url <url> --json`. Act only on a completed
review whose commit SHA equals the current PR head. Resolve valid findings in
code; record dismissal only with explicit operator agreement.
- **Cursor Bugbot:** require its external check to pass and address any linked
  findings before the next push.
- **GitHub Copilot:** reviews drafts and every push through the repository
  ruleset. Require a completed review whose commit equals the current PR head,
  then resolve each material conversation after fixing it or documenting why no
  change is warranted.

Every push invalidates prior review freshness. Do not merge because an earlier
round was clean. The current head must have all required CI checks green, a
completed clean Qodo review, a passing Bugbot check, and no unresolved Copilot
or human review threads. Copilot must have completed review of that same head;
the absence of threads while its review is pending is not a pass. The ruleset
requires pull requests and thread
resolution but zero approving reviews; correctness comes from evidence and
closed findings, not an approval-count ceremony. This clean exact-head state is
the effective approval to merge even though GitHub records no required formal
approval.

Today, GitHub mechanically enforces required CI, Bugbot status, pull requests,
and thread resolution. The leader enforces exact-head Qodo and Copilot review
completion before merge because Qodo publishes a comment-only review rather
than a check context. `points-6ja` tracks a fail-closed `review-gate` check once
a scoped Qodo service credential is available; never put an unscoped personal
Qodo key in Actions.

## Mission Loop: Bounded Ethos Nodes

An Ethos mission is one graph node: one declared input set, one output, one
worker, one evaluator, and a bounded number of correction rounds.

### Node Contract

Before dispatch, record:

- **Purpose:** one outcome this node produces.
- **Inputs:** exact spec clauses, issue acceptance criteria, files, and prior
  mission results it consumes.
- **Output:** the artifact or decision returned to the leader.
- **Write set:** exact allowed paths; design missions may leave this open only
  when choosing the artifact structure is part of the work.
- **Check:** observable pass/fail conditions, including commands and required
  evidence.
- **Worker and evaluator:** distinct gstack handles.
- **Evaluator model:** a preferred Bedrock OpenAI model, never an open-weight
  model. Open-weight agents may work or provide experimental evidence, but may
  not issue the independent Ethos verdict.
- **Round budget:** maximum correction rounds before escalation.
- **For product-slice implementation nodes — slice evidence:** operator demo,
  seams crossed, risk retired, explicit omissions, and tests at unit,
  integration/contract, and installed-artifact end-to-end levels.
- **For product-slice implementation nodes — first-running checkpoint:** the
  first commit where the thin path ran, the current end-to-end command, its
  latest successful result, and every seam still mocked or bypassed.

Documentation, design, review, configuration, module-support, and spike nodes do
not fabricate product-slice fields. They provide observable evidence appropriate
to their own output; spikes use the question, experiment, evidence, decision,
and code-disposition contract above.

Pass only this context to the worker. Do not send the entire session transcript
when the contract and cited artifacts are sufficient.

### Execution

```text
create contract → spawn named subagent → verify it started
  → worker returns structured result/evidence to leader (no reflection)
  → leader records result in Ethos with worker as author
  → evaluator checks saved artifact and returns reflection/verdict to leader
  → leader records reflection in Ethos with evaluator as author
  → evaluator stop: accept/close
  → evaluator continue or pivot: advance/correct
  → evaluator escalate: return to operator
```

Project specialists intentionally lack Ethos mutation access. The primary
`build` leader persists the artifacts they author: worker result first, then the
independent evaluator's reflection after review. Reflections are append-only and
gate round advancement, so ordering and authorship are load-bearing. A
worker-authored `stop` reflection would preempt correction if the evaluator later
finds a defect and is therefore a workflow failure, not a harmless ordering
difference.

The leader correlates every persisted artifact to both the child session and the
mission contract. For long handoffs recovered from OpenCode, use
`.bin/extract-subagent-result.sh`; it selects the latest completed assistant text
by timestamp and refuses a result unless the exported session ID/agent and the
artifact's single leading `ethos-result` mission/round/author envelope match the
dispatch record. Include that exact envelope requirement in every worker and
evaluator prompt.
Array position, similar session IDs, and prose references to another mission are
not identity evidence.

Workers return saved edits, structured results, and exact check evidence. They do
not stage, commit, push, or otherwise mutate Git. The leader reviews the diff and
tool trace, runs the required checks independently, and owns branch creation,
staging, commits, pushes, PRs, review threads, and merges.
For product-slice implementation, workers get the thinnest real path running
early and rerun it whenever another seam is connected. Do not accumulate a large
body of code that has only compiled or passed isolated tests. Compilation,
mocks, snapshots, and unit tests do not count as integrated execution through
the shipped entry point. Other workflow classes run the smallest real check of
the artifact they change.

### Evidence Gate

A mission result is accepted only when every criterion has observable evidence:

```text
criterion | verdict: pass/fail/unresolved | evidence
```

Evidence is an exact command and result, file path, test name, generated
artifact, model-check report, or real-harness observation. A worker's claim and
an evaluator's confidence are not evidence by themselves. Missing evidence is
`unresolved`, never an inferred pass.

Ethos owns the durable contract, worker result, evaluator reflection, and audit
log. The leader does not copy them into a second checks file.

Specialist shell allowlists are workflow guardrails, not a security sandbox. A
write-enabled worker can change build/test inputs that approved commands execute.
Use isolated worktrees for writers, keep credentials out of prompts and output,
inspect tool traces for permission evasions, and independently review all edits
before the leader commits them. `make --eval`, `make -f`, inline recipes, and
other indirection that executes commands outside approved canonical targets are
permission bypasses and fail the mission.

OpenCode, Beads, Ethos, Circuit, Git, and GitHub retain their own identifiers and
state authority. Correlate them through OpenCode session metadata and explicit
contract/evidence fields rather than inventing one shared ID. See
`docs/opencode/10-sessions-persistence.md` for the mapping and PR head-SHA rule.

### Worker and Evaluator Map

| Node type | Worker | Evaluator |
| --- | --- | --- |
| Product scope and CLI ergonomics | `gstack-product` | `gstack-architect` |
| Architecture and package boundaries | `gstack-architect` | `gstack-reviewer` |
| Z spec and partition design | `gstack-architect` | `gstack-reviewer` |
| Go implementation and unit tests | `gstack-implementer` | `gstack-reviewer` |
| Installed-binary and real-harness acceptance | `gstack-qa` | `gstack-reviewer` |
| Credential and config-write security | `gstack-security` | `gstack-architect` |
| Documentation | `gstack-product` | `gstack-reviewer` |

The primary `build` agent is the leader, not a worker or evaluator. A worker
never evaluates its own result. The evaluator column is restricted to
`gstack-architect` and `gstack-reviewer`; both are pinned to preferred Bedrock
OpenAI models. Do not substitute `gstack-qa` or another open-weight assignment
as evaluator. Add a separate Bedrock OpenAI evaluator agent if a future node
needs evaluation expertise not represented by those two handles.

## Deterministic Work Stays Deterministic

Use code and tools for exact operations: sorting, merging, schema validation,
formatting, linting, model checking, test execution, artifact comparison, and
dependency queries. Use agents for judgment: product fit, architecture choices,
threat models, test adequacy, and review.

If a deterministic command can answer a question exactly, run it rather than
asking a model to estimate the answer. An agent may select and interpret a tool;
it must not replace the tool's computation with prose.

## Return Paths

Failures return to the node that introduced the failed condition:

- Spec inconsistency returns to the spec/design node.
- Implementation or unit-test failure returns to `gstack-implementer`.
- Missing acceptance evidence returns to `gstack-qa`.
- Security finding returns to the producing implementation or design node, not
  to an unrelated batch.
- Product mismatch returns to product/design before more code is written.

Each return records the failed criterion, evidence, and correction scope in the
Ethos reflection. The round budget is three by default. Exhausting it escalates
the decision to the operator; it does not waive the gate.

## Formal Classes

The following changes require the `formal` pipeline and model checking before
implementation:

- Route, unroute, and verification state transitions
- Source/protocol/authentication compatibility rules
- Claude alias and override coherence
- Multi-file atomicity, rollback, and concurrent-writer behavior
- Any repeated defect class caused by missing state or an invalid transition

The authoritative model is `docs/spec/points.target.spec.tex`. Run fuzz for type
checking and ProB for invariant and deadlock checks. Tests derived from changed
TTF partitions land with the implementation. See `docs/TESTPLAN.md`.

## Completion Conditions

A PR unit is complete only when:

- Every claimed Beads issue has met its acceptance criteria.
- Every required Ethos mission is closed with an accepted result.
- Every evidence row is `pass`; no row is missing or inferred.
- Z verification was rerun for modeled behavior changes.
- `make check` passes on the complete diff.
- Local review has zero material findings.
- For user-visible product work, the built or installed CLI was exercised
  through the changed user workflow.
- For a product-slice PR, the slice has focused unit evidence, real-boundary
  integration or contract evidence, and at least one end-to-end acceptance test
  through the installed public entry point. The relative quantity follows
  `docs/TESTPLAN.md`'s test pyramid; one end-to-end test does not replace broad
  lower-level coverage.
- For a product-slice PR, the worker reported the first-running checkpoint and
  no material integration seam remains silently mocked or deferred.
- Documentation, design, configuration, spike, and support PRs passed the
  proportionate real checks named by their own acceptance criteria.
- The operator confirmed the demo when human judgment was required.
- CI and remote review gates pass on the latest commit.
- The branch, issue state, and handoff are pushed and durable.

## Resumption

A new session reconstructs state in this order:

1. `bd ready --json` and `bd show <claimed-id> --json`
2. Open Ethos missions, contracts, results, reflections, and logs
3. Git branch, status, and recent commits
4. The governing spec clauses and test partitions
5. The next ready Beads or mission node

The prior chat transcript is optional context, not workflow state. If the loop
cannot resume from Beads, Ethos, Git, and the specification, the previous
session failed to make its work durable.
