#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'agent tool smoke: %s\n' "$*" >&2
  exit 1
}

scratch=${TMPDIR:-$PWD/.tmp/opencode}
mkdir -p "$scratch"
output=$(mktemp "$scratch/points-agent-smoke.XXXXXX")
errors=$(mktemp "$scratch/points-agent-smoke-errors.XXXXXX")
session=''

cleanup() {
  if test -n "$session"; then
    opencode session delete "$session" >/dev/null 2>&1 || true
  fi
  rm -f "$output" "$errors"
}
trap cleanup EXIT

if ! opencode run --agent gstack-product --format json \
  'Use the read tool exactly once to read go.mod, then reply exactly AGENT_TOOL_SMOKE_OK.' \
  >"$output" 2>"$errors"; then
  jq -r 'select(.type == "error") | .error.message' "$output" >&2 || true
  sed -n '1,20p' "$errors" >&2
  fail 'gstack-product could not complete a tool-capable turn'
fi

session=$(jq -r 'select(.sessionID != null) | .sessionID' "$output" | head -1)
test -n "$session" || fail 'smoke run returned no session ID'
jq -e 'select(.type == "tool_use" and .part.tool == "read" and .part.state.status == "completed")' "$output" >/dev/null \
  || fail 'gstack-product did not complete the read tool'
jq -e 'select(.type == "text" and .part.text == "AGENT_TOOL_SMOKE_OK")' "$output" >/dev/null \
  || fail 'gstack-product did not return the expected marker'

echo 'agent tool smoke: gstack-product completed a real read-tool turn'
