#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo 'usage: extract-subagent-result.sh <session-id> <mission-id> <round> <output-file>' >&2
  exit 2
}

test "$#" -eq 4 || usage
session=$1
mission=$2
round=$3
output=$4

case "$session" in ses_*) ;; *) usage ;; esac
case "$mission" in m-????-??-??-???) ;; *) usage ;; esac
case "$round" in ''|*[!0-9]*) usage ;; esac

scratch=${TMPDIR:-$PWD/.tmp/opencode}
mkdir -p "$scratch"
exported=$(mktemp "$scratch/points-subagent-export.XXXXXX")
candidate=$(mktemp "$scratch/points-subagent-result.XXXXXX")
trap 'rm -f "$exported" "$candidate"' EXIT
trap 'exit 1' HUP INT TERM

opencode session export "$session" >"$exported"
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

grep -Fxq "mission: $mission" "$candidate" || {
  echo "extract result: latest assistant artifact does not declare expected mission $mission" >&2
  exit 1
}
grep -Fxq "round: $round" "$candidate" || {
  echo "extract result: latest assistant artifact does not declare expected round $round" >&2
  exit 1
}

mkdir -p "$(dirname "$output")"
cp "$candidate" "$output"
echo "extract result: validated $mission round $round artifact from $session -> $output"
