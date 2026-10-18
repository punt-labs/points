# OpenCode models and routing

## Policy

This document configures the development harness, not the `points` product.
OpenCode routes every model through the global `bifrost` provider. Preferred
routes are, in order:

1. Explicit AWS Bedrock routes for OpenAI models.
2. Explicit AWS Bedrock routes for open-weight models being evaluated.
3. `bifrost/openrouter/auto` as the selectable secondary route.

Anthropic models may remain visible because Bifrost and OpenRouter serve them,
but no preferred agent or maintenance role selects one. Direct-provider routes
are not preferred when an equivalent Bifrost Bedrock route exists.

Open-weight models are never Ethos evaluators. They may perform bounded worker
tasks or experimental comparisons, but every independent mission verdict must
come from an evaluator pinned to a preferred Bedrock OpenAI model. The current
evaluator set is `gstack-architect` and `gstack-reviewer`; create another
Bedrock OpenAI evaluator instead of promoting an open-weight worker when a new
evaluation specialty is required.

OpenCode does not expose a configured model fallback chain. An unavailable
configured default may fall back to the newest supported model, which is too
implicit for provider policy. `openrouter/auto` is therefore a deliberate model
selection for a run or session, not a claimed automatic failover from Bedrock.

## Assignments

| Role | Model | Variant | Reason |
| --- | --- | --- | --- |
| Session default and `build` | `bifrost/openai/gpt-5.6-sol` | Session-selected | Strong OpenAI coding default |
| Architect | `bifrost/openai/gpt-6-astra` | `high` | Deep design reasoning |
| Product | `bifrost/openai/gpt-6-astra` | `medium` | Product and scope reasoning |
| Security | `bifrost/openai/gpt-6-astra` | `high` | Threat analysis |
| Implementer | `bifrost/openai/gpt-5.6-sol` | `high` | Coding and tool use |
| Reviewer | `bifrost/openai/gpt-5.6-sol` | `high` | Correctness review |
| QA worker | `bifrost/bedrock/gpt-oss-120b` | `medium` | OpenAI open-weight trial; never an Ethos evaluator |
| Researcher | `bifrost/openai/gpt-5.6-terra` | `medium` | Reliable Code Mode and MCP schemas |
| Title | `bifrost/openai/gpt-5.6-luna` | None | Cheap, short maintenance request |
| Compaction and summary | `bifrost/openai/gpt-5.6-terra` | None | Reliable long-context maintenance |

The root model cannot retain a variant in OpenCode V2. Agent model references
retain their configured variants. Built-in `build`, `plan`, `general`, and
`explore` inherit the session selection when they have no explicit model.

## Catalog

The global OpenCode configuration declares the Bifrost routes that should be
selectable. In addition to the assignments above, Bedrock Nemotron Super 3,
Llama 4 Maverick, and Mistral Large 3 remain available for experiments.
Explicit OpenRouter OpenAI, GPT-OSS, and Llama entries remain available beside
`openrouter/auto`. Anthropic entries are visible but not preferred.

The custom Bifrost provider uses
`@opencode/ai/providers/openai-compatible/responses`. Preferred GPT reasoning
variants with function tools require the Responses API; the chat-completions
runtime rejects that combination. `make doctor` validates the effective package
and completes a real `gstack-product` read-tool turn so catalog presence alone
cannot mask a broken transport.

The source of truth for availability is Bifrost's authenticated `/models`
response. OpenCode's configured catalog supplies model limits and variants; it
does not discover accurate custom-provider capabilities automatically.

## Runtime evidence

On 2026-10-11, direct Bifrost probes succeeded for all four Bedrock OpenAI
routes and for Bedrock Nemotron, Llama, and Mistral. OpenCode-native tests then
proved:

- Bedrock GPT-OSS 120B produced normal text and used `read` successfully.
- Bedrock Nemotron used `read` successfully during the QA trial before QA moved
  to the preferred OpenAI open-weight GPT-OSS route.
- `openrouter/auto` completed an explicit OpenCode run.
- Bedrock Mistral called Context7 but malformed its first Code Mode `search`
  invocation for Quarry; it remains experimental rather than the researcher.
- Bedrock Terra remains the researcher because the native researcher previously
  completed both Quarry and Context7 calls through Code Mode.

One OpenRouter Nemotron probe returned HTTP 429, and the OpenRouter Mistral
route had no endpoint matching current privacy policy. Those explicit routes
are not configured as preferred models. A raw GPT-OSS response initially
contained reasoning without final content, but its OpenCode-native text and
tool tests passed; OpenCode behavior is the relevant acceptance boundary.

## Ownership

Global provider credentials, model catalog entries, the root default, and
hidden maintenance agents live in `~/.config/opencode/opencode.json`. Project
specialist assignments live in `.opencode/agents/*.md`. `points` must preserve
user-authored per-agent choices; this bootstrap policy is not product output.

After changing the global catalog, restart the OpenCode service with the
pass/Bifrost preflight described in `docs/opencode/12-server-clients.md`, then
verify `opencode models`, `opencode debug agents`, and representative native
runs.
