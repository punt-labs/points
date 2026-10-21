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

## Clarification: 2026-10-18 — bounded OpenCode/Bifrost slice

The first end-to-end implementation slice fixes one supported route pair without
reversing the multi-source target. The operator explicitly supplies
`--config PATH`, `--base-url ROOT`, source `bifrost`, harness `opencode`, and one
of exactly `bedrock/gpt-5.6-sol` or `openai/gpt-6-astra`. A same-provider model
outside that fixture is refused. Discovery, other harness/source pairs,
environment backends, picker filtering, list, and unroute follow in later
slices.

`ROOT` is the deployment root; the writer derives `<ROOT>/openai/v1` and verify
derives `<ROOT>/v1/models` only from a coherent observed managed base. Route is
offline. Status reads only the explicit strict-JSON file. Verify first proves
local coherence and then performs at most one authenticated catalog request.
HTTPS and literal loopback HTTP are normal; non-loopback HTTP requires fresh
invocation-scoped `--allow-insecure-http` consent. Consent is not persisted,
does not weaken TLS, and never permits redirect following, retry, or proxy use.

An owned Bifrost routing overlay that conflicts with the requested route is
corrected after preserving exact original bytes and supported mode at
`<PATH>.points.bak`. Backup publication is exclusive and durable before config
publication. There is one atomic config commit point but no atomic transaction
across backup and config entries. Before commit, no config is published; after
commit, cancellation, durability, cleanup, or reporting failure is reported
truthfully and does not trigger automatic restoration. The committed backup is
a retained recovery result, not cleanup residue.

The bounded transaction refinement makes those boundaries terminal: every live
operation is running/phase guarded, successful revalidation is an explicit
precondition to commit, and pre-commit cancellation enters an abort phase that
cannot stage, publish, revalidate, or commit. Identity-safe cleanup and directory
sync remain available in abort; post-commit cancellation still permits mandatory
durability confirmation and cleanup. A confirmed sync discharges an owned
cleanup identity that is absent or replaced without deleting the replacement or
erasing the anomaly note. A historical config-sync failure remains reportable
even if later cleanup sync confirms final config durability.

This slice observes one native file and does not claim precedence over OpenCode
layering outside it. The operator remains the route authority, while unrelated
providers and protected agent/session choices remain user-owned.

The general target's `unroute` remains outside this slice, but its formal
operation is still coherent and factored: nonempty input plus coherent pre-state,
a completely assigned effect that removes route/model/auth/registration/picker
state, exact no-op refusal for empty or incoherent input, and a checked coherent
post-state. Malformed observations belong to status/verify and never silently
authorize route mutation.
