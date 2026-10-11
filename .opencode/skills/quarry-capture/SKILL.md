---
name: Quarry Capture
description: Persist durable project lessons or personal memory in Quarry after a non-obvious root cause, ratified decision, repeatable procedure, or mission reflection emerges. Use when the user says remember/capture/learn this, or when completed work produced knowledge that should survive sessions. Never capture secrets, source dumps, or progress narration.
---

# Quarry capture

## Decision framework

Choose the narrowest durable destination:

- Use `tools.quarry.learn` for a project-scoped lesson that future contributors
  should retrieve in this repository.
- Use `tools.quarry.remember` for identity-scoped memory such as a fact,
  procedure, observation, or explicitly qualified opinion.
- Use `tools.quarry.ingest` only for a durable source document that is not
  already indexed and whose provenance should remain available.

Capture only knowledge that will matter in a later session: a non-obvious root
cause, ratified design rationale, repeatable recovery procedure, or concise
mission reflection. Do not capture secrets, credentials, proprietary source,
raw tool output, transient status, or content already committed in the repo.

Before writing, search for an existing equivalent entry. Prefer updating or
leaving the existing source over creating duplicates. Include provenance and
confidence where the tool accepts them; distinguish objective facts from
opinions.

## Prerequisites

Use `tools.quarry.status` if service health is uncertain. Consult `quarry
--help` for CLI-only maintenance rather than embedding command documentation.

## Resources

- Project workflow and evidence policy: `docs/WORKFLOW.md`
- Research role: `.opencode/agents/researcher.md`
