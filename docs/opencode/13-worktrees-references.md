# OpenCode worktrees and references

## Two distinct mechanisms

OpenCode separates **worktrees** (writable checkouts of the current project) from
**references** (named, read-only sources). They solve different problems and must
not be conflated.

| Mechanism | Writable | Scope | Backing |
| --- | --- | --- | --- |
| Worktree | yes | one project, many checkouts | VCS strategy (git) + a project-scoped DB table |
| Reference | no | a named source | local path or cached git remote |

## Worktrees

A worktree is an additional checkout of the current project. Worktrees are
project-scoped: each is a row in a per-project table keyed by
`(project_id, directory)` with an owning strategy. The default worktree base is
`<global.data>/worktree/<projectID[:6]>`, outside the project tree.

- **create** resolves the project, selects the strategy, makes the destination
  (de-duplicating the name with a numeric suffix), delegates the checkout to the
  strategy, records ownership, and — if the project defines a start command —
  runs it in the new worktree with `OPENCODE_WORKTREE_BASE` and
  `OPENCODE_WORKTREE_PATH` in the environment.
- **remove** delegates to the owning strategy and clears the row.
- **refresh** reconciles the table against the filesystem: it discovers checkouts
  under known roots, claims unowned rows, and drops rows whose directories are
  gone. Discovery never steals a directory already owned by another strategy.

The only built-in strategy is **git** (`git worktree create/remove/list`). It is
auto-selected when the project's detected VCS type is `git`. Other strategies are
added by plugin; adding one makes it the selected strategy.

### Session binding to a worktree

Sessions are bound to a location (a directory), not to a worktree abstraction.
Moving a session into a worktree directory (`session_move`, area 10) re-resolves
the target's project, sets the new location, and re-derives the session's
`subpath` relative to the project directory, while preserving the session ID.
Running a worker in a worktree therefore means giving its session that worktree's
directory as its location.

### External-directory permission boundary

A worktree under the global data directory is **outside** the main session's
location. Reaching it — reading, editing, or running a shell with that `workdir`
— crosses the `external_directory` approval boundary, which is evaluated before
read/edit/shell permission. In this repo the six gstack specialists and the
researcher are granted `external_directory: *` (they already need to reach
sibling repos such as `../circuit` and the OpenCode source checkout), so a
specialist working in a project worktree is not additionally blocked. Keep that
grant deliberate: it is what lets a worker operate in an isolated worktree, and
it is also what lets a worker touch unrelated directories, so the shell
allowlist remains the real constraint.

## References

A reference is a named, read-only source resolved to a path:

- a **local** source points at an absolute path, or
- a **git** source points at a remote, materialized into a shared cache under
  `<global.repos>` and refreshed daily.

References are for pulling in external material to read (another repo, a docs
tree) without checking it out as a project worktree. They are read-only by
construction and are not a place to do work.

## VCS detection and review base

The VCS layer is provider-pluggable. Project/VCS detection walks up for `.git`
and `.hg` markers only; the built-in providers are **git** and **hg**
(Mercurial). The selected provider supplies branch info, status, diff, and an
optional review base, and a filesystem watch on branch metadata
(`.git/HEAD` for git) refreshes the current branch. There is no built-in
provider for any other VCS.

## Decision: Jujutsu (points-p70)

For OpenCode v2.0.26, **do not adopt Jujutsu for this project yet.**

- OpenCode detects only `.git` and `.hg`; there is no `.jj` marker and no jj VCS
  provider or jj worktree strategy. `jj` is also not installed on the
  development machine.
- A colocated repository (`jj git init --colocate`) keeps a real `.git`, so
  OpenCode would detect it as **git** and operate entirely on the git view. Its
  worktree strategy would run `git worktree`, which is not jj's workspace model;
  jj's operation log, change IDs, and bookmarks would be invisible to OpenCode.
  The two worktree models would compete over the same checkouts.
- Nothing in the current workflow needs jj: git worktrees already provide the
  isolation that concurrent workers require (see
  `docs/opencode/11-background-concurrency.md`).

Revisit only if (a) a jj VCS provider/worktree strategy exists for OpenCode, or
(b) a concrete workflow need justifies a plugin, and only after verifying GitHub
CLI, Beads Dolt sync, and Ethos hooks against a colocated repo. Until then, keep
`points-p70` open as a watch item, not an action.

## Shared Beads and Ethos state across worktrees

Beads (Dolt) and Ethos state are repository/identity scoped, not per-worktree.
Multiple git worktrees of one project share the same `.git` common directory and
the same Beads database and Ethos records. Concurrent workers in separate
worktrees therefore share one task graph and one mission/audit store; isolation
applies to the working files, not to Beads or Ethos state. Keep write-sets
disjoint so parallel workers do not collide on files even while they share the
task and mission stores.

## Decisions

- Keep the built-in git worktree strategy; do not add a worktree strategy plugin
  without a concrete need.
- Use git worktrees (not jj, not references) for isolating concurrent writable
  work on this project.
- Use references only for read-only external material; never do work in a
  reference path.
- Preserve the specialists' `external_directory: *` grant as the enabler for
  worktree and sibling-repo work, and rely on the shell allowlist as the active
  constraint.
- Treat Beads and Ethos state as shared across a project's worktrees; rely on
  disjoint write-sets for safe parallelism.

## Runtime evidence

Confirmed from installed OpenCode v2.0.26 source that the only built-in worktree
strategy is git and that VCS detection recognizes only `.git`/`.hg`. Confirmed on
the development machine that `points` is a plain git repository with no worktrees
and that `jj` is not installed. No worktrees or references were created; this
area is current-behavior documentation and a deferral decision, with no
configuration change.
