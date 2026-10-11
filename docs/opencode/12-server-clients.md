# OpenCode 2 Server and Client Surfaces

This records the area 12 audit of the shared service, terminal UI, Desktop, web,
and pairing surfaces.

## Current Architecture

Normal CLI and Desktop clients use one per-user background service:

```text
OpenCode TUI ─┐
Desktop ──────┼── HTTP on 127.0.0.1 ── shared OpenCode service
CLI commands ─┘                         sessions, config, MCPs, tools
```

On this Ubuntu host, the service advertises a loopback URL and both CLI and
Desktop sessions appear in the same session store. `--standalone` starts a
private server for isolation; it pays separate initialization cost and does not
share the normal service lifecycle.

## Desktop Installation

On Ubuntu, use the official `.deb` from <https://opencode.ai/download>. Verify
its embedded version before installation:

```sh
dpkg-deb --field ~/Downloads/opencode-desktop-linux-amd64.deb Version
```

Install it with APT:

```sh
sudo apt install ~/Downloads/opencode-desktop-linux-amd64.deb
```

Do not prefer Homebrew's Linux cask here: it installs an AppImage that requires
the FUSE 2 compatibility library (`libfuse.so.2`), while Ubuntu 24.04 installs
FUSE 3 by default. The native `.deb` avoids that AppImage mount dependency.

## Shared-Service Authentication

The local service exposes configuration and tool APIs. OpenCode 2.0.26's raw
`GET /api/config` response includes resolved provider credentials. Loopback
binding limits exposure but does not make the endpoint harmless to local
processes. Require authentication even on loopback.

Store a dedicated random password in `pass`:

```sh
pass generate opencode/server-password 48
```

Apply it to OpenCode's managed service environment:

```sh
./.bin/configure-opencode-service-auth.sh
```

The script also refuses to restart the service when `BIFROST_VK` cannot be
resolved from the current environment or `pass:bifrost/vk-<hostname>`. A locked
GPG agent can otherwise make a restart inherit an empty virtual key and produce
a Bifrost authentication error. Unlock `pass`, verify key presence without
printing it, and rerun the script.

The script never writes the password into repository files. OpenCode copies the
managed service environment into `~/.local/state/opencode/service.json`, which
must remain mode 0600, and restarts the service. `pass` is the human-managed
source; the service file is OpenCode's private runtime copy. Rerun the script
after rotating `pass:opencode/server-password`. CLI and Desktop clients use the
service's discovery credentials automatically.

Verify that an unauthenticated request is denied:

```sh
curl -sS -o /dev/null -w '%{http_code}\n' "$(opencode service status)/api/info"
```

Expected status: `401`.

Verify a managed client still succeeds:

```sh
opencode api get /api/info
```

Restart Desktop after changing service authentication. Confirm that it reconnects
to the project, can list sessions, and sees all configured MCP servers after
their normal warm-up period.

## Network Policy

- Keep the shared service bound to `127.0.0.1` or `::1`.
- Do not set the hostname to `0.0.0.0`.
- Keep mDNS disabled.
- Do not add CORS origins unless a reviewed web client requires one.
- Do not start pairing or expose the server remotely until authentication,
  origin policy, and the intended client are reviewed together.

The project does not set a `server` block in `opencode.json`; this preserves the
safe loopback defaults. Verify the effective URL with `opencode service status`
and `opencode api get /api/info`.

## Client Roles

- **TUI:** primary development client; best visibility into tools and child
  sessions.
- **Desktop:** optional client over the shared service; useful for persistent
  session navigation and richer presentation.
- **Web/pair:** disabled by policy until remote-access review.
- **Standalone:** isolated diagnostics and tests where shared sessions and MCP
  processes would contaminate evidence.

Desktop and TUI are views over the same service, not independent authorities.
Beads, Ethos, Git, and the formal specification remain the durable workflow
state described in `docs/WORKFLOW.md`.

## Verified Desktop Behavior

The Desktop audit verified:

- OpenCode 2.0.26 and the `points` project directory
- Bifrost with `bedrock/gpt-5.6-sol`
- `build`, all six gstack subagents, and the active researcher
- All eight MCP connections and read-only runtime calls
- A successful `gstack-qa` child session
- Shared session visibility from the CLI
- Loopback-only service binding
- HTTP 401 for unauthenticated service requests
- CLI and Desktop operation after pass-backed service authentication
- No repository changes caused by the audit

The active reasoning variant and Desktop's internal connection label were not
visible. Shared session visibility and the single observed service process show
shared storage and service behavior, but those UI metadata fields remain
unverified.

## TUI Configuration

The project does not commit a `tui.json`. OpenCode's defaults already provide
child-session navigation and the project has no evidence-based need to override
theme, mouse, diff rendering, attention, or keybindings for every contributor.
Personal presentation preferences belong in the user's global TUI config. Add a
project setting only when it enforces a shared workflow requirement and has been
tested in both terminal and Desktop clients.

## Credential Rotation

The Desktop audit and subsequent diagnostics exposed provider credentials in
session or tool-output storage. Rotate provider credentials after configuration
stabilizes. The dedicated OpenCode server password is a separate credential and
should also be rotated if its value is ever printed or copied outside `pass`.
