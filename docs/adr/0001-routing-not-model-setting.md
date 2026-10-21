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

## Clarification: 2026-10-18 — OpenCode Slice 1 ownership

The Slice 1 explicit-file OpenCode writer refines, rather than changes, this
decision. `points` owns the selected route and root default plus the native model
registration needed to make that default referenceable. For the Bifrost provider
it owns the Responses package, credential-name/reference, derived base URL, and
the selected registration's identity/enabled/tool-capability leaves. It also
removes provider/model/variant routing overlays that would bypass those owned
route facts.

Registration is not a picker filter and is not an agent model choice. Switching
the root default from the Sol fixture token to Astra retains Sol's registration
and unrelated metadata. The merge preserves `agents`, maintenance-agent model
pins, sessions, separate agent files, other providers, unrelated root settings,
and unselected model data outside the enumerated routing overlays. No test or
implementation may rewrite a protected pin to make acceptance pass.

Slice 1 `status` and `verify` are intentionally limited to the explicitly named
file. They do not certify native configuration layering, plugins, existing
sessions, separate agent files, every retained declaration, or the model that
generated an answer. Full verify means the selected route is locally coherent
and an authenticated bounded catalog probe advertises the exact selected token
at probe time. Generation identity requires separately correlated real-harness
and upstream telemetry.

Correctable route-overlay conflicts are backed up and normalized, not treated as
agent drift. The backup warning identifies only sorted owned conflict paths; it
does not print old/new values or inspect user-authored model choices.

The bounded formal normalizer makes that ownership frame executable without
modeling arbitrary JSON syntax: finite owned-leaf states compute exact changed
and conflict pointer images, while native registration presence is modeled
separately from the certified selectable registration projection. Consequently,
unsupported and unselected native declarations remain user-owned and retained;
they are not silently certified or pruned. Presence of a selected declaration is
also independent from its owned leaves, so a missing `modelID`, enabled, or tools
leaf is a repairable addition rather than an impossible input state. Opaque
protected sentinels represent agents, maintenance pins, unrelated data, other
providers, and exact-number bytes. The projection must preserve those
registrations and sentinels and establish the coherent selected route; it is a
checker abstraction, not permission for an implementation to narrow the
preservation contract.
