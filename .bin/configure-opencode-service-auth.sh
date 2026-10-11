#!/usr/bin/env bash
# Configure OpenCode's shared background service with pass-backed Basic auth.

set -euo pipefail

password_path=${OPENCODE_SERVER_PASSWORD_PATH:-opencode/server-password}

for command in pass opencode; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "configure-opencode-service-auth: $command not found" >&2
    exit 1
  fi
done

password=$(pass show "$password_path" 2>/dev/null | head -1)
if [[ -z "$password" ]]; then
  echo "configure-opencode-service-auth: no password at pass:$password_path" >&2
  echo "  pass generate $password_path 48" >&2
  exit 1
fi

if [[ -z "${BIFROST_VK:-}" ]]; then
  bifrost_path="bifrost/vk-$(hostname -s)"
  bifrost_key=$(pass show "$bifrost_path" 2>/dev/null | head -1) || true
  if [[ -z "$bifrost_key" ]]; then
    echo "configure-opencode-service-auth: BIFROST_VK is unavailable" >&2
    echo "  unlock pass/GPG and verify pass:$bifrost_path before restarting OpenCode" >&2
    exit 1
  fi
  unset bifrost_key
fi

opencode service set env OPENCODE_SERVER_USERNAME opencode >/dev/null
opencode service set env OPENCODE_SERVER_PASSWORD "$password" >/dev/null

echo "OpenCode shared-service authentication configured from pass:$password_path."
echo "The service restarts automatically; allow MCP servers time to reconnect."
