# OpenCode instructions and context assembly

## Authority

`AGENTS.md` is the sole active project-instruction authority for OpenCode V2.
OpenCode does not load `CLAUDE.md` as a fallback and does not interpret Claude
`@file` imports. `CLAUDE.md` remains only as a short compatibility pointer for
other harnesses; it must not duplicate project policy.

The root `AGENTS.md` contains only durable constraints that should accompany
every request: product invariants, orchestration boundaries, Beads ownership,
session completion, quality gates, and canonical documentation links. Command
catalogs and detailed procedures belong in tool help or `docs/`, not the
always-loaded prompt.

## Assembly order

OpenCode V2 assembles model context in this order:

1. Selected agent or provider system prompt.
2. Model identity, built-in date, and environment context.
3. Code Mode catalog and execution guidance when enabled.
4. Global and project `AGENTS.md` files.
5. Skill summaries, references, and reachable MCP guidance.
6. Session-specific instruction entries supplied through the API.

The selected specialist's Markdown body is its system prompt. The root
`AGENTS.md` still follows it, so specialist role text should describe the role
and its output contract rather than repeat repository-wide policy.

OpenCode loads the global `~/.config/opencode/AGENTS.md` first when present,
then project files nearest to the working directory before farther ancestors.
It combines sources and does not resolve contradictions. This repository has
one root `AGENTS.md` and no nested project instruction files. Add nested files
only when a subtree has genuine local rules.

## Skills, MCP, and Ethos

This repository has five project-local skills. OpenCode advertises only each
permitted skill's ID, name, and description; bodies load lazily after a `skill`
call. The catalog and permission decisions are documented in
`docs/opencode/05-skills.md`.

MCP instructions are generated from connected servers and filtered by the
selected agent's permissions. Their catalogs may arrive or change after a
session starts. The researcher receives scoped research MCP guidance through
Code Mode; ordinary gstack specialists do not receive broad MCP access.

Ethos identity files and `.punt-labs/ethos/CLAUDE.md` are not OpenCode project
instructions. Ethos context reaches agents through the Ethos MCP and through
the explicit gstack agent prompts and workflow contracts. This avoids injecting
the entire vendored identity registry into every model request.

## Token and duplication policy

The earlier root instructions contained roughly 800 words, mostly generated
Beads command documentation, while `CLAUDE.md` held a separate 500-word policy.
The OpenCode-forward root is now about 600 words and `CLAUDE.md` is a small
pointer. Detailed Beads commands remain in `bd --help` and
`docs/WORKFLOW.md`. This reduces always-loaded context and removes conflicting
authorities without weakening the operational contract.

Do not add files to the inactive V2 `instructions` config array. Use
`AGENTS.md`, a narrowly triggered skill, an MCP server instruction, or a
session-specific instruction entry according to lifetime and scope.

## Validation

`make check-dev` validates committed development configuration without requiring
live local services. It checks instruction authority, thin Claude
compatibility, native V2 agent files, Bifrost assignments, evaluator policy,
the exact MCP roster, JSON syntax, and obvious committed credentials.

`make doctor` adds live workstation checks: required CLIs, OpenCode service
health, eight connected MCP servers, and the expected active specialist roster.
Keep live checks out of normal CI because credentials and local daemons are not
available in a fresh public runner.

A fresh no-tool `build` request after this cleanup reported 10,840 cache-write
input tokens. The API intentionally exposes instruction-change events rather
than privileged instruction contents. Since the root `AGENTS.md` is only about
600 words, most remaining baseline cost comes from the combined tool, MCP, and
skill catalogs. Area 5 should reduce skill-advertisement noise; area 9 should
review tool and Code Mode catalog size.
