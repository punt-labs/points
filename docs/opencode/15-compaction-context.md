# OpenCode compaction and context management

## What compaction is

When a session's conversation grows toward the model's context window, OpenCode
replaces the older part of the transcript with a compact representation so work
can continue. Two mechanisms exist:

- **Summary (default).** A dedicated `compaction` maintenance agent writes a
  structured Markdown summary of the older transcript. The newest messages
  within the `keep` budget are retained beside the summary, serialized to
  labeled text (not raw transcript): tool activity is converted, long tool
  outputs are truncated, and attachment bytes are replaced with descriptors
  (see "Tool output and media" below).
- **Native.** When the model's provider supports it, OpenCode uses the
  provider's own compaction, producing an encrypted replacement window that only
  replays on the endpoint that made it.

This repo's models summarize, so the summary mechanism is what applies.

## Settings and reserved context

Defaults (unchanged in this repo):

- `auto: true` — automatic compaction is on.
- `keep: 15_000` — tokens of recent conversation kept beside the summary
  (serialized to labeled text, as above).
- `buffer` — unset, so OpenCode reserves window space for the final reply and the
  summary itself: 10% of the window, except that when the window is at least
  `2 × RESERVE_MIN` (32,000 tokens) the reserve is at least `RESERVE_MIN`
  (16,000). Below 32,000 tokens the reserve is just 10%.

Compaction is **due** when the estimated context reaches the ceiling
(`window − reserve`). The estimate is anchored on the provider's last reported
usage plus the text added since, so an unknown window never auto-triggers;
compaction then happens only when the provider rejects a request as too long.

## Triggers

- **auto** — the estimate crossed the ceiling before a turn.
- **overflow** — the provider rejected the context as too long; the next attempt
  aims below the rejected size, shrinking at 70% → 50% → 35% before giving up.
- **manual** — the operator ran `/compact`.

With automatic compaction off, only the operator compacts (overflow included).

## Checkpoint shape

A completed summary compaction becomes the first message of the active history
and is sent on later requests as one user message:

```text
<conversation-checkpoint>
  <summary>…structured summary…</summary>
  <recent-context>…newest kept messages, serialized to text…</recent-context>
</conversation-checkpoint>
[new messages…]
```

The summary uses a fixed template — Objective, Requirements, Decisions, Work
State (Completed / Active / Blocked), Next Move, Relevant Files, Important
Context. Updating an existing checkpoint consolidates it: newer history wins, and
resolved blockers and answered questions are dropped while unresolved work and
unanswered user requests are carried forward verbatim.

## Transcript independence

The summary prompt deliberately **excludes** instructions and setup: repository
conventions, instruction files such as `AGENTS.md`, environment details, and the
session ID. The next agent receives current versions of all of these separately,
re-selected fresh each turn (see `docs/opencode/06-instructions-context.md`). A
checkpoint therefore summarizes only what the user and assistant said and did,
and is portable across agents and restarts. The active history normally loads
from the latest completed compaction, so a summary checkpoint is self-contained
context. A native checkpoint is the exception: it replays only when its provider
provenance is compatible with the current endpoint, so after a model or provider
switch OpenCode skips it and re-expands the stored transcript instead.

The summary is also instructed to preserve consequential workflow state —
whether changes are uncommitted, committed, pushed, under review, or merged — so
a resumed agent does not lose track of where a branch or PR stands.

## Durable Beads and Ethos recovery

Compaction does not store Beads or Ethos state; it only summarizes the
conversation. Beads issues (central Hosted DoltDB) and Ethos mission records
(per-checkout working tree) remain the durable sources and are re-read from their
stores after compaction, not reconstructed from the summary. The checkpoint's
role is to preserve identifiers and intent (which bead, which mission, what was
decided) so the resumed agent knows which durable records to consult. Keep
bead/mission IDs and status in the conversation so they survive into the summary.

## Tool output and media in the summary

The recent-context transcript trims long tool outputs (about 1,250 characters
each) and omits reasoning, media bytes, and instruction updates; background shell
output is left out of the retained recent part. Media is estimated for sizing only
(images ≈ 1,500 tokens, PDFs ≈ 2,000). Do not rely on full tool output surviving
compaction — persist anything that must outlast the window (a file, a bead, a
commit), not the transcript.

## Maintenance-model routing

Compaction, summary, and title run as hidden maintenance agents configured in
`~/.config/opencode/opencode.json`:

| Maintenance agent | Model |
| --- | --- |
| Compaction | `bifrost/bedrock/gpt-5.6-terra` |
| Summary | `bifrost/bedrock/gpt-5.6-terra` |
| Title | `bifrost/bedrock/gpt-5.6-luna` |

All three are Bedrock OpenAI-family routes, consistent with the routing policy
that no preferred agent or maintenance role selects an Anthropic model
(`docs/opencode/03-models-routing.md`). A long-context reliable model backs
compaction/summary; a cheap, short model backs title.

## Decisions

- Keep automatic compaction on with the default `keep: 15_000` and the default
  reserve (10% of the window, floored at 16k once the window reaches 32k). The
  defaults are well-matched to the Bedrock long-context
  maintenance model; revisit only if summaries start losing needed recent detail.
- Keep compaction and summary on `bifrost/bedrock/gpt-5.6-terra`.
- Set the title maintenance model to `bifrost/bedrock/gpt-5.6-luna`, correcting a
  prior global-config drift where title pointed at an Anthropic model in
  violation of the maintenance-role routing policy.
- Treat the checkpoint as conversation state only; rely on Beads, Ethos, Git, and
  files for durable state, and keep their identifiers in the conversation so they
  survive compaction.

## Runtime evidence

Confirmed from installed OpenCode v2.0.26 source the compaction defaults
(`auto`, `keep: 15_000`, the 10%/32k-floored-16k reserve rule), the summary
template and
transcript-independence prompt, the checkpoint wrapper, the shrink ladder on
overflow, and tool-output trimming. Confirmed the live global maintenance-model
assignments and corrected the title model from an Anthropic route to
`bifrost/bedrock/gpt-5.6-luna` in `~/.config/opencode/opencode.json`; the change
applies on the next service restart or config reload.
