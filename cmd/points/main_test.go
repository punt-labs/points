package main

import (
	"testing"
)

// Table-driven smoke tests for the scaffold command surface. The real
// behavioural suite is derived from the Z spec's TTF partitions (see
// docs/TESTPLAN.md); these only pin the CLI contract so the scaffold builds
// and the exit-code convention is locked in.
func TestRunExitCodes(t *testing.T) {
	cases := []struct {
		name string
		args []string
		want int
	}{
		{"no args prints usage", nil, 0},
		{"help", []string{"--help"}, 0},
		{"version", []string{"version"}, 0},
		{"route not implemented", []string{"route"}, 2},
		{"status not implemented", []string{"status"}, 2},
		{"verify not implemented", []string{"verify"}, 2},
		{"list not implemented", []string{"list"}, 2},
		{"unroute not implemented", []string{"unroute"}, 2},
		{"unknown command", []string{"wat"}, 2},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := run(tc.args); got != tc.want {
				t.Errorf("run(%v) = %d, want %d", tc.args, got, tc.want)
			}
		})
	}
}
