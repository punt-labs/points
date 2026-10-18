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
parent=''
child_info=''
child_messages=''
worktree=''

oc() {
  (cd "$worktree" && opencode "$@")
}

cleanup() {
  if test -z "$parent" && test -n "$output" && test -f "$output"; then
    parent=$(jq -r 'select(.sessionID != null) | .sessionID' "$output" 2>/dev/null | head -1 || true)
  fi
  if test -n "$parent" && test -n "$worktree"; then
    oc session delete "$parent" >/dev/null 2>&1 || true
  fi
  for file in "$output" "$errors" "$child_info" "$child_messages"; do
    test -z "$file" || rm -f "$file"
  done
  if test -n "$worktree"; then
    git worktree remove --force "$worktree" >/dev/null 2>&1 || true
  fi
  output=''
  errors=''
  parent=''
  child_info=''
  child_messages=''
  worktree=''
}
trap cleanup EXIT HUP INT TERM

worktree=$(mktemp -d "$scratch/points-agent-worktree.XXXXXX")
rmdir "$worktree"
git worktree add --detach "$worktree" HEAD >/dev/null

test -z "$(git -C "$worktree" status --porcelain=v1)" \
  || fail 'disposable smoke worktree did not start clean'

smoke() {
  local agent=$1 expected_model=$2 expected_variant=$3 marker=$4
  local child children
  output=$(mktemp "$scratch/points-agent-smoke.XXXXXX")
  errors=$(mktemp "$scratch/points-agent-smoke-errors.XXXXXX")
  child_info=$(mktemp "$scratch/points-agent-child.XXXXXX")
  child_messages=$(mktemp "$scratch/points-agent-messages.XXXXXX")

  if ! oc run --format json \
    "Use the $agent subagent in the foreground. Tell it: Do not edit, write, patch, or otherwise change any file. Use the read tool exactly once with path go.mod, then reply exactly $marker. After it returns, reply exactly PARENT_AGENT_TOOL_SMOKE_OK." \
    >"$output" 2>"$errors"; then
    jq -r 'select(.type == "error") | .error.message' "$output" >&2 || true
    sed -n '1,20p' "$errors" >&2
    fail "parent could not complete the $agent subagent turn"
  fi

  parent=$(jq -r 'select(.sessionID != null) | .sessionID' "$output" | head -1)
  test -n "$parent" || fail "$agent smoke returned no parent session ID"
  children=$(oc api get /api/session | jq -r --arg parent "$parent" '[.data[] | select(.parentID == $parent)] | length')
  test "$children" -eq 1 || fail "$agent smoke created $children child sessions, expected 1"
  child=$(oc api get /api/session | jq -r --arg parent "$parent" '.data[] | select(.parentID == $parent) | .id')
  oc api get "/api/session/$child" >"$child_info"
  oc api get "/api/session/$child/message" >"$child_messages"

  jq -e --arg agent "$agent" --arg model "$expected_model" --arg variant "$expected_variant" '
    .data.agent == $agent
    and (.data.model.providerID + "/" + .data.model.id) == $model
    and .data.model.variant == $variant
    and .data.outcome == "succeeded"
  ' "$child_info" >/dev/null || fail "$agent child did not use $expected_model#$expected_variant successfully"
  jq -e '
    [.data[] | select(.type == "assistant") | .content[]? | select(.type == "tool" and .name == "read" and .state.status == "completed")] as $reads
    | ($reads | length) == 1
      and ($reads[0].state.input.path == "go.mod")
  ' "$child_messages" >/dev/null || fail "$agent child did not complete exactly one read of go.mod"
  jq -e --arg marker "$marker" '
    any(.data[] | select(.type == "assistant") | .content[]?; .type == "text" and .text == $marker)
  ' "$child_messages" >/dev/null || fail "$agent child did not return the expected marker"

  test -z "$(git -C "$worktree" status --porcelain=v1)" \
    || fail "$agent changed the disposable read-only smoke worktree"

  oc session delete "$parent" >/dev/null
  parent=''
  rm -f "$output" "$errors" "$child_info" "$child_messages"
  output=''
  errors=''
  child_info=''
  child_messages=''
  printf 'agent tool smoke: %s completed %s#%s with one read-only go.mod tool turn\n' \
    "$agent" "$expected_model" "$expected_variant"
}

smoke gstack-product bifrost/openai/gpt-6-astra medium PRODUCT_AGENT_TOOL_SMOKE_OK
smoke gstack-implementer bifrost/openai/gpt-5.6-sol high IMPLEMENTER_AGENT_TOOL_SMOKE_OK
