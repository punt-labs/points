# Contributing

Thank you for contributing to `points`. By participating, you agree to follow
the [Code of Conduct](CODE_OF_CONDUCT.md).

## Before You Start

Read `docs/SETUP.md`, then select and claim an unblocked Beads issue:

```bash
bd ready --json
```

```bash
bd update <issue-id> --claim --json
```

For behavior or architecture changes, update the authoritative specification at
`docs/spec/points.target.spec.tex` before implementation. Derive tests according
to the canonical strategy in `docs/TESTPLAN.md` and execute work through the
bounded Beads/Ethos loop in `docs/WORKFLOW.md`.

## Quality Gates

Install the pinned development toolchain:

```bash
make tools
```

Run the complete local gate:

```bash
make check
```

Apply Go formatting:

```bash
make format
```

Build the development binary:

```bash
make build
```

Cross-compile release artifacts:

```bash
make dist
```

Tests must be table-driven where multiple cases exercise the same behavior.
Use `testify/assert` and `testify/require` once the implementation needs the
approved test dependency; the dependency-free scaffold uses standard `testing`.
Every automated Go test invocation uses `-race -count=1`.

## Pull Requests

- Keep each change focused and include tests with new behavior.
- Update user-facing documentation in the same change as behavior.
- Run `make check` before requesting review.
- Resolve every review conversation and keep CI green.
- Do not commit credentials, local overrides, or generated scratch files.

Security vulnerabilities should not be filed publicly. Follow `SECURITY.md`.

## Repository Administration

Maintainers configure GitHub outside the repository:

- Protect `main`; require pull requests, resolved conversations, and every CI
  status check, with no bypass actors or force pushes.
- Enable Dependabot alerts and security updates, secret scanning, and push
  protection.
- Enable automatic Copilot review, auto-merge, and automatic deletion of merged
  branches.
- Verify the protections with a test pull request before the first release.

The complete one-time checklist is in `docs/PUBLIC-RELEASE.md`.
