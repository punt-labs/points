# Changelog

All notable changes to `points` are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Repository scaffold: Go module + CLI skeleton (`cmd/points`) with the
  `route`/`status`/`verify`/`list`/`unroute` command surface stubbed.
- Formal design: the verified Z specification set under `docs/spec/`
  (`target`, `current`, and the `fleet`/`claude` two-tool split), with target
  and current PDFs.
- Architecture decision records (`docs/adr/0001`–`0007`) capturing the routing
  thesis, config-writer (not proxy) stance, pluggable delivery backends,
  multi-source per-harness routing, Go single-binary choice, Claude Code
  complexity quarantine, and the spec-as-design-source decision.
- `docs/TESTPLAN.md` — spec-driven layered test strategy.
- `docs/WORKFLOW.md` — spec-first Beads and Ethos development loop.
- Project-scoped OpenCode 2 `gopls` diagnostics and `gofmt` formatting.
- Pass-backed authentication for the shared OpenCode service and documented
  Desktop, TUI, standalone, and network policy.
- Ordered OpenCode 2 safety boundaries for the primary build agent and explicit
  tool allowlists for gstack specialists.
- Native Quarry-first `researcher` subagent with scoped local, MCP, and web
  research access.
- OpenCode-forward `AGENTS.md` authority with thin Claude compatibility,
  deterministic development-configuration checks, and live workstation doctor.
- Project skills for Quarry recall/capture, Ethos missions, development
  diagnostics, and trust-aware agent mail.
- Narrow gstack shell allowlists and documented Code Mode, MCP, session-tool,
  error-contract, and future Jujutsu boundaries.
- OpenCode-first configuration ownership and precedence, with redundant global
  JSONC removed and future `points` writer boundaries documented.
- Built-in-only OpenCode plugin policy, mature-repository Git-hook comparison,
  and current Ethos/Biff hook and notification validation.
- Public GitHub repository with protected `main`, robust required CI, and an
  iterative Qodo, Cursor Bugbot, and Copilot review loop.
- OpenCode session lifecycle and cross-system ID ownership for Beads, Ethos,
  Circuit, Git, and GitHub correlation.
- OpenCode background work and concurrency: subagent/shell jobs, depth cap,
  steer/queue, completion notifications, cancellation, restart recovery, and
  write-set/worktree isolation.
- OpenCode worktrees and references: git worktree strategy, reference sources,
  VCS detection, external-directory boundary, shared Beads/Ethos state, and the
  decision to defer Jujutsu adoption.
- OpenCode compaction and context management: summary vs native compaction,
  reserved context, checkpoint shape, transcript independence, and maintenance
  model routing.
- `docs/SETUP.md` — post-clone tool-enablement steps.
- Makefile quality gate; Bazel scaffolding (unverified pending bazelisk).
- Beads configuration (`issue_prefix: points`), canonical `.gitignore`,
  markdownlint config, and CI workflow.
