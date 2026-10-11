#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'dev config: %s\n' "$*" >&2
  exit 1
}

jq empty opencode.json || fail 'opencode.json is not valid JSON'

for key in model default_agent providers compaction warming username share update; do
  if jq -e --arg key "$key" 'has($key)' opencode.json >/dev/null; then
    fail "project opencode.json must not own global/runtime field: $key"
  fi
done
if jq -e 'has("plugins") or (.experimental? != null)' opencode.json >/dev/null; then
  fail 'project OpenCode plugins/experimental hooks require an explicit area-8 review'
fi
if find .opencode -maxdepth 1 -type f \( -name opencode.json -o -name opencode.jsonc \) |
  grep -q .; then
  fail 'use root opencode.json; duplicate .opencode config changes precedence'
fi

grep -q 'sole active OpenCode project-instruction authority' AGENTS.md ||
  fail 'AGENTS.md must declare instruction authority'
grep -q '(AGENTS.md)' CLAUDE.md ||
  fail 'CLAUDE.md must point to AGENTS.md'
if grep -Eq '^## (Identity|Project state|Source of truth|The thesis|Conventions)$' CLAUDE.md; then
  fail 'CLAUDE.md duplicates canonical project policy'
fi

agents=(
  gstack-architect
  gstack-implementer
  gstack-product
  gstack-qa
  gstack-reviewer
  gstack-security
  researcher
)
for agent in "${agents[@]}"; do
  file=".opencode/agents/${agent}.md"
  test -f "$file" || fail "missing $file"
  grep -q '^description: .' "$file" || fail "$file has no description"
  grep -q '^mode: subagent$' "$file" || fail "$file is not a subagent"
  grep -q '^model: bifrost/' "$file" || fail "$file does not use Bifrost"
  grep -q '^permissions:$' "$file" || fail "$file has no native V2 permissions"
  if grep -Eq '^(disabled|disable): true$' "$file"; then
    fail "$file is disabled"
  fi
done

for file in .opencode/agents/gstack-*.md; do
  if awk '
    /^  - action: shell$/ { shell=1; next }
    shell && /^    resource: "\*"$/ { found=1 }
    shell && /^  - action:/ { shell=0 }
    END { exit !found }
  ' "$file"; then
    fail "$file has wildcard shell access"
  fi
done

./.bin/check-ethos-evaluator-models.sh

expected_mcp='beadle biff brave-search context7 ethos lux quarry vox'
actual_mcp=$(jq -r '.mcp.servers | keys[]' opencode.json | sort | xargs)
test "$actual_mcp" = "$expected_mcp" ||
  fail "MCP roster differs: expected [$expected_mcp], got [$actual_mcp]"

grep -q 'workflows: \["CI", "Security"\]' .github/workflows/biff-notify.yml ||
  fail 'Biff notifications must watch both CI and Security workflows'

expected_skills='agent-mail ethos-mission punt-dev-doctor quarry-capture quarry-recall'
actual_skills=$(find .opencode/skills -mindepth 2 -maxdepth 2 -name SKILL.md \
  -printf '%h\n' | xargs -r -n1 basename | sort | xargs)
test "$actual_skills" = "$expected_skills" ||
  fail "project skill roster differs: expected [$expected_skills], got [$actual_skills]"

for skill in $expected_skills; do
  file=".opencode/skills/${skill}/SKILL.md"
  grep -q '^name: .' "$file" || fail "$file has no name"
  grep -q '^description: .' "$file" || fail "$file has no description"
  words=$(wc -w < "$file")
  test "$words" -le 600 || fail "$file exceeds 600 words ($words)"
  while IFS= read -r target; do
    test -e "$target" || fail "$file references missing $target"
  done < <(grep -oE '`(docs|\.punt-labs|\.opencode)/[^`]+`' "$file" | tr -d '`' || true)
done

researcher_skills=$(awk '
  /^  - action: skill$/ { skill=1; next }
  skill && /^    resource: / { print $2; skill=0 }
' .opencode/agents/researcher.md | sort | xargs)
test "$researcher_skills" = 'quarry-capture quarry-recall' ||
  fail "researcher skill allowlist differs: [$researcher_skills]"
if grep -RqsE '^description: .*' ~/.config/opencode/skills ~/.claude/skills ~/.agents/skills 2>/dev/null; then
  for skill in $expected_skills; do
    if find ~/.config/opencode/skills ~/.claude/skills ~/.agents/skills \
      -path "*/$skill/SKILL.md" -o -path "*/skills/$skill.md" 2>/dev/null | grep -q .; then
      fail "project skill $skill duplicates a global skill ID"
    fi
  done
fi

if grep -IlE '(sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----)' \
  AGENTS.md CLAUDE.md README.md opencode.json .envrc Makefile \
  .bin/* .opencode/agents/*.md .opencode/skills/*/SKILL.md \
  docs/*.md docs/opencode/*.md >/dev/null; then
  fail 'possible committed credential detected'
fi
