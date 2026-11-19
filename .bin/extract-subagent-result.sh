#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo 'usage: extract-subagent-result.sh <session-id> <mission-id> <round> <author> <output-file>' >&2
  exit 2
}

test "$#" -eq 5 || usage
session=$1
mission=$2
round=$3
author=$4
output=$5

case "$session" in ses_*) ;; *) usage ;; esac
case "$mission" in m-????-??-??-???) ;; *) usage ;; esac
case "$round" in ''|*[!0-9]*) usage ;; esac
case "$author" in gstack-*) ;; *) usage ;; esac

scratch=${TMPDIR:-$PWD/.tmp/opencode}
mkdir -p "$scratch"
exported=$(mktemp "$scratch/points-subagent-export.XXXXXX")
candidate=$(mktemp "$scratch/points-subagent-result.XXXXXX")
expected=$(mktemp "$scratch/points-subagent-header.XXXXXX")
trap 'rm -f "$exported" "$candidate" "$expected"' EXIT
trap 'exit 1' HUP INT TERM

opencode session export "$session" >"$exported"
jq -e --arg session "$session" --arg author "$author" '
  .info.id == $session and .info.agent == $author
' "$exported" >/dev/null || {
  echo "extract result: exported session identity/agent does not match $session/$author" >&2
  exit 1
}

jq -r '
  [.messages[]
    | select(.type == "assistant" and .time.completed != null)
    | {
        completed: .time.completed,
        text: ([.content[]? | select(.type == "text") | .text] | join("\n"))
      }
    | select(.text != "")]
  | sort_by(.completed)
  | last.text // empty
' "$exported" >"$candidate"

test -s "$candidate" || {
  echo "extract result: session $session has no completed assistant text" >&2
  exit 1
}

cat >"$expected" <<HEADER
--- ethos-result ---
mission: $mission
round: $round
author: $author
--- end-ethos-result ---
HEADER

cmp -s "$expected" <(head -n 5 "$candidate") || {
  echo "extract result: latest assistant artifact has the wrong result header" >&2
  exit 1
}
test "$(grep -Fxc -- '--- ethos-result ---' "$candidate")" -eq 1 || {
  echo 'extract result: artifact contains duplicate result headers' >&2
  exit 1
}
test "$(grep -Fxc -- '--- end-ethos-result ---' "$candidate")" -eq 1 || {
  echo 'extract result: artifact contains duplicate result trailers' >&2
  exit 1
}

mkdir -p "$(dirname "$output")"
cp "$candidate" "$output"
echo "extract result: validated $mission round $round author $author from $session -> $output"
