#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'live plugins: %s\n' "$*" >&2
  exit 1
}

scratch=${TMPDIR:-$PWD/.tmp/opencode}
mkdir -p "$scratch"
inventory=$(mktemp "$scratch/points-plugins.XXXXXX")
trap 'rm -f "$inventory"' EXIT
opencode api get /api/plugin >"$inventory"

herdr_count=$(jq -r '[.data[] | select(.id == "herdr.opencode")] | length' "$inventory")
test "$herdr_count" -le 1 || fail 'multiple herdr.opencode plugins are active'

expected_path=''
if test "$herdr_count" -eq 1; then
  expected_path=$(realpath "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/plugins/herdr-agent-state.js")
  expected_sha='f70a7d2193f4a9409838b078acee5a35f72f0925af08f63c142ec9cbf0ba5fcd'
  actual_sha=$(sha256sum "$expected_path" | awk '{print $1}')
  test "$actual_sha" = "$expected_sha" || fail "herdr.opencode integration hash changed; review the update and refresh the allowlist: $expected_path"
  grep -Fxq '// HERDR_INTEGRATION_ID=opencode' "$expected_path" || fail 'herdr.opencode integration ID marker is missing'
  grep -Fxq '// HERDR_INTEGRATION_VERSION=13' "$expected_path" || fail 'herdr.opencode integration version is not the reviewed version 13'
fi

bad=$(jq -r --arg expected "$expected_path" '
  .data[]
  | select(
      .state.status != "active"
      or (
        .source.type != "builtin"
        and (
          $expected == ""
          or .id != "herdr.opencode"
          or .source.type != "local"
          or .source.path != $expected
        )
      )
    )
  | [.id, .source.type, .state.status, (.source.path // .source.target // "-")] | @tsv
' "$inventory")

if test -n "$bad"; then
  printf 'live plugins: unapproved or unhealthy plugin inventory:\n%s\n' "$bad" >&2
  exit 1
fi

if test "$herdr_count" -eq 1; then
  echo 'live plugins: built-ins and reviewed optional herdr.opencode path/version/hash are active'
else
  echo 'live plugins: built-ins are active; optional herdr.opencode is not installed'
fi
