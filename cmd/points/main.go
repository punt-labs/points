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
// implemented. See docs/SETUP.md and the Linear backlog (label repo:points)
// for the build plan.
package main

import (
	"fmt"
	"os"
	"time"
)

const usage = `points — route your AI coding harnesses (config tool, not a proxy)

Usage:
  points [--no-telemetry] <command> [flags]

Commands:
  route     Point a harness (or set of harnesses) at a source + default model
  status    Show the per-harness route and default model
  verify    Check that every routed harness reaches a valid upstream
  list      List the providers a source serves
  unroute   Return a harness to its vendor default (direct)
  version   Print the points version

Run "points <command> --help" for details.
Use --no-telemetry before the command to disable usage capture for this run.

points is spec-first: docs/spec/points.target.spec.tex is the source of truth.
`

const version = "0.0.0-scaffold"

func main() {
	os.Exit(run(os.Args[1:]))
}

func run(args []string) int {
	started := time.Now()
	disabled := len(args) > 0 && args[0] == "--no-telemetry"
	if disabled {
		args = args[1:]
	}
	observations := observe(disabled)
	defer observations.close()

	command := classify(args)
	output, outcome, code := dispatch(command, args)
	stream := os.Stdout
	if code != 0 {
		stream = os.Stderr
	}
	if _, err := fmt.Fprint(stream, output); err != nil {
		outcome = outputError
		if code == 0 {
			code = 1
		}
	}
	observations.complete(command, outcome, started)
	return code
}

func classify(args []string) cliCommand {
	if len(args) == 0 {
		return commandHelp
	}
	switch command := cliCommand(args[0]); command {
	case "-h", "--help", "help":
		return commandHelp
	case "version", "--version":
		return commandVersion
	case commandRoute, commandStatus, commandVerify, commandList, commandUnroute:
		return command
	default:
		return commandUnknown
	}
}

func dispatch(command cliCommand, args []string) (string, cliOutcome, int) {
	switch command {
	case commandHelp:
		return usage, success, 0
	case commandVersion:
		return "points " + version + "\n", success, 0
	case commandUnknown:
		return fmt.Sprintf("points: unknown command %q\n\n%s", args[0], usage), invalidCommand, 2
	default:
		return fmt.Sprintf("points %s: not implemented yet (scaffold)\n", command), notImplemented, 2
	}
}
