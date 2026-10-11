# OpenCode plugins and repository hooks

## Decision

`points` uses OpenCode's built-in plugins only. It has no global or project
external OpenCode plugin and no experimental hook configuration. The active
plugin API reports every plugin as built-in and active.

Keep integrations in the narrowest owner:

- MCP servers own external tool execution and connection lifecycle.
- Skills own on-demand decision workflows and deposited-document indexes.
- `AGENTS.md` owns durable project policy.
- Git hooks own commit audit, trailers, and asynchronous repository events.
- OpenCode plugins are reserved for lifecycle interception or registry
  transforms that configuration, MCP, skills, and Git hooks cannot express.

Wrapping Ethos, Quarry, Biff, Vox, Beadle, Lux, Context7, or Brave in project
plugins would duplicate existing MCP ownership and add startup/failure coupling.
No custom plugin is justified today.

## Built-in plugin surface

OpenCode 2.0.26 uses built-ins for configuration discovery, agents, skills,
commands, providers/models, MCP, tools, prompts, Code Mode defaults, Git and
Mercurial VCS, worktrees, browser, instructions, compaction, formatting,
snapshots, watcher, and tool-output policy. Built-ins activate before a session
uses their domains. Registry transforms replay in registration order; later
valid registrations can override earlier effective names. Each model request
captures a stable tool snapshot.

Hook order is plugin order. Prompt hooks modify admitted input; context,
compaction, title, and generate hooks affect their separate model calls; HTTP
and retry hooks affect provider traffic. A hook must be retry-safe and cooperate
with cancellation. This repository does not install hooks that rewrite prompts,
model requests, HTTP bodies, retry decisions, tools, agents, or providers.

## Mature repository comparison

Ethos, Quarry, Biff, Vox, and Beadle were inspected as references. Their local
Git config is deliberately minimal: normal origin/branch tracking and, where
used, `beads.role=maintainer`. They do not add project OpenCode plugins. Mature
tool integration is implemented through generated Git hooks and committed
enablement markers.

`points` has the mature five-hook set:

- `pre-commit` — Ethos audit sealing, fail-closed when enabled.
- `commit-msg` — Ethos mission/delegation trailers.
- `pre-push` — Biff notification dispatch, fail-open.
- `post-commit` — Biff notification dispatch, fail-open.
- `post-checkout` — Biff notification dispatch, fail-open.

Ethos itself has only `pre-commit` and `commit-msg`, which is intentional for the
tool's own repository. Quarry, Vox, and Beadle carry the same five-hook shape as
`points`. `points` and Ethos have a newer commit-message hook than older sibling
checkouts; the difference is currency, not drift. `ethos doctor` verifies both
hook presence and exact installed-version hashes.

Running `biff enable` idempotently refreshed the committed notification workflow
to watch both `CI` and `Security`; it preserved the newer pinned actions,
default-branch checkout, fork-secret boundary, and relay settings. Biff Git
hooks deliberately ignore dispatch failures so communication cannot block Git.

The shared `.gitattributes` rule delegates `.beads/issues.jsonl` merges to the
Beads merge driver. `.gitignore` follows mature repos by excluding local
credentials, runtime state, captures, worktrees, and per-clone settings while
retaining committed tool markers and policy.

## Claude compatibility

`.claude/settings.json` remains an occasional-harness compatibility file. Its
Vox permission does not configure OpenCode. Deposited Claude hooks and guides
are likewise not OpenCode plugins. Do not port them mechanically: OpenCode uses
MCP, native agents/skills, `AGENTS.md`, and its own plugin API.

## Failure and update policy

An external plugin can transform credentials, models, tools, permissions,
sessions, worktrees, and provider requests. Adding one therefore requires an
explicit area-8 review, pinned source/version, startup and unload tests,
cancellation, failure isolation, secret analysis, and rollback documentation.
`make check-dev` rejects unreviewed project `plugins` or `experimental` config.

After upgrading Ethos or Biff, rerun their enable/doctor commands. Git hooks are
per-clone; committed markers and workflow files are shared. After changing an
OpenCode plugin or MCP binary, restart the service after `direnv allow` and
credential preflight.

## Future Jujutsu plugin

A Jujutsu worktree strategy is a legitimate future plugin candidate because
OpenCode configuration and MCP cannot replace Git worktree creation/removal.
It remains deferred to `points-p70` and area 13, after the initial baseline is
committed and `jj` is installed. Adoption requires native `jj workspace`
ownership, not a plugin that merely blocks Git commands.

## Validation

`make check-dev` validates that project plugin/experimental fields are absent
and Biff watches both quality workflows. `make doctor` requires all active
OpenCode plugins to be built-in and healthy, Ethos hook checks to pass, and Biff
deployment to be current. Normal `make check` continues to lint committed
workflow and source artifacts.

The first protected PR proved all three automated review integrations. Qodo
completed a clean structured review on the exact head commit, Cursor Bugbot
passed its external check, and Copilot submitted an approval-recommended review
with zero findings. Qodo publishes a review rather than a GitHub check context
in this organization, matching Ethos, so the leader enforces its exact-head
cleanliness in the iterative PR loop documented in `docs/WORKFLOW.md`.
