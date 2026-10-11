# OpenCode built-in and custom tools

## Scope and architecture

This audit covers the model-visible executable surface: direct built-ins, Code
Mode, MCP namespaces, skills as loadable tools, subagents, permissions, schema
errors, and custom-tool need. Coding conventions remain in `AGENTS.md`, nested
`AGENTS.md` files, Qodo standards, or narrowly triggered skills.

OpenCode keeps high-frequency local operations direct: `read`, `glob`, `grep`,
`edit`/`write`/`patch`, `shell`, `question`, `skill`, and `subagent` as supported
by the selected model. Large MCP, browser, session, and worktree catalogs sit
behind `execute` Code Mode. Calling `execute` does not bypass authorization;
each nested tool still checks its own permission action.

MCP actions use `<server>_<tool>` and resource `*`; unsupported characters are
normalized. Model-visible paths retain namespaces such as
`tools.quarry.status`. Registration validates namespace and effective-name
collisions, and `execute` is reserved. This project adds no custom executable
tools. Deterministic repository behavior belongs in `.bin/` scripts and Make
targets unless a model-callable schema provides a concrete user benefit.

## Agent surfaces

- `build` orchestrates with the broad default surface, project safety rules,
  and approval gates for consequential shell and communication operations.
- Read-only gstack specialists receive read/glob/grep plus a narrow shell
  allowlist for Git inspection, Go checks, Make targets, `./points`, and `fuzz`.
- `gstack-implementer` additionally receives edit capability but uses the same
  bounded shell commands.
- Gstack specialists cannot launch children, load project skills, access MCPs,
  invoke Code Mode, or use the browser.
- `researcher` receives read/search, Code Mode, scoped Quarry/Context7/Brave
  actions, and only the Quarry recall/capture skills. It cannot edit, shell, or
  delegate.

The previous wildcard specialist shell rule was unnecessarily equivalent to
host filesystem, process, and network authority. Native tests proved the new
policy: reviewer `git status --short` and QA `go test ./...` succeeded, while
reviewer `printf`, edits, and leader-only skill loading were denied. `make *`
remains a deliberate trust boundary because repository Make targets execute
host commands; agents operate only in a trusted checkout and `make check` is the
canonical gate.

## Code Mode and errors

Code Mode is useful for parallel independent calls and local composition of
results. Its runtime has no imports, timers, direct filesystem, or arbitrary
network access. The synchronous `search` function takes an object and returns
catalog metadata; discovered tools are then called through `tools`.

Native testing of `search('wrong')` returned
`SchemaError(Expected object)` without nested tool execution. Permission denial
returns `Permission denied: <action>`. Missing catalogs and disconnected MCPs
must not be described as permission failures: MCPs initialize asynchronously,
and service restarts during this audit repeatedly removed and re-added catalogs.
Direct doctor checks proved the local binaries, daemons, and credentials were
healthy while OpenCode reported stdio MCP startup timeouts. Area 11/18 owns
concurrency, restart, and operational recovery for that churn.

The apparent stdio churn was resolved by allowing the repository environment
with `direnv allow` before service restart. Because all local MCP commands use
`direnv exec .`, missing authorization can fail them as a group while remote
servers still connect. `make doctor` now checks direnv readiness first.

Catalog paths returned by `search` are opaque exact identifiers. A researcher
test incorrectly compared bracket-notation Context7 output against a
reconstructed dotted path, reported a local lookup miss, then successfully
called the exact known tool. Consumers must use the returned path/signature and
must not normalize bracket and dot notation themselves.

Detailed output truncation, managed full-output files, media, and attachments
belong to area 16. This audit only requires errors to remain distinguishable and
full output to be retrievable through OpenCode's managed-output mechanism.

## Session and worktree utilities

OpenCode Code Mode session rename/move and worktree create/list operations do
not request built-in permission actions in 2.0.26; worktree removal checks
`edit`. The old `opencode_session_move` rule therefore made a false claim and
was removed. The primary leader owns session/worktree lifecycle. The researcher
prompt explicitly forbids those utilities; other specialists cannot reach Code
Mode. Area 13 must revisit this instruction-only boundary.

## Jujutsu

Jujutsu (`jj`) is not installed. A colocated Git/Jujutsu repository could
improve agent work by making every working-copy change a revision and by using
native `jj workspace` isolation. It should not be initialized in this repository
while the entire environment baseline is uncommitted.

Installed OpenCode 2.0.26 currently uses its Git VCS adapter. Upstream has work
for Jujutsu detection/status/diff, but native Jujutsu workspace creation and
removal remain out of scope. Git worktrees are not Jujutsu workspaces. A linked
Bead defers installation and colocated initialization to area 13 after the
baseline commit, with explicit verification of OpenCode version support,
GitHub, Beads, Ethos hooks, bookmarks/push, and agent shell rules.
The follow-up is `points-p70`.

## Validation

`make check-dev` rejects wildcard gstack shell access and verifies the agent,
skill, evaluator, and MCP policy. Runtime smoke tests cover allowed local
commands, denied arbitrary shell/edit/skill access, Code Mode schema failure,
OpenAI/open-weight direct tool use, and researcher MCP calls established in the
model and permissions audits.
