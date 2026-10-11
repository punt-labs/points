# Public Release Readiness

This checklist covers controls that cannot be fully enforced by files in the
repository. Complete it when `punt-labs/points` is created on GitHub and before
the first public release.

## GitHub Repository

- Set `main` as the default branch.
- Enable private vulnerability reporting.
- Enable the dependency graph, Dependabot alerts, and security updates.
- Enable secret scanning and push protection.
- Enable automatic branch deletion and auto-merge.
- Enable automatic Copilot code review.

## Main Ruleset

- Require pull requests and resolved review conversations.
- Require every CI matrix leg and security check.
- Prevent force pushes and branch deletion.
- Configure zero bypass actors.
- Verify the ruleset with a test pull request containing a deliberate lint
  failure, then remove the failure.

## Release Pipeline

The repository does not yet ship an installer or release workflow because the
routing commands remain a scaffold. Before the first binary release:

- Add a tag-triggered release workflow with GitHub-hosted builds.
- Attach the four artifacts produced by `make dist`.
- Generate checksums and GitHub artifact attestations.
- Set an explicit SLSA provenance target.
- Add and test a checksum-verifying installer for `~/.local/bin/points`.
- Replace README source-build Quick Start with a commit-SHA-pinned installer.
- Exercise the installed binary through a real routing operation in CI.
- Update `CHANGELOG.md` and create the GitHub release from its release section.

Track each unfinished item in Beads before release; this document is the exit
criteria, not an issue tracker.
