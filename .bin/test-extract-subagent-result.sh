#!/usr/bin/env bash
set -euo pipefail

root=$(mktemp -d "${TMPDIR:-$PWD/.tmp/opencode}/points-extract-test.XXXXXX")
trap 'rm -rf "$root"' EXIT HUP INT TERM
mkdir -p "$root/bin"
cat >"$root/bin/opencode" <<'SH'
#!/usr/bin/env bash
cat "$FAKE_EXPORT"
SH
chmod +x "$root/bin/opencode"
export PATH="$root/bin:$PATH"

fixture() {
  local file=$1 sid=$2 agent=$3 text=$4
  jq -n --arg sid "$sid" --arg agent "$agent" --arg text "$text" '{info:{id:$sid,agent:$agent},messages:[{type:"assistant",time:{completed:2},content:[{type:"text",text:$text}]}]}' >"$file"
}

valid='--- ethos-result ---
mission: m-2026-10-18-099
round: 2
author: gstack-architect
--- end-ethos-result ---
body may quote:
mission: m-2026-10-18-001
round: 1'
fixture "$root/valid.json" ses_valid gstack-architect "$valid"
FAKE_EXPORT="$root/valid.json" ./.bin/extract-subagent-result.sh ses_valid m-2026-10-18-099 2 gstack-architect "$root/out.md" >/dev/null
cmp -s "$root/out.md" <(printf '%s\n' "$valid")

wrong='--- ethos-result ---
mission: m-2026-10-18-001
round: 1
author: gstack-architect
--- end-ethos-result ---
quoted expected values:
mission: m-2026-10-18-099
round: 2'
fixture "$root/wrong.json" ses_wrong gstack-architect "$wrong"
if FAKE_EXPORT="$root/wrong.json" ./.bin/extract-subagent-result.sh ses_wrong m-2026-10-18-099 2 gstack-architect "$root/wrong.md" >/dev/null 2>&1; then exit 1; fi
fixture "$root/agent.json" ses_agent gstack-reviewer "$valid"
if FAKE_EXPORT="$root/agent.json" ./.bin/extract-subagent-result.sh ses_agent m-2026-10-18-099 2 gstack-architect "$root/agent.md" >/dev/null 2>&1; then exit 1; fi
fixture "$root/session.json" ses_other gstack-architect "$valid"
if FAKE_EXPORT="$root/session.json" ./.bin/extract-subagent-result.sh ses_session m-2026-10-18-099 2 gstack-architect "$root/session.md" >/dev/null 2>&1; then exit 1; fi
fixture "$root/duplicate.json" ses_dup gstack-architect "$valid
--- ethos-result ---"
if FAKE_EXPORT="$root/duplicate.json" ./.bin/extract-subagent-result.sh ses_dup m-2026-10-18-099 2 gstack-architect "$root/dup.md" >/dev/null 2>&1; then exit 1; fi

echo 'extract subagent result tests: PASS'
