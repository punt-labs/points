#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'live models: %s\n' "$*" >&2
  exit 1
}

command -v opencode >/dev/null || fail 'opencode is not installed'
command -v jq >/dev/null || fail 'jq is not installed'

catalog=$(mktemp "${TMPDIR:-/tmp}/points-models.XXXXXX")
trap 'rm -f "$catalog"' EXIT
opencode models >"$catalog"

check() {
  local owner=$1 model=$2
  test -n "$model" || fail "$owner has no explicit model"
  grep -Fxq "$model" "$catalog" || fail "$owner model is unavailable: $model"
}

for file in .opencode/agents/*.md; do
  model=$(sed -n 's/^model: //p' "$file")
  check "${file%.md}" "$model"
done

global=${XDG_CONFIG_HOME:-$HOME/.config}/opencode/opencode.json
test -f "$global" || fail "missing global config: $global"
check 'global default' "$(jq -r '.model // empty' "$global")"
for role in title compaction summary; do
  check "global $role" "$(jq -r --arg role "$role" '.agents[$role].model // empty' "$global")"
done

echo 'live models: all configured project and maintenance models are available'
