# OpenCode sessions and cross-system identity

## Ownership

No universal session ID should replace the identifiers owned by each system:

| System | Identifier | Owns |
| --- | --- | --- |
| OpenCode | `ses_…` | Conversation, model/agent selection, messages, children, forks, inbox, approvals, context |
| Beads | `points-…` | Work item, priority, dependencies, acceptance criteria, status |
| Ethos | `m-…`, `d-…` | Mission contract, worker/evaluator delegation, results, reflections, audit |
| Circuit | `<machine>-<suffix>` | Durable workflow-machine state, observed checks, transition history |
| Git | 40-character commit SHA | Immutable code state |
| GitHub | `owner/repo`, PR number/node ID, head SHA | Pull request, checks, reviews, threads, merge state |

These IDs correlate but do not alias one another. The authoritative join for a
PR review observation is `(repository, PR number, head SHA)`. A push changes the
head SHA and invalidates observations without changing the PR, Circuit, Bead,
Ethos, or OpenCode IDs.

## Correlation metadata

OpenCode sessions have arbitrary durable JSON `metadata`. It is mutable through
the API and inherited by children and forks. The future Circuit/OpenCode adapter
should set stable references such as:

```json
{
  "bead": "points-6nw",
  "repo": "punt-labs/points",
  "pr": 6,
  "circuitSession": "pr-watch-ab12",
  "ethosMission": "m-…",
  "ethosDelegation": "d-…"
}
```

Omit unavailable keys rather than writing null placeholders. Do not put the
current head SHA in OpenCode metadata: it is mutable Circuit/GitHub evidence.
Circuit's check state must bind every observation to the SHA it evaluated.

Metadata is correlation, not authority. Changing it must not change Bead,
mission, Circuit, Git, or GitHub state. The CLI does not currently expose
metadata creation; an adapter should use the OpenCode API.

## Parent, child, and fork

A subagent receives a new durable OpenCode session with `parentID` set to the
calling session. It inherits location, parent metadata, and session permission
rules; its configured agent/model selection still determines its execution.
The returned session ID can continue only from the same parent. Default nesting
depth is one.

Deleting a parent recursively deletes its children. Runtime testing deleted one
isolated parent and two children while leaving both forks intact.

A fork is a new top-level session. It has no `parentID`; instead,
`fork.sessionID` and a message boundary identify the copied source history.
Forks adopt the parent's newest instruction state, metadata, permissions,
location, and transcript through the selected boundary. They then diverge
independently and survive source deletion.

## Model, agent, context, and restart

Model and agent defaults need not be stored on a session. When explicitly
switched, OpenCode persists provider, model, variant, and agent. An isolated
fork switched to `plan` and Bedrock Luna `low`; after service restart it retained
that selection and recalled a token from the copied parent transcript.

Configuration changes affect future resolution but do not rewrite existing
session selections or history. Moving or restarting a session retains its
instruction state and introduces changed ambient instructions through an
instruction update.

## Inbox delivery

OpenCode persists pending input in a serialized per-session inbox:

- `steer` is promoted at the next safe model-step boundary and takes priority.
- `queue` is FIFO and promotes one normal queued item at a time.
- Move and compaction entries are ordered control barriers.
- Admission is durable and idempotent enough to survive service restart.

Use steering for corrective input to current work. Use queueing when order must
be preserved behind work already admitted. Background completion notifications
are also durable session events; area 11 owns concurrency and cancellation.

## Move, archive, delete, and transfer

Move validates the destination and initializes its location context before
admission. It preserves session ID/history while changing location, project ID,
and subpath at a safe boundary. The source implementation serializes move with
other inbox controls. Because move changes configuration and tool context, it is
leader-owned and area 13 must test it with worktrees and Jujutsu.

The schema can store `time.archived`, and imported sessions preserve it, but
OpenCode 2.0.26 exposes no current CLI/server archive operation. Do not describe
archive as available lifecycle functionality.

`opencode session delete <id>` is non-interactive and recursively destructive
for children. Export before deletion when retention matters. Export contains
one session's settled messages, not descendants. Sanitized export redacts title,
metadata, location paths, and user content. Import preserves the original
session ID and refuses collisions; import parents before children.

## Persistence and cleanup

The shared OpenCode service owns the local database used by CLI and Desktop.
Session data survives service and application upgrades; uninstall does not
remove it. Use `opencode debug paths db` to locate the database, but do not edit
it externally while the service runs.

List commands show top-level sessions and are location/project scoped; they are
not a global workflow inventory. Use titles for human navigation and metadata
for machine correlation. Beads, Ethos, Circuit, and GitHub remain the durable
sources for their respective workflow state.

Delete only known disposable sessions. Never infer staleness from age alone:
an old session may be the conversational link to an active Bead, mission, or
Circuit run. A cleanup tool should resolve correlation metadata and active
external state before deletion.

## Runtime evidence

The audit created an isolated parent, subagent child, metadata child, and two
forks. It proved child parentage, fork boundaries, metadata inheritance,
transcript copying, explicit model/agent persistence, service-restart survival,
sanitized export, recursive child deletion, and independent fork survival. All
test sessions and exports were removed afterward.
