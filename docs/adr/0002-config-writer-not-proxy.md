# ADR-0002: config-writer, not a proxy

- Status: Accepted
- Date: 2026-10-10

## Context

A common way to route coding harnesses to alternative models is a local proxy
(e.g. claude-code-router) that intercepts requests and rewrites them. We
evaluated this against a config-writing approach.

## Decision

`points` is a **config-writer**. Its entire output is static configuration on
one machine: it runs, writes files (and renders env via a backend), and exits.
It never sits in the request path.

## Consequences

- **No runtime component to fail.** The predecessor's failures were all config
  drift, never a crashed process; a config tool cannot introduce a request-path
  failure mode.
- Orthogonal to the actual gateway/router (Bifrost, etc.): `points` configures
  *which* endpoint each harness talks to; it never *is* one.
- Visibility (`status`/`verify`) becomes the primary UX — the antidote to the
  silent drift that motivated the rewrite.

## Alternatives rejected

- **Proxy / router process**: adds a daemon in the request path, the exact class
  of runtime failure the config approach avoids; also cannot help pi/open code,
  which read their own config files regardless.
- **Hybrid** (config + optional proxy): unnecessary complexity for no benefit the
  config approach lacks.
