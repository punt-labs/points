# OpenCode configuration layers and precedence

## Harness policy

OpenCode V2 is the default development harness for this user and repository.
Claude Code, Pi, and Codex remain supported occasional-use compatibility
surfaces. OpenCode-native configuration is authoritative for daily agent,
skill, MCP, model, and session behavior; compatibility files must not redefine
its project policy.

## Active ownership

| Layer | Owner | Contents |
| --- | --- | --- |
| `~/.config/opencode/opencode.json` | User/global | Bifrost provider and model catalog, Bedrock default, explicit `build` default agent, hidden maintenance models |
| `~/.config/opencode/cli.json` | User/CLI | TUI and terminal preferences only |
| Repository `opencode.json` | Project | MCP roster, build safety policy, Go LSP and formatter |
| `.opencode/agents/*.md` | Project | Specialist prompts, models, steps, and permissions |
| `.opencode/skills/*/SKILL.md` | Project | Narrowly triggered workflows and resource indexes |
| `AGENTS.md` | Project | Always-loaded OpenCode project policy |
| `.envrc` and `.envrc.local` | Environment | Non-secret defaults and local/pass-backed secret resolution |
| `.punt-labs/**` | Tool owners | Committed tool state, identity graph, generated/deposited references; not general OpenCode config |
| Session state | User/session | Selected model, agent, variant, approvals, context, and history |

The redundant global `opencode.jsonc` contained only `$schema` and was removed.
One global server config avoids ambiguous ownership. `cli.json` remains separate
because OpenCode V2 does not accept terminal preferences in project config.

## Precedence

OpenCode loads configuration from low to high priority:

1. Global `~/.config/opencode/opencode.json(c)`.
2. An explicitly selected config file, when the process supplies one.
3. Direct `opencode.json(c)` files from the farthest ancestor to the current
   directory.
4. `.opencode/opencode.json(c)` files from the farthest ancestor to the current
   directory.
5. Inline `OPENCODE_CONFIG_CONTENT` for that process.
6. Session-selected model and agent for existing session behavior.
7. One-run CLI selections such as `--model` and `--agent` for that invocation.

Fields merge rather than replacing whole documents. Later scalar values win;
maps merge by key; arrays follow the field's schema semantics. Permission rules
append and use last-match-wins behavior. Agents and skills also have their own
discovery and precedence rules documented in areas 1, 5, and 6.

A temporary nested test proved that a same-directory
`.opencode/opencode.json` model overrides both its direct sibling and farther
ancestor files. A standalone run with `OPENCODE_CONFIG_CONTENT` selected
Bedrock Luna over the global Bedrock Sol default. No persistent inline or
explicit config environment override is active in this repository.

## Session behavior

The global default applies to new work when a session has not already selected
a model. Existing sessions retain their stored model and agent. Switching a
session does not rewrite configuration. The root default cannot retain a
variant; agents and one-run/session selections can.

Do not migrate or rewrite existing sessions merely because the global default
changes. Make model changes explicit in the session when continuity matters.

## Future `points` boundary

The `points` product may manage only the OpenCode routing/provider fields and
root default model described by the formal specification and ADR-0001. It must
preserve user-owned and project-owned fields, including:

- agent definitions and per-agent models;
- skills and commands;
- permissions and policies;
- MCP servers;
- formatter, LSP, watcher, media, output, and worktree settings;
- CLI preferences in `cli.json`;
- session-selected models, agents, variants, approvals, and history.

This bootstrap configuration is evidence for the future writer, not permission
for the product to reproduce or own every field. Writers must parse, merge, and
round-trip unrelated configuration rather than replacing the file wholesale.

## Validation

`make check-dev` validates project-owned committed files and their invariants.
`make doctor` validates the active OpenCode service and local toolchain. Global
model/provider configuration is user state and is runtime-tested with
`opencode models`, `opencode debug agents`, and representative runs; it is not
copied into the repository. The global configuration source is visible locally
through `opencode debug config`, which lists ordered configuration sources (see
`docs/opencode/17-cli-automation.md`), but the project's committed gates
deliberately do not read or assert that user state.
