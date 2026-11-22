package main

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"time"

	"github.com/punt-labs/punt-observe-go/logging"
	"github.com/punt-labs/punt-observe-go/telemetry"
)

const (
	tool      = "points"
	role      = "cli"
	operation = tool + "." + role + ".run"
)

type cliCommand telemetry.EnumMember

const (
	commandHelp    cliCommand = "help"
	commandVersion cliCommand = "version"
	commandRoute   cliCommand = "route"
	commandStatus  cliCommand = "status"
	commandVerify  cliCommand = "verify"
	commandList    cliCommand = "list"
	commandUnroute cliCommand = "unroute"
	commandUnknown cliCommand = "unknown"
)

type cliOutcome telemetry.EnumMember

const (
	success        cliOutcome = "success"
	notImplemented cliOutcome = "not_implemented"
	invalidCommand cliOutcome = "invalid_command"
	outputError    cliOutcome = "output_error"
)

var invocationSchema = telemetry.Schema{
	Name:    operation,
	Version: 1,
	Signal:  telemetry.Span,
	Fields: map[string]telemetry.Field{
		"command": {Kind: telemetry.Enum, Required: true, Members: []telemetry.EnumMember{
			telemetry.EnumMember(commandHelp), telemetry.EnumMember(commandVersion),
			telemetry.EnumMember(commandRoute), telemetry.EnumMember(commandStatus),
			telemetry.EnumMember(commandVerify), telemetry.EnumMember(commandList),
			telemetry.EnumMember(commandUnroute), telemetry.EnumMember(commandUnknown),
		}},
		"outcome": {Kind: telemetry.Enum, Required: true, Members: []telemetry.EnumMember{
			telemetry.EnumMember(success), telemetry.EnumMember(notImplemented),
			telemetry.EnumMember(invalidCommand), telemetry.EnumMember(outputError),
		}},
	},
}

type observability struct {
	handler   *logging.Handler
	log       *slog.Logger
	telemetry *telemetry.Client
}

func observe(disabled bool) observability {
	var log *slog.Logger
	handler, err := logging.New(tool, role)
	if err != nil {
		_, _ = fmt.Fprintln(os.Stderr, "points: cannot initialize private diagnostics")
	} else {
		log = slog.New(handler).With("component", tool+"."+role)
	}
	return observability{
		handler:   handler,
		log:       log,
		telemetry: telemetry.New(tool, telemetry.Config{Disabled: disabled, Diagnostics: log}, invocationSchema),
	}
}

func (o observability) complete(command cliCommand, outcome cliOutcome, started time.Time) {
	elapsed := time.Since(started)
	if o.log != nil {
		level, message := slog.LevelWarn, "Command failed"
		switch outcome {
		case success:
			level, message = slog.LevelInfo, "Command succeeded"
		case outputError:
			level, message = slog.LevelError, "Command failed to write output"
		}
		o.log.Log(context.Background(), level, message, "command", string(command), "outcome", string(outcome))
	}
	o.telemetry.Record(telemetry.Observation{
		Name: operation, Version: invocationSchema.Version, Started: started, Duration: elapsed,
		Attributes: []telemetry.Value{
			telemetry.EnumValue("command", telemetry.EnumMember(command)),
			telemetry.EnumValue("outcome", telemetry.EnumMember(outcome)),
		},
	})
}

func (o observability) close() {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	o.telemetry.Shutdown(ctx)
	if o.handler != nil {
		if err := o.handler.Close(); err != nil {
			_, _ = fmt.Fprintln(os.Stderr, "points: cannot close private diagnostics")
		}
	}
}
