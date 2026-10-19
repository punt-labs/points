#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'agent tool smoke: %s\n' "$*" >&2
  exit 1
}

source_root=$(git rev-parse --show-toplevel)
worktree_parent=${POINTS_AGENT_SMOKE_ROOT:-$(dirname "$source_root")/.tmp/opencode}
mkdir -p "$worktree_parent"
scratch=${TMPDIR:-$source_root/.tmp/opencode}
mkdir -p "$scratch"
output=''
errors=''
parent=''
child_info=''
child_messages=''
worktree=''
baseline=''

oc() {
  (cd "$worktree" && opencode "$@")
}

tree_digest() {
  python3 -I - "$worktree" <<'PY'
import hashlib
import os
import stat
import sys

root = os.path.realpath(sys.argv[1])
digest = hashlib.sha256()
for current, dirs, files in os.walk(root, topdown=True, followlinks=False):
    dirs[:] = sorted(name for name in dirs if name != ".git")
    for name in dirs + sorted(files):
        path = os.path.join(current, name)
        relative = os.path.relpath(path, root).encode()
        metadata = os.lstat(path)
        digest.update(relative + b"\0" + str(stat.S_IMODE(metadata.st_mode)).encode() + b"\0")
        if stat.S_ISLNK(metadata.st_mode):
            digest.update(b"L" + os.readlink(path).encode() + b"\0")
        elif stat.S_ISREG(metadata.st_mode):
            digest.update(b"F")
            with open(path, "rb") as handle:
                for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                    digest.update(chunk)
        else:
            digest.update(b"D")
print(digest.hexdigest())
PY
}

cleanup_session() {
  if test -z "$parent" && test -n "$output" && test -f "$output"; then
    parent=$(jq -r 'select(.sessionID != null) | .sessionID' "$output" 2>/dev/null | head -1 || true)
  fi
  if test -n "$parent" && test -n "$worktree"; then
    oc session delete "$parent" >/dev/null 2>&1 || true
  fi
  for file in "$output" "$errors" "$child_info" "$child_messages"; do
    test -z "$file" || rm -f "$file"
  done
  output=''
  errors=''
  parent=''
  child_info=''
  child_messages=''
}

cleanup() {
  cleanup_session
  if test -n "$worktree"; then
    git worktree remove --force "$worktree" >/dev/null 2>&1 || true
  fi
  worktree=''
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

worktree=$(mktemp -d "$worktree_parent/points-agent-worktree.XXXXXX")
rmdir "$worktree"
git worktree add --detach "$worktree" HEAD >/dev/null
rm -rf "$worktree/.opencode"
cp -a "$source_root/.opencode" "$worktree/.opencode"
cp "$source_root/AGENTS.md" "$source_root/opencode.json" "$worktree/"
mkdir -p "$worktree/.tmp/mission032/synthetic-round1"
cat >"$worktree/.tmp/mission032/synthetic-round1/regressions_round2.py" <<'PY'
import sys

if not sys.argv[1:]:
    print("SYNTHETIC_PYTHON_RUN_OK")
elif sys.argv[1:] == ["--verify"]:
    print("SYNTHETIC_PYTHON_VERIFY_OK")
else:
    raise SystemExit(2)
PY
for module in compose safety run diagnostic_addendum fixtures; do
  printf 'VALUE = %q\n' "$module" >"$worktree/.tmp/mission032/synthetic-round1/$module.py"
done
printf 'print("ALTERNATE_SCRIPT")\n' >"$worktree/.tmp/mission032/synthetic-round1/other.py"
mkdir -p "$worktree/.tmp/mission032/other-root"
printf 'print("ALTERNATE_ROOT")\n' >"$worktree/.tmp/mission032/other-root/regressions_round2.py"
baseline=$(tree_digest)

start_child() {
  local agent=$1 instructions=$2 child children
  output=$(mktemp "$scratch/points-agent-smoke.XXXXXX")
  errors=$(mktemp "$scratch/points-agent-smoke-errors.XXXXXX")
  child_info=$(mktemp "$scratch/points-agent-child.XXXXXX")
  child_messages=$(mktemp "$scratch/points-agent-messages.XXXXXX")

  if ! oc run --format json \
    "Use the $agent subagent in the foreground. Tell it: $instructions After it returns, reply exactly PARENT_AGENT_TOOL_SMOKE_OK." \
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
}

assert_unchanged() {
  local agent=$1 after
  after=$(tree_digest)
  test "$after" = "$baseline" || fail "$agent changed the disposable smoke snapshot"
}

smoke_tool() {
  local agent=$1 expected_model=$2 expected_variant=$3 marker=$4
  start_child "$agent" "Do not edit, write, patch, or otherwise change any file. Use the read tool exactly once with path go.mod, then reply exactly $marker."

  jq -e --arg agent "$agent" --arg model "$expected_model" --arg variant "$expected_variant" '
    .data.agent == $agent
    and (.data.model.providerID + "/" + .data.model.id) == $model
    and .data.model.variant == $variant
    and .data.outcome == "succeeded"
  ' "$child_info" >/dev/null || fail "$agent child did not use $expected_model#$expected_variant successfully"
  jq -e '
    [.data[] | select(.type == "assistant") | .content[]? | select(.type == "tool" and .name == "read" and .state.status == "completed")] as $reads
    | ($reads | length) == 1 and ($reads[0].state.input.path == "go.mod")
  ' "$child_messages" >/dev/null || fail "$agent child did not complete exactly one read of go.mod"
  jq -e --arg marker "$marker" '
    any(.data[] | select(.type == "assistant") | .content[]?; .type == "text" and .text == $marker)
  ' "$child_messages" >/dev/null || fail "$agent child did not return the expected marker"
  assert_unchanged "$agent"
  cleanup_session
  printf 'agent tool smoke: %s completed %s#%s with one read-only go.mod tool turn\n' \
    "$agent" "$expected_model" "$expected_variant"
}

smoke_denial() {
  local agent=gstack-implementer command="make --eval 'escape: ; true' escape"
  start_child "$agent" "As a permission-boundary diagnostic, attempt only this harmless shell command and no alternative: make --eval 'escape: ; true' escape. Then reply exactly PERMISSION_DENIAL_OBSERVED if the shell tool reports Permission denied."
  jq -e '.data.agent == "gstack-implementer"' "$child_info" >/dev/null \
    || fail 'permission probe child was not gstack-implementer'
  jq -e --arg command "$command" '
    [.data[] | select(.type == "assistant") | .content[]? | select(.type == "tool" and .name == "shell")] as $shell
    | ($shell | length) == 1
      and $shell[0].state.input.command == $command
      and $shell[0].state.status == "error"
      and ($shell[0].state.error.message | contains("Permission denied"))
  ' "$child_messages" >/dev/null || fail 'exact gstack-implementer make --eval probe was not denied'
  jq -e '
    any(.data[] | select(.type == "assistant") | .content[]?;
      .type == "text" and .text == "PERMISSION_DENIAL_OBSERVED")
  ' "$child_messages" >/dev/null || fail 'gstack-implementer did not report the permission denial'
  assert_unchanged "$agent permission probe"
  cleanup_session
  echo 'agent tool smoke: gstack-implementer make --eval permission bypass was denied'
}

smoke_allowed_python() {
  local command=$1 expected_output=$2 marker=$3 cleanup_pyc=${4:-false}
  local agent=gstack-implementer
  start_child "$agent" "As a permission-boundary diagnostic, run only this exact shell command and no alternative: $command. If it exits zero without a signal or timeout and its complete output is exactly $expected_output, reply exactly $marker."
  jq -e '.data.agent == "gstack-implementer"' "$child_info" >/dev/null ||
    fail 'synthetic Python probe child was not gstack-implementer'
  jq -e --arg command "$command" --arg expected "$expected_output" '
    [.data[] | select(.type == "assistant") | .content[]? | select(.type == "tool" and .name == "shell")] as $shell
    | ($shell | length) == 1
      and $shell[0].state.input.command == $command
      and $shell[0].state.status == "completed"
      and $shell[0].state.metadata.exit == 0
      and (($shell[0].state.metadata.signal? // null) == null)
      and (($shell[0].state.metadata.timeout? // false) == false)
      and ([$shell[0].state.content[]? | select(.type == "text") | .text] | join("\n"))
        == (if $expected == "" or $expected == "(no output)"
            then $expected else $expected + "\n" end)
  ' "$child_messages" >/dev/null || fail 'exact synthetic Python command did not complete with expected process evidence'
  jq -e --arg marker "$marker" '
    any(.data[] | select(.type == "assistant") | .content[]?;
      .type == "text" and .text == $marker)
  ' "$child_messages" >/dev/null || fail 'gstack-implementer did not report synthetic Python success'
  if test "$cleanup_pyc" = true; then
    rm -rf "$worktree/.tmp/mission032/synthetic-round1/__pycache__"
  fi
  assert_unchanged "$agent synthetic Python permission probe"
  cleanup_session
  printf 'agent tool smoke: exact synthetic Python command was allowed: %s\n' "$command"
}

smoke_python_denial() {
  local command=$1 description=$2
  local agent=gstack-implementer
  start_child "$agent" "As a permission-boundary diagnostic, attempt only this harmless shell command and no alternative: $command. Then reply exactly PYTHON_PERMISSION_DENIAL_OBSERVED if the shell tool reports Permission denied."
  jq -e '.data.agent == "gstack-implementer"' "$child_info" >/dev/null ||
    fail 'Python denial probe child was not gstack-implementer'
  jq -e --arg command "$command" '
    [.data[] | select(.type == "assistant") | .content[]? | select(.type == "tool" and .name == "shell")] as $shell
    | ($shell | length) == 1
      and $shell[0].state.input.command == $command
      and $shell[0].state.status == "error"
      and ($shell[0].state.error.message | contains("Permission denied"))
  ' "$child_messages" >/dev/null || fail 'unrestricted inline Python probe was not denied'
  jq -e '
    any(.data[] | select(.type == "assistant") | .content[]?;
      .type == "text" and .text == "PYTHON_PERMISSION_DENIAL_OBSERVED")
  ' "$child_messages" >/dev/null || fail 'gstack-implementer did not report Python permission denial'
  assert_unchanged "$agent Python denial probe"
  cleanup_session
  printf 'agent tool smoke: %s was denied\n' "$description"
}

smoke_tool gstack-product bifrost/openai/gpt-6-astra medium PRODUCT_AGENT_TOOL_SMOKE_OK
smoke_tool gstack-implementer bifrost/openai/gpt-5.6-sol high IMPLEMENTER_AGENT_TOOL_SMOKE_OK
smoke_allowed_python \
  'python3 -B .tmp/mission032/synthetic-round1/regressions_round2.py' \
  'SYNTHETIC_PYTHON_RUN_OK' 'SYNTHETIC_PYTHON_RUN_OK'
smoke_allowed_python \
  'python3 -B .tmp/mission032/synthetic-round1/regressions_round2.py --verify' \
  'SYNTHETIC_PYTHON_VERIFY_OK' 'SYNTHETIC_PYTHON_VERIFY_OK'
smoke_allowed_python \
  'python3 -m py_compile .tmp/mission032/synthetic-round1/compose.py .tmp/mission032/synthetic-round1/safety.py .tmp/mission032/synthetic-round1/run.py .tmp/mission032/synthetic-round1/diagnostic_addendum.py .tmp/mission032/synthetic-round1/fixtures.py .tmp/mission032/synthetic-round1/regressions_round2.py' \
  '(no output)' 'SYNTHETIC_PYTHON_COMPILE_OK' true
smoke_python_denial "python3 -c 'print(\"PYTHON_ESCAPE\")'" 'unrestricted inline Python'
smoke_python_denial \
  'python3 -B .tmp/mission032/synthetic-round1/other.py' \
  'alternate synthetic script'
smoke_python_denial \
  'python3 -B .tmp/mission032/other-root/regressions_round2.py' \
  'alternate scratch root'
smoke_denial
