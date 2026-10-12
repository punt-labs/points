# OpenCode background work and concurrency

## Execution model

OpenCode serializes the model turns of a single session and runs different
sessions concurrently. A per-session run coordinator owns a single draining
fiber from the first wake until the session would stay idle; a mid-drain
"doorbell" coalesces new work into the same busy period, and the widest pending
scope wins (`input` subsumes `steer`). Model-turn parallelism therefore comes
from running multiple sessions — notably subagent children — not from
overlapping turns inside one session.

This serialization applies to model turns, not to long-running tool work.
Subagents and shells run as **jobs** in a process-local registry keyed by the
child session ID or the shell ID. Jobs are forked in parallel and outlive the
plugin call that launched them, so a background job keeps running while its
owning session returns to the model and starts its next turn.

## Subagents

The `subagent` tool spawns a child session and runs it as a job:

- **Foreground (default):** the parent blocks on the job and returns the child's
  final text. Interrupting the parent interrupts the child and cancels the job.
- **Background (`background: true`):** the call returns immediately with the
  child session ID and a running status; the parent is told not to poll.
- Passing a prior child `sessionID` continues that specific child; a supplied
  session must already be a child of the caller.

Nesting depth is capped by `experimental.subagent_depth` (default `1`). The tool
walks the `parentID` chain and refuses once the limit is reached. At the default,
a primary agent may spawn one layer of subagents, and those subagents cannot
spawn their own. This matches the project's worker/evaluator map: the `build`
leader dispatches every gstack worker and evaluator directly as depth-1
subagents.

A foreground subagent can become backgrounded mid-flight (the operator backgrounds
blocking work); the tool then switches to the notification path instead of
returning inline.

### Specialist delegation boundary

The six `.opencode/agents/gstack-*.md` specialists run as `mode: subagent` with a
deny-all permission baseline and no `subagent` grant, so they cannot delegate
further even below the depth cap. They are leaf workers by configuration, and
their prompts reinforce "do not delegate." Keep this boundary: delegation
authority and the worker/evaluator split stay with the `build` leader.

## Shells

The `shell` tool runs each command as a job keyed by its shell ID:

- **Foreground (default):** blocks with a default timeout
  (`DEFAULT_TIMEOUT_MS`, two minutes). Set `timeout: 0` to disable.
- **Background (`background: true`):** returns immediately with the shell ID; the
  command has no timeout by default and streams output to a file. The parent is
  notified with the command's output when it finishes.
- A foreground shell can be backgrounded mid-run; its timeout is then removed.

Shells receive identifying environment: `AGENT=1`, `OPENCODE=1`,
`AI_AGENT=opencode` (unless already set), and `OPENCODE_SESSION_ID=<session>`.
`OPENCODE_SESSION_ID` is the hook most likely to carry OpenCode session identity
into `ethos hook commit-trailers`; `points-hqi` owns that integration.

## Steering versus queueing

Pending input lives in a durable, serialized per-session inbox (see
`docs/opencode/10-sessions-persistence.md`):

- `steer` promotes at the next safe model-step boundary and takes priority; use
  it to correct or redirect work already in flight.
- `queue` is FIFO and promotes one item at a time at normal input boundaries; use
  it when later work must run in order behind admitted work.
- Move and compaction entries are ordered control barriers.

## Completion notifications

Background completion is not a signal the leader must watch for. The job delivers
a **synthetic message** into the parent session's inbox carrying the result, and
the message resumes the parent. Subagent notifications carry
`metadata.source = "subagent"` with the child ID, agent, and state; shell
notifications carry the command output and shell/job IDs. Notifications are
deduplicated per `childSessionID:startedAt`, and the durable background marker is
cleared once the notification is admitted.

The correct leader behavior after launching background work is to do other
non-overlapping work or end the turn; it will be resumed when the notification
arrives. Polling, sleeping, or re-reading output files while waiting is wasted
work.

## Cancellation and interruption

- `escape` interrupts the current session's execution.
- `ctrl+b` backgrounds the session's blocking tools (`Session.background`), which
  injects a synthetic message listing what was backgrounded and tells the leader
  to move on.
- `ctrl+d` interrupts a subagent.

Interruption resolves as soon as it is accepted; finalizers and the settled hook
run afterward on their own time. Cancelled jobs are not persisted as recoverable
background work.

## Restart and durable authority

The shared background service owns the registry and recovery, and the
managed-server protocol admits one server at a time (a successor spawns only after
the previous process is confirmed dead). This is the single durable authority for
concurrent work; do not run competing standalone servers against the same
database for normal work.

On restart, a boot sweep recovers orphaned executions and pending background jobs:

- **Interrupted turns** resume, guarded by a durable per-turn attempt budget
  (default `maxAttempts = 10`); a turn that keeps dying is terminalized instead of
  crash-looping.
- **Background subagents** that were still running are resumed and re-backgrounded;
  their parents receive the normal completion notification.
- **Background shells** do **not** survive restart: a running shell is reported
  `cancelled` with a restart notice, while already-completed or errored output is
  still delivered. Recovery is at-least-once, so tool side effects can repeat
  after a crash — prefer idempotent background commands.

## Worktree and write-set isolation

OpenCode bounds concurrency but does not, by itself, prevent two parallel
sessions from editing the same files. The subagent tool explicitly instructs
callers to work on non-overlapping tasks. Safe parallelism therefore depends on:

- disjoint write sets per concurrent worker (Ethos mission write-sets enforce
  this for mission work), and
- separate worktrees when concurrent workers must touch the same paths.

Worktree mechanics and `session_move` across worktrees are area 13
(`points-h7o.13`); the rule here is that running workers in parallel is only safe
when their file targets do not overlap.

## Decisions

- Keep `experimental.subagent_depth` at the default `1`. The worker/evaluator map
  dispatches specialists directly from the leader, so deeper nesting is
  unnecessary and the shallow cap keeps delegation authority with the leader.
  Revisit only if a concrete pipeline needs a depth-2 subagent.
- Keep specialists as non-delegating leaf subagents (deny-all baseline, no
  `subagent` grant). Do not grant `subagent` to a gstack agent.
- Leave `experimental.portable_shell_scanner` at its default; the local/dev
  channel already selects the portable scanner.
- Treat background completion as inbox-delivered, not polled. Leader and skill
  guidance must never instruct sleeping or polling for background results.
- Rely on disjoint write sets (and worktrees where needed) for safe parallel
  work; OpenCode concurrency alone does not prevent file conflicts.

## Runtime evidence

An isolated test session launched a background shell (`background: true`). The
tool returned immediately with `status: running` and a shell ID, and the
command's completion arrived as a synthetic notification that resumed the session
without any polling — matching the source. The test session was deleted
afterward. Subagent parent/child, fork, and service-restart persistence were
runtime-proven during area 10 and are not re-proven here.
