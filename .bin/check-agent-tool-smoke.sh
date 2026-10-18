#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'agent tool smoke: %s\n' "$*" >&2
  exit 1
}

scratch=${TMPDIR:-$PWD/.tmp/opencode}
mkdir -p "$scratch"
output=''
errors=''
session=''

cleanup() {
  if test -z "$session" && test -n "$output" && test -f "$output"; then
    session=$(jq -r 'select(.sessionID != null) | .sessionID' "$output" 2>/dev/null | head -1 || true)
  fi
  if test -n "$session"; then
    opencode session delete "$session" >/dev/null 2>&1 || true
  fi
  test -z "$output" || rm -f "$output"
  test -z "$errors" || rm -f "$errors"
  output=''
  errors=''
  session=''
}
trap cleanup EXIT HUP INT TERM

smoke() {
  local agent=$1 marker=$2 before after
  output=$(mktemp "$scratch/points-agent-smoke.XXXXXX")
  errors=$(mktemp "$scratch/points-agent-smoke-errors.XXXXXX")
  before=$(git status --porcelain=v1)

  if ! opencode run --agent "$agent" --format json \
    "Do not edit, write, patch, or otherwise change any file. Use the read tool exactly once with path go.mod, then reply exactly $marker." \
    >"$output" 2>"$errors"; then
    jq -r 'select(.type == "error") | .error.message' "$output" >&2 || true
    sed -n '1,20p' "$errors" >&2
    fail "$agent could not complete a tool-capable turn"
  fi

  session=$(jq -r 'select(.sessionID != null) | .sessionID' "$output" | head -1)
  test -n "$session" || fail "$agent smoke returned no session ID"
  jq -s -e '
    [.[] | select(.type == "tool_use" and .part.tool == "read" and .part.state.status == "completed")] as $reads
    | ($reads | length) == 1
      and ($reads[0].part.state.input.path == "go.mod")
  ' "$output" >/dev/null || fail "$agent did not complete exactly one read of go.mod"
  jq -e --arg marker "$marker" 'select(.type == "text" and .part.text == $marker)' "$output" >/dev/null \
    || fail "$agent did not return the expected marker"

  after=$(git status --porcelain=v1)
  test "$after" = "$before" || fail "$agent changed the working tree during a read-only smoke"

  cleanup
  printf 'agent tool smoke: %s completed exactly one read-only go.mod tool turn\n' "$agent"
}

smoke gstack-product PRODUCT_AGENT_TOOL_SMOKE_OK
smoke gstack-implementer IMPLEMENTER_AGENT_TOOL_SMOKE_OK
