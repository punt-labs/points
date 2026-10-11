# ADR-0004: multi-source, per-harness routing

- Status: Accepted
- Date: 2026-10-10

## Context

An early model assumed a single active gateway (Bifrost). That is true for one
operator's setup but not the general case: another user may route through direct
OpenAI plus OpenRouter with no gateway at all, and different harnesses may
legitimately point at different upstreams.

## Decision

Model a **set of configured sources** and a **per-harness route**
(`routeVia : Harness ⇸ Source`), chosen by the operator. Each routed harness
routes through exactly one source that speaks its protocol. A source declares the
providers it serves, the protocols it exposes, and the auth modes it accepts.

The operator picks the route. There is **no tool-defined precedence and no ban on
overlap**: if two sources both serve a provider, the operator simply routes a
given harness through whichever they prefer — that choice is the tool.

## Consequences

- The single-gateway setup is the degenerate case: one source serving every
  provider, all harnesses routed through it.
- Routability is per-harness: a model is routable for harness `h` iff its provider
  is served by `routeVia(h)`.
- No global precedence rule is needed; `routeVia` *is* the decision.

## Alternatives rejected

- **Single global gateway**: cannot express "no gateway, several direct sources,"
  the real multi-source case.
- **Tool-defined precedence on overlap**: removes the operator's choice, which is
  the entire purpose of the tool.
