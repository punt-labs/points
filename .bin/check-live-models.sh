#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'live models: %s\n' "$*" >&2
  exit 1
}

command -v opencode >/dev/null || fail 'opencode is not installed'
command -v jq >/dev/null || fail 'jq is not installed'
command -v curl >/dev/null || fail 'curl is not installed'
test -n "${BIFROST_VK:-}" || fail 'BIFROST_VK is not loaded; run through direnv'

scratch=${TMPDIR:-$PWD/.tmp/opencode}
mkdir -p "$scratch"
catalog=$(mktemp "$scratch/points-opencode-models.XXXXXX")
upstream=$(mktemp "$scratch/points-bifrost-models.XXXXXX")
runtime=$(mktemp "$scratch/points-runtime-agents.XXXXXX")
effective=$(mktemp "$scratch/points-effective-models.XXXXXX")
trap 'rm -f "$catalog" "$upstream" "$runtime" "$effective"' EXIT

opencode models >"$catalog"
opencode debug agents 2>/dev/null | jq -r '.[] | select(.model != null) | [.id, (.model.providerID + "/" + .model.id)] | @tsv' >"$runtime"

# Extract only model references from loaded config sources. Never materialize or
# print the rest of /api/config/debug config because provider settings may contain
# resolved credentials.
opencode debug config 2>/dev/null | jq -r '
  reduce .[] as $source (
    {default: null, title: null, compaction: null, summary: null};
    .default = ($source.info.model // .default)
    | .title = ($source.info.agents.title.model // .title)
    | .compaction = ($source.info.agents.compaction.model // .compaction)
    | .summary = ($source.info.agents.summary.model // .summary)
  )
  | to_entries[]
  | select(.value != null)
  | [.key, (.value.providerID + "/" + .value.model)]
  | @tsv
' >"$effective"

base=$(jq -r '.providers.bifrost.settings.baseURL // empty' "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/opencode.json")
test -n "$base" || fail 'global Bifrost baseURL is missing'
root=${base%/openai/v1}
curl -fsS --max-time 30 -H "Authorization: Bearer $BIFROST_VK" "$root/v1/models" \
  | jq -r '.data[]?.id' >"$upstream" \
  || fail 'could not fetch authenticated Bifrost model catalog'

test -s "$upstream" || fail 'Bifrost model catalog is empty'

check_available() {
  local owner=$1 model=$2 served
  test -n "$model" || fail "$owner has no explicit model"
  grep -Fxq "$model" "$catalog" || fail "$owner model is absent from OpenCode catalog: $model"
  case "$model" in
    bifrost/*)
      served=${model#bifrost/}
      grep -Fxq "$served" "$upstream" || fail "$owner model is not served by live Bifrost: $model"
      ;;
  esac
}

runtime_model() {
  awk -F '\t' -v id="$1" '$1 == id { print $2; exit }' "$runtime"
}

effective_model() {
  awk -F '\t' -v role="$1" '$1 == role { print $2; exit }' "$effective"
}

for file in .opencode/agents/*.md; do
  id=$(basename "${file%.md}")
  configured=$(sed -n 's/^model: //p' "$file")
  loaded=$(runtime_model "$id")
  check_available "$id configured" "$configured"
  test "$loaded" = "$configured" || fail "$id loaded model differs from configured model: loaded=${loaded:-<missing>} configured=$configured; reload or restart OpenCode"
  check_available "$id loaded" "$loaded"
done

for role in default title compaction summary; do
  model=$(effective_model "$role")
  check_available "effective $role" "$model"
  if test "$role" != default; then
    loaded=$(runtime_model "$role")
    test "$loaded" = "$model" || fail "$role runtime model differs from effective config: loaded=${loaded:-<missing>} configured=$model; reload or restart OpenCode"
  fi
done

echo 'live models: configured, effective, runtime, and Bifrost-served models agree'
