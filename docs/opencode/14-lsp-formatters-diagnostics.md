# OpenCode 2 LSP, Formatters, and Diagnostics

This records the area 14 decision in the OpenCode 2 configuration audit.

## Decision

Enable project-scoped Go diagnostics through `gopls` and background Go
formatting through the built-in `gofmt` formatter. Do not enable all built-in
language servers or formatters, and do not enable OpenCode's experimental LSP
navigation tool yet.

`opencode.json` owns the interactive configuration:

```json
{
  "lsp": {
    "gopls": {
      "command": ["gopls"],
      "extensions": [".go"]
    }
  },
  "formatter": {
    "gofmt": {}
  }
}
```

The `Makefile` pins and installs `gopls`. OpenCode resolves the executable from
the environment supplied when the session starts.

## Why

- `gopls` is the selected Go diagnostic engine and is available directly for
  focused checks. OpenCode integration is configured, with the observed 2.0.26
  limitation recorded below.
- Built-in `gofmt` runs after OpenCode writes or edits `.go` files. It uses the
  same formatting semantics checked by the pinned `golangci-lint fmt --diff`
  quality gate.
- Project scope makes the choice explicit and reproducible for contributors
  without enabling unrelated language tooling globally.
- Narrow enablement avoids automatic downloads, memory use, and diagnostic noise
  from language servers irrelevant to this repository.

## Authority Boundary

OpenCode diagnostics and background formatting are feedback, not acceptance.
`make check` remains authoritative because it uses pinned golangci-lint,
uncached race tests, Markdown lint, and actionlint in the same repository state
reviewed by CI.

An LSP success cannot waive a compiler, test, lint, or spec failure. If `gopls`
and `make check` disagree, diagnose the version or workspace mismatch and trust
the quality gate until the mismatch is resolved.

## Observed OpenCode 2.0.26 Limitation

Runtime testing used a module-scoped `.go` file with an invalid string return
from an `int` function. Direct `gopls check` reported the expected type error.
OpenCode's edit response reported no diagnostics, both with the explicit gopls
entry above and with `lsp: true`, even after restarting the background service;
the server log showed no gopls process start.

The formatter test passed in the same runs: intentionally one-line Go was
rewritten into gofmt layout. Area 14 therefore enables and verifies formatting,
and pins and configures gopls for reproducible activation when OpenCode supports
this path. It does not claim that OpenCode 2.0.26 currently surfaces gopls
diagnostics. Until then, run `gopls check <file>` directly for focused feedback
and use `make check` as the acceptance gate.

## Experimental LSP Tool

OpenCode can expose navigation operations such as definitions, references,
hover, symbols, implementations, and call hierarchy when
`OPENCODE_EXPERIMENTAL_LSP_TOOL=true` is set. That tool is not enabled here.

Enabling an experimental model-callable tool would increase tool schema and
permissions without evidence that its underlying integration works in this
version. Reconsider it after stable diagnostics activate or when an agent task
requires semantic navigation that repository search cannot provide reliably.

## Verification

Install the pinned tools:

```sh
make tools
```

Confirm the configured executable:

```sh
gopls version
```

Confirm OpenCode resolves only the selected Go entries:

```sh
opencode debug config
```

Run the authoritative gate:

```sh
make check
```

For a runtime diagnostic test, open or edit a temporary `.go` file containing a
type error in an isolated worktree, compare OpenCode's edit response with
`gopls check <file>`, then remove the file. For formatter verification, write
deliberately unformatted Go in the same disposable location and confirm OpenCode
rewrites it with `gofmt` before running `make check`.

## Result

The project receives automatic gofmt feedback with no duplicate formatter
policy. Gopls is pinned and configured, but its OpenCode diagnostic integration
is not effective on 2.0.26. The repository's deterministic quality gate decides
whether work may proceed.
