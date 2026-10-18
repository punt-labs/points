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

expected_path=$(realpath "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/plugins/herdr-agent-state.js")
expected_sha='f70a7d2193f4a9409838b078acee5a35f72f0925af08f63c142ec9cbf0ba5fcd'
actual_sha=$(sha256sum "$expected_path" | awk '{print $1}')
test "$actual_sha" = "$expected_sha" || fail "herdr.opencode integration hash changed; review the update and refresh the allowlist: $expected_path"
grep -Fxq '// HERDR_INTEGRATION_ID=opencode' "$expected_path" || fail 'herdr.opencode integration ID marker is missing'
grep -Fxq '// HERDR_INTEGRATION_VERSION=13' "$expected_path" || fail 'herdr.opencode integration version is not the reviewed version 13'

bad=$(jq -r --arg expected "$expected_path" '
  .data[]
  | select(
      .state.status != "active"
      or (
        .source.type != "builtin"
        and (
          .id != "herdr.opencode"
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

herdr=$(jq -r --arg expected "$expected_path" '[.data[] | select(.id == "herdr.opencode" and .source.type == "local" and .source.path == $expected and .state.status == "active")] | length' "$inventory")
test "$herdr" -eq 1 || fail 'expected one active reviewed herdr.opencode integration'

echo 'live plugins: built-ins and reviewed herdr.opencode path/version/hash are active'
