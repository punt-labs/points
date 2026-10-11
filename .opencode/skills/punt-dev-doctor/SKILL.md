---
name: Punt Development Doctor
description: Diagnose or verify the points development environment, OpenCode service, MCP roster, agent configuration, Ethos, Beads, and Punt Labs helper tools. Use for setup failures, stale services, missing agents/tools, credential-safe health checks, post-clone setup, or whenever OpenCode/toolchain configuration changes.
---

# Punt development doctor

## Decision framework

Choose the least expensive check that proves the claim:

- Run `make check-dev` for deterministic committed configuration: instructions,
  agents, evaluator models, MCP roster, JSON, and authored-file secret patterns.
- Run `make doctor` for live workstation health: CLI execution, required tools,
  OpenCode service, connected MCPs, and active agent roster.
- Use the affected tool's MCP health operation when available; otherwise use its
  `doctor` or `--help` command.
- Restart OpenCode only after configuration, credential, or installed MCP binary
  changes. Preserve pass-backed authentication and verify Bifrost credentials
  are resolvable before restart.

Report the failing layer—committed config, local secret store, background
service, MCP process, or tool binary—rather than applying broad reinstalls.
Never print secret values. A partial MCP list immediately after restart may be
startup latency; confirm bounded readiness before diagnosing failure.

## Prerequisites

Work from the repository root with direnv approved. Follow `docs/SETUP.md` for
post-clone setup and the relevant OpenCode audit page for ownership decisions.

## Resources

- Canonical setup and troubleshooting: `docs/SETUP.md`
- Service authentication: `docs/opencode/12-server-clients.md`
- Instructions/context: `docs/opencode/06-instructions-context.md`
- Models: `docs/opencode/03-models-routing.md`
- Diagnostics: `docs/opencode/14-lsp-formatters-diagnostics.md`
