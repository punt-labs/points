# Punt Labs Team

Shared identity registry for Punt Labs. Every project references this
repo as a git submodule at `.punt-labs/ethos/`, giving all tools access
to the same team of humans and AI agents.

## The Team

| Handle | Name | Kind | Personality | Role | Inspired By |
|--------|------|------|-------------|------|-------------|
| **jfreeman** | Jim Freeman | human | principal-engineer | CEO | — |
| **claude** | Claude Agento | agent | friendly-direct | COO / VP Eng | L.L. Zamenhof |
| **bwk** | Brian K | agent | kernighan | Go specialist | Brian Kernighan |
| **mdm** | Doug M | agent | mcilroy | CLI specialist | Doug McIlroy |
| **djb** | Dan B | agent | bernstein | Security engineer | Dan Bernstein |
| **adt** | Alan T | agent | turing | PM (grounding) | Alan Turing |
| **ghr** | Grace H | agent | hopper | PM (building blocks) | Grace Hopper |
| **edt** | Edward T | agent | tufte | UX designer | Edward Tufte |
| **ach** | Alex H | agent | hamilton | Finance & ops | Alexander Hamilton |
| **adb** | Ada B | agent | lovelace | Infra engineer | Ada Lovelace |

## Teams

**Engineering** — ethos, biff, quarry, beadle, vox, lux, punt-kit, z-spec, prfaq

```text
jfreeman (CEO)
  └─ claude (COO)
       ├─ bwk (Go specialist)
       ├─ mdm (CLI specialist)
       ├─ rmh (Python specialist)
       ├─ djb (Security engineer)
       └─ adb (Infra engineer)
```

**Website** — public-website

```text
jfreeman (CEO)
  ├─ claude (COO)
  │    └─ edt (UX designer)
  └─ ghr (PM building blocks)
```

## Structure

```text
identities/          10 identity YAMLs (handle, kind, personality, writing style, talents)
personalities/       11 personality .md files (behavioral instructions)
writing-styles/      11 writing style .md files (communication rules)
talents/             10 talent .md files (domain expertise)
roles/               10 role YAMLs (responsibilities, permissions)
teams/                2 team YAMLs (members, collaborations, repositories)
agents/               8 Claude Code agent definitions (.md with frontmatter)
config.yaml           default agent persona
```

## How It Works

Each project adds this repo as a submodule:

```bash
git submodule add git@github.com:punt-labs/team.git .punt-labs/ethos
```

Ethos reads from `.punt-labs/ethos/` automatically — identities,
personalities, writing styles, talents, roles, and teams all resolve
from the submodule. No configuration needed.

When a Claude Code session starts, the ethos SessionStart hook:

1. Resolves the agent's identity from the submodule
2. Injects the full personality and writing style into session context
3. Installs agent definitions from `agents/` into `.claude/agents/`

Subagents (bwk, mdm, djb, etc.) get their persona injected
automatically at spawn time via the SubagentStart hook.

## Adding a New Team Member

1. Create the identity: `identities/<handle>.yaml`
2. Create the personality: `personalities/<name>.md`
3. Create the writing style: `writing-styles/<name>-prose.md`
4. Create the agent definition: `agents/<handle>.md`
5. Create the role: `roles/<role-name>.yaml`
6. Add to a team: edit `teams/<team>.yaml`
7. Commit, push, and run `git submodule update` in consuming repos

## Design

Teams and roles are formally specified in Z notation. The specification
type-checks with fuzz and animates with probcli. See
[ethos/docs/teams.tex](https://github.com/punt-labs/ethos/blob/main/docs/teams.tex)
for the formal model.

Key invariants enforced by ethos:

- Every team member references a valid identity and role
- Every team has at least one member
- Collaborations reference roles filled by team members
- No self-collaboration
- Referential integrity on role deletion
