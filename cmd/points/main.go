// Command points configures AI coding harnesses to route each one, per the
// operator's choice, through a chosen source (a gateway such as Bifrost, a
// direct vendor, or an aggregator such as OpenRouter).
//
// points is a routing CONFIG tool, not a proxy: it writes static configuration
// on one machine and exits. Nothing runs in the request path. The formal design
// is in docs/spec/points.target.spec.tex (fuzz- and ProB-verified).
//
// This is a scaffold entry point: subcommands are declared so the command
// surface is visible and `go build` succeeds, but the behaviours are not yet
// implemented. See docs/SETUP.md and the beads queue for the build plan.
package main

import (
	"fmt"
	"os"
)

const usage = `points — route your AI coding harnesses (config tool, not a proxy)

Usage:
  points <command> [flags]

Commands:
  route     Point a harness (or set of harnesses) at a source + default model
  status    Show the per-harness route and default model
  verify    Check that every routed harness reaches a valid upstream
  list      List the providers a source serves
  unroute   Return a harness to its vendor default (direct)
  version   Print the points version

Run "points <command> --help" for details.

points is spec-first: docs/spec/points.target.spec.tex is the source of truth.
`

const version = "0.0.0-scaffold"

func main() {
	os.Exit(run(os.Args[1:]))
}

func run(args []string) int {
	if len(args) == 0 {
		return write(os.Stdout, usage)
	}
	switch args[0] {
	case "-h", "--help", "help":
		return write(os.Stdout, usage)
	case "version", "--version":
		return write(os.Stdout, "points "+version+"\n")
	case "route", "status", "verify", "list", "unroute":
		_ = write(os.Stderr, fmt.Sprintf("points %s: not implemented yet (scaffold)\n", args[0]))
		return 2
	default:
		_ = write(os.Stderr, fmt.Sprintf("points: unknown command %q\n\n%s", args[0], usage))
		return 2
	}
}

func write(f *os.File, text string) int {
	if _, err := fmt.Fprint(f, text); err != nil {
		return 1
	}
	return 0
}
