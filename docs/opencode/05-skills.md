# OpenCode skills

## Decision

Project skills provide progressive disclosure for recurring workflows whose
details currently live in `.punt-labs/**/*.md` or canonical project docs. They
do not mirror every tool or copy full manuals. MCP server instructions continue
to carry concise tool-surface guidance; skills add decision logic, safety
boundaries, and pointers to detailed resources.

## Project catalog

| Skill | Trigger | Primary resources |
| --- | --- | --- |
| `quarry-recall` | Prior decisions, rationale, procedures, indexed knowledge | Researcher prompt, context policy, setup |
| `quarry-capture` | Durable lesson, memory, procedure, or reflection | Workflow and researcher prompt |
| `ethos-mission` | Bounded worker/evaluator delegation | Workflow, deposited Ethos operations and setup |
| `punt-dev-doctor` | Setup, service, MCP, agent, or toolchain health | Setup and OpenCode audit pages |
| `agent-mail` | Inbox, trust-aware triage, reply, or send | Deposited Beadle guide and permission policy |

Lux, Vox, Biff, Context7, and Brave do not receive project skills. Their MCP
instructions already explain when and how to use their tools; a second skill
would duplicate catalog metadata without adding a distinct workflow.

The Quarry MCP contract explicitly refers to recall and capture skills, but
neither existed in the active catalog before this audit. The two project skills
close that gap. They separate read-oriented recall from side-effecting durable
capture so trigger and permission policy remain clear.

## Permissions

The primary `build` agent may discover all project skills. Deny-all gstack
specialists receive none, which keeps their role contexts focused. The
researcher receives only `quarry-recall` and `quarry-capture`. Mission dispatch,
environment repair, and external mail remain leader-owned.

## Global compatibility catalog

OpenCode currently discovers three Punt-oriented global Claude compatibility
skills: `baseline-ops`, `create-from-project`, and `mission`. They have no
frontmatter descriptions, so OpenCode registers but does not advertise them.
Their bodies are Claude-first: they refer to `CLAUDE.md`, `Agent`, `TodoWrite`,
and historical evaluator handles. This project does not override those IDs.
The project skills use distinct IDs and current OpenCode/Ethos contracts;
upstream Ethos should migrate or retire the global compatibility skills.

The wider global catalog also contains duplicate synced skill trees. OpenCode
resolves duplicate IDs by source precedence, but duplicate on-disk packages
increase maintenance risk. They are user-level state and are not rewritten by
this repository. Area 18 should address upgrade/cache cleanup policy.

## Validation

`make check-dev` asserts the exact project skill set, required name and
description metadata, a 600-word ceiling, local resource existence, agent
permissions, and authored-file secret checks. Native runtime tests loaded every
skill. The researcher loaded both Quarry skills; build loaded mission, doctor,
and mail.

Skill descriptions are intentionally specific because their metadata is always
advertised to permitted agents while bodies load only on demand. Add a new
project skill only when it represents a recurring decision workflow that is not
already supplied by MCP instructions, `AGENTS.md`, or an existing skill.

The five skill bodies total about 1,200 words but are not part of baseline
context. Only their concise metadata is advertised to `build`; the researcher
sees only the two Quarry summaries. This is materially smaller and safer than
injecting the full `.punt-labs/**/*.md` tree.
