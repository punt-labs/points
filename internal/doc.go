// Package internal is the home for points' implementation packages.
//
// Planned layout (see docs/spec/points.target.spec.tex for the formal model):
//
//	internal/catalog  — fetch + cache a source's model catalog (providers served)
//	internal/route    — the pure core: selection → per-harness config content
//	internal/harness  — per-harness writers (claudecode, codex, pi, opencode)
//	internal/backend  — env delivery backends (launcher-wrapper, direnv, mise, nix)
//	internal/verify   — the routability/coherence checks behind `points verify`
//
// The core is a pure function of the operator's selection; backends only render
// its output. File-writing for pi/opencode is universal; env delivery is the
// pluggable part (claudecode/codex).
package internal
