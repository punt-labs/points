#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'live plugins: %s\n' "$*" >&2
  exit 1
}

inventory=$(mktemp "${TMPDIR:-/tmp}/points-plugins.XXXXXX")
trap 'rm -f "$inventory"' EXIT
opencode api get /api/plugin >"$inventory"

bad=$(jq -r '
  .data[]
  | select(
      .state.status != "active"
      or (
        .source.type != "builtin"
        and (.id != "herdr.opencode" or .source.type != "local")
      )
    )
  | [.id, .source.type, .state.status, (.source.path // .source.target // "-")] | @tsv
' "$inventory")

if test -n "$bad"; then
  printf 'live plugins: unapproved or unhealthy plugin inventory:\n%s\n' "$bad" >&2
  exit 1
fi

herdr=$(jq -r '[.data[] | select(.id == "herdr.opencode" and .source.type == "local" and .state.status == "active")] | length' "$inventory")
test "$herdr" -eq 1 || fail 'expected one active herdr.opencode integration'

echo 'live plugins: built-ins and approved herdr.opencode integration are active'
