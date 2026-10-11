# ADR-0006: Claude Code's complexity is quarantined

- Status: Accepted
- Date: 2026-10-10

## Context

Analysis of the predecessor showed that almost every hard, breakage-prone part
belonged to **one** harness — Claude Code: it canonicalizes the configured id
(stripping the provider prefix the gateway routes on), needs a `modelOverrides`
map to send the verbatim id, fans out tier aliases
(`opus`/`sonnet`/`haiku`/`fable`), pins a small-fast background model, carries the
`[1m]` context marker, and is the only harness with a legitimate use of a Claude
subscription credential. The other three harnesses are uniformly "route the id
verbatim."

## Decision

Treat Claude Code's complexity as a **quarantined concern**, modeled separately
(the `points.claude` spec) from the OpenAI-protocol harnesses (the `points.fleet`
spec). The complexity is irreducible but bounded: it concerns exactly one harness.

## Consequences

- A change to any OpenAI-protocol harness (codex/pi/open code) cannot regress the
  Claude Code path, and vice versa.
- The fleet concern collapses to a uniform "route the verbatim id" rule; the
  Claude concern carries the canonicalization/override/tier/credential machinery
  alone.
- Picking a non-Claude model for Claude Code is a loud refusal (Claude Code only
  runs Anthropic models), not a silent mis-route.

## Note

The split is a design/modeling decision, not necessarily two binaries: `points`
ships as one CLI, but its internal structure and its specs keep the two concerns
separated along this seam.
