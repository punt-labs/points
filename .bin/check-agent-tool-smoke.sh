#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'agent tool smoke: %s\n' "$*" >&2
  exit 1
}

scratch=${TMPDIR:-$PWD/.tmp/opencode}
mkdir -p "$scratch"

smoke() {
  local agent=$1 marker=$2 output errors session=''
  output=$(mktemp "$scratch/points-agent-smoke.XXXXXX")
  errors=$(mktemp "$scratch/points-agent-smoke-errors.XXXXXX")

  cleanup_smoke() {
    if test -n "$session"; then
      opencode session delete "$session" >/dev/null 2>&1 || true
    fi
    rm -f "$output" "$errors"
  }

  if ! opencode run --agent "$agent" --format json \
    "Use the read tool exactly once to read go.mod, then reply exactly $marker." \
    >"$output" 2>"$errors"; then
    jq -r 'select(.type == "error") | .error.message' "$output" >&2 || true
    sed -n '1,20p' "$errors" >&2
    cleanup_smoke
    fail "$agent could not complete a tool-capable turn"
  fi

  session=$(jq -r 'select(.sessionID != null) | .sessionID' "$output" | head -1)
  test -n "$session" || { cleanup_smoke; fail "$agent smoke returned no session ID"; }
  jq -e 'select(.type == "tool_use" and .part.tool == "read" and .part.state.status == "completed")' "$output" >/dev/null \
    || { cleanup_smoke; fail "$agent did not complete the read tool"; }
  jq -e --arg marker "$marker" 'select(.type == "text" and .part.text == $marker)' "$output" >/dev/null \
    || { cleanup_smoke; fail "$agent did not return the expected marker"; }

  cleanup_smoke
  printf 'agent tool smoke: %s completed a real read-tool turn\n' "$agent"
}

smoke gstack-product PRODUCT_AGENT_TOOL_SMOKE_OK
smoke gstack-implementer IMPLEMENTER_AGENT_TOOL_SMOKE_OK
