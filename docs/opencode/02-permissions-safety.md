# OpenCode 2 Permissions and Safety

This records area 2 of the OpenCode configuration audit. The policy adapts the
canonical Claude permission boundary and the Ethos role tool allowlists to
OpenCode 2's ordered rules. The last matching rule wins.

## Primary Build Agent

The built-in `build` agent remains the workflow leader with broad development
access. Project rules add boundaries at the end of its resolved rule list:

- Deny edits to `.env`, `.env.*`, `.envrc`, and `.envrc.local`.
- Deny recursive deletion rooted at `/` or the home directory.
- Ask before `sudo`, `su`, `dd`, raw network clients, remote shells, and
  `direnv allow`.
- Ask before Git pushes, releases, package publication, email, Biff
  outbound communication, Ethos mission mutation, and session movement.
- Deny Desktop browser tools until a user-visible browser workflow is requested
  and reviewed.

Routine repository reads, edits, tests, local Git operations, Beads work, and
specialist delegation remain available. The operator approves effects that
cross privilege, network, publication, communication, or session boundaries.
PR merges are leader-owned and do not prompt; the merge gate in
`docs/WORKFLOW.md` is their authorization. Releases remain approval-gated.

## Specialist Baseline

Every gstack specialist starts with deny-all, then receives an explicit
allowlist:

- Local `read`, `glob`, `grep`, and `shell`
- External-directory reads required for references and sibling standards
- No nested subagents

The Ethos role files define a scoped Quarry/Biff/Ethos MCP subset. OpenCode
2.0.26 accepted equivalent permission rules syntactically but did not offer the
allowed Context7 tool to a restarted child session. Because positive MCP grants
were not effective in runtime tests, specialists receive no MCP tools in this
exemplar. The leader owns MCP research and passes evidence into mission context.
Future Ethos generation may restore the role subset only after a positive child
session proves each normalized action is available.

What is absent is the boundary:

- No Beadle mail or contact mutation
- No Biff write, wall, or talk
- No Ethos mission dispatch, ADR, team, role, vendor, or attribute mutation
- No Lux display mutation
- No Vox controls
- No OpenCode session mutation
- No browser, Brave, Context7, or other MCP access

## Role Exceptions

| Agent | Additional access |
| --- | --- |
| `gstack-implementer` | Repository file edits |
| All other specialists | No additional tools |

## Researcher

`.opencode/agents/researcher.md` adapts Quarry's shipped Claude plugin agent at
`../quarry/plugin/agents/researcher.md`. It is a separate research specialist,
not a gstack worker/evaluator identity.

It receives local read/search, Quarry research and capture tools, Context7,
Brave, web search/fetch, and Desktop browser access. It receives no project
edits, shell, communication, session mutation, or nested delegation. Research
is therefore concentrated in one explicit role rather than granting every
specialist broad external access.

OpenCode exposes MCP tools to models through its `execute` Code Mode gateway.
The researcher's deny-all policy originally allowed the qualified Quarry and
Context7 actions but omitted `execute`, so the child could not discover or call
them. Allowing `execute` fixed the configuration. A fresh native
`build`-to-`researcher` call then invoked `tools.quarry.status` and
`tools.context7.resolve-library-id`, returning 2,272 Quarry documents and the
Context7 library ID `/anomalyco/opencode`.

Shell is retained because all six roles need deterministic repository commands,
tests, Git inspection, and installed-artifact checks. It is restricted to the
reviewed command families documented in `docs/opencode/09-tools.md`; wildcard
specialist shell access is forbidden by `make check-dev`. Agent instructions
still forbid workflow ownership by workers; permission availability is not
authority to push, publish, dispatch, or merge.

OpenCode 2.0.26 appends a final `browser: deny` rule to file-defined subagents,
after their configured permissions. A QA-local browser allow is therefore
ineffective under last-match semantics. The primary leader owns Desktop browser
execution and passes captured evidence to `gstack-qa` until OpenCode provides a
supported subagent override point.

## Secret Boundary

The primary agent cannot edit secret environment files. Reading `.env` patterns
retains OpenCode's built-in ask rules. Secrets are supplied through `pass`,
direnv, and private OpenCode service state as documented in
`docs/opencode/12-server-clients.md`.

OpenCode permissions cannot prevent a permitted shell command from reading its
own inherited environment. Therefore:

- Specialist prompts must not request environment dumps.
- Evidence commands report presence or classification, never values.
- `make check` and review include secret-pattern scans where appropriate.
- Provider credentials are rotated after configuration stabilizes.

## Validation

Inspect the effective ordered rules:

```sh
opencode debug agents
```

For each specialist, verify deny-all precedes its allowlist, only the implementer
has `edit: allow`, and every specialist lacks `subagent` permission.

Runtime denial tests use disposable child sessions. They attempt one denied file
edit and one denied outbound tool call without actually sending or publishing
anything. A refusal is the passing result. Allowed read and shell smoke tests
must still pass.

The repository quality gate remains:

```sh
make check
```
