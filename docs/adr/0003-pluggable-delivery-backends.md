# ADR-0003: pluggable delivery backends

- Status: Accepted
- Date: 2026-10-10

## Context

The predecessor hard-wired one env-delivery mechanism: a managed block in
`.envrc.local` applied by direnv. That is one vehicle among several (Nix, mise,
plain shell, per-process injection), and baking it in excludes users who manage
their environment differently.

## Decision

Separate **what to write** (per-harness config content — a pure function of the
selection) from **how it is delivered** (a pluggable backend). direnv becomes one
backend, not a dependency.

Backends for the env-fed surface (Claude Code's vars, codex's base URL/auth):

- **launcher-wrapper** (preferred, default) — inject env per process
  (`points claude …`); drift-proof, no persistent state to race.
- **direnv**, **mise** — per-directory shell env.
- **nix** — devshell / home-manager, declarative.

**File-writing is the universal core**, independent of backend: pi and open code
validate models against their own config files and ignore environment variables,
so the tool always writes those files directly. codex's provider table is also a
file.

## Consequences

- No single env manager is load-bearing.
- The launcher-wrapper is especially valuable for Claude Code (its config is the
  most error-prone), making the canonicalization/override/tier state per-process
  and ephemeral.
- The backend abstraction applies only to env-fed harnesses; pi/open code do not
  participate in it.

## Alternatives rejected

- **direnv-only**: excludes Nix/mise users; the managed-block pattern is what
  drifted.
- **launcher-wrapper only**: cannot configure pi/open code, which need files.
