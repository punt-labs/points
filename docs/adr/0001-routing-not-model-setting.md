# ADR-0001: points is a routing tool, not a model-setter

- Status: Accepted
- Date: 2026-10-10

## Context

The predecessor (`model-provider.sh`) was conceived as a "set the model"
tool and repeatedly broke. Analysis showed it was conflating two separate
concerns: *routing* (how a request reaches an upstream) and *model choice*
(which model serves a request). The whole point of running multiple agents is
that they can use different models — a reviewer on a cheap model, an architect
on a capable one — so a tool that forces one model across agents fights its
users.

## Decision

`points` owns **routing** and a **default model** only. It never writes an
agent's model. Routing is session-global per harness (base URL, auth, source);
model choice is per-agent, user-authored, and out of scope. The guarantee is
**routability** — every model whose provider the chosen source serves reaches a
valid upstream — not model-identity across requests.

## Consequences

- Per-agent model selection is fully supported, because the tool leaves agent
  definitions untouched.
- The core becomes a pure function `selection → per-harness routing config`.
- Correctness is "is every referenceable model routable?", which is checkable
  (`verify`), not "did every agent get the selected model?", which would be wrong.

## Alternatives rejected

- **Fan-out** (write the selection into every agent slot): clobbers deliberate
  per-agent choices.
- **Verify-no-drift** (flag agents pinning a non-default model): flags a
  legitimate choice as an error.
