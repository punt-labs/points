package main

import (
	"context"
	"database/sql"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"golang.org/x/sys/unix"
)

func TestCLIProcess(t *testing.T) {
	if os.Getenv("POINTS_TEST_CLI") != "1" {
		return
	}
	os.Args = append(os.Args[:1], os.Args[3:]...)
	main()
}

func newCLI(t *testing.T, home string, env []string, args ...string) *exec.Cmd {
	t.Helper()
	binary, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(t.Context(), 10*time.Second)
	t.Cleanup(cancel)
	cmd := exec.CommandContext(ctx, binary, append([]string{"-test.run=^TestCLIProcess$", "--"}, args...)...)
	cmd.Dir = t.TempDir()
	cmd.Env = append(cmd.Environ(), "HOME="+home, "PUNT_TELEMETRY=", "POINTS_TELEMETRY=", "POINTS_TEST_CLI=1")
	cmd.Env = append(cmd.Env, env...)
	return cmd
}

func runCLI(t *testing.T, home string, env []string, exit int, args ...string) string {
	t.Helper()
	cmd := newCLI(t, home, env, args...)
	out, err := cmd.CombinedOutput()
	if cmd.ProcessState == nil || cmd.ProcessState.ExitCode() != exit {
		t.Fatalf("exit: got %v, want %d; output: %s", err, exit, out)
	}
	return string(out)
}

func TestCLIObservability(t *testing.T) {
	home := t.TempDir()
	const canary = "operator@example.invalid"
	if out := runCLI(t, home, nil, 0, "version"); out != "points "+version+"\n" {
		t.Fatalf("unexpected version output: %q", out)
	}
	if out := runCLI(t, home, nil, 2, "route", home, canary); !strings.Contains(out, "not implemented yet") {
		t.Fatalf("missing command error: %q", out)
	}
	if out := runCLI(t, home, nil, 2, "status"); !strings.Contains(out, "not implemented yet") {
		t.Fatalf("missing command error: %q", out)
	}
	if out := runCLI(t, home, nil, 2, canary); !strings.Contains(out, "unknown command") {
		t.Fatalf("missing usage error: %q", out)
	}

	root := filepath.Join(home, ".punt-labs", "points")
	logs := filepath.Join(root, "logs")
	logPath := filepath.Join(logs, "points.log")
	dbPath := filepath.Join(root, "telemetry.db")
	checkMode(t, root, 0o700)
	checkMode(t, logs, 0o700)
	checkMode(t, logPath, 0o600)
	checkMode(t, logPath+".rotate.lock", 0o600)
	checkMode(t, dbPath, 0o600)
	log, err := os.ReadFile(logPath)
	if err != nil {
		t.Fatal(err)
	}
	checkOutcomeLogs(t, log,
		"[INFO] points.cli: Command succeeded command=version outcome=success",
		"[WARNING] points.cli: Command failed command=route outcome=not_implemented",
		"[WARNING] points.cli: Command failed command=status outcome=not_implemented",
		"[WARNING] points.cli: Command failed command=unknown outcome=invalid_command")
	for _, forbidden := range []string{canary, home} {
		if strings.Contains(string(log), forbidden) {
			t.Errorf("log contains private data: %q", forbidden)
		}
	}
	checkSpans(t, dbPath,
		`{"command":"version","outcome":"success"}`,
		`{"command":"route","outcome":"not_implemented"}`,
		`{"command":"status","outcome":"not_implemented"}`,
		`{"command":"unknown","outcome":"invalid_command"}`)
}

func checkOutcomeLogs(t *testing.T, log []byte, want ...string) {
	t.Helper()
	lines := strings.Split(strings.TrimSuffix(string(log), "\n"), "\n")
	if len(lines) != len(want) {
		t.Fatalf("want exactly %d log records, got %d:\n%s", len(want), len(lines), log)
	}
	for i, record := range want {
		if !strings.HasSuffix(lines[i], " "+record) {
			t.Errorf("unexpected log record %q, want suffix %q", lines[i], record)
		}
	}
}

func checkMode(t *testing.T, path string, want fs.FileMode) {
	t.Helper()
	info, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if got := info.Mode().Perm(); got != want {
		t.Errorf("%s mode = %o, want %o", filepath.Base(path), got, want)
	}
}

func checkSpans(t *testing.T, path string, want ...string) {
	t.Helper()
	db, err := sql.Open("sqlite", "file:"+filepath.ToSlash(path)+"?mode=ro")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		if err := db.Close(); err != nil {
			t.Error(err)
		}
	})
	rows, err := db.QueryContext(t.Context(), "SELECT signal, name, schema_version, end_ns - start_ns, attributes FROM signals ORDER BY rowid")
	if err != nil {
		t.Fatal(err)
	}
	defer func() {
		if err := rows.Close(); err != nil {
			t.Error(err)
		}
	}()
	for _, attrsWant := range want {
		if !rows.Next() {
			t.Fatalf("missing span with %s (query error: %v)", attrsWant, rows.Err())
		}
		var signal, name, attrs string
		var schema int
		var duration int64
		if err := rows.Scan(&signal, &name, &schema, &duration, &attrs); err != nil {
			t.Fatal(err)
		}
		if signal != "span" || name != "points.cli.run" || schema != 1 || duration <= 0 || attrs != attrsWant {
			t.Errorf("unexpected observation: %s %s v%d (%dns) %s; wanted attributes %s", signal, name, schema, duration, attrs, attrsWant)
		}
	}
	if rows.Next() {
		t.Error("unexpected additional observation")
	}
	if err := rows.Err(); err != nil {
		t.Fatal(err)
	}
}

func TestCLIReportsErrorOutputFailure(t *testing.T) {
	home := t.TempDir()
	stderr, err := os.Open(os.DevNull)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		if err := stderr.Close(); err != nil {
			t.Error(err)
		}
	})
	cmd := newCLI(t, home, nil, "route")
	cmd.Stderr = stderr
	if err := cmd.Run(); cmd.ProcessState == nil || cmd.ProcessState.ExitCode() != 2 {
		t.Fatalf("expected original exit code 2, got %v", err)
	}
	root := filepath.Join(home, ".punt-labs", "points")
	log, err := os.ReadFile(filepath.Join(root, "logs", "points.log"))
	if err != nil {
		t.Fatal(err)
	}
	checkOutcomeLogs(t, log, "[ERROR] points.cli: Command failed to write output command=route outcome=output_error")
	checkSpans(t, filepath.Join(root, "telemetry.db"), `{"command":"route","outcome":"output_error"}`)
}

func TestCLITelemetryOff(t *testing.T) {
	for _, c := range []struct {
		name string
		env  []string
		args []string
	}{
		{"global", []string{"PUNT_TELEMETRY=off", "POINTS_TELEMETRY=on"}, []string{"version"}},
		{"per-tool", []string{"PUNT_TELEMETRY=on", "POINTS_TELEMETRY=off"}, []string{"version"}},
		{"flag", []string{"PUNT_TELEMETRY=on", "POINTS_TELEMETRY=on"}, []string{"--no-telemetry", "version"}},
	} {
		t.Run(c.name, func(t *testing.T) {
			home := t.TempDir()
			runCLI(t, home, c.env, 0, c.args...)
			root := filepath.Join(home, ".punt-labs", "points")
			if _, err := os.Stat(filepath.Join(root, "telemetry.db")); !os.IsNotExist(err) {
				t.Fatalf("telemetry store should not exist, stat error: %v", err)
			}
			checkMode(t, filepath.Join(root, "logs", "points.log"), 0o600)
		})
	}
}

func TestCLIReportsLoggingStartupFailure(t *testing.T) {
	home := t.TempDir()
	root := filepath.Join(home, ".punt-labs", "points")
	if err := os.MkdirAll(root, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "logs"), nil, 0o600); err != nil {
		t.Fatal(err)
	}
	out := runCLI(t, home, []string{"POINTS_TELEMETRY=off"}, 0, "version")
	if out != "points: cannot initialize private diagnostics\npoints "+version+"\n" {
		t.Fatalf("unexpected output when diagnostics cannot start: %q", out)
	}
}

func TestCLIContinuesWithRotationLockHeld(t *testing.T) {
	home := t.TempDir()
	root := filepath.Join(home, ".punt-labs", "points")
	logs := filepath.Join(root, "logs")
	if err := os.MkdirAll(logs, 0o700); err != nil {
		t.Fatal(err)
	}
	logPath := filepath.Join(logs, "points.log")
	lock, err := os.OpenFile(logPath+".rotate.lock", os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		if err := lock.Close(); err != nil {
			t.Error(err)
		}
	})
	if err := unix.Flock(int(lock.Fd()), unix.LOCK_EX|unix.LOCK_NB); err != nil {
		t.Fatal(err)
	}
	started := time.Now()
	out := runCLI(t, home, nil, 0, "version")
	if elapsed := time.Since(started); elapsed < 1900*time.Millisecond || elapsed > 5*time.Second {
		t.Errorf("CLI with rotation lock held took %v, want roughly 2s plus subprocess overhead", elapsed)
	}
	if out != "points: cannot initialize private diagnostics\npoints "+version+"\n" {
		t.Fatalf("unexpected output with rotation lock held: %q", out)
	}
	if _, err := os.Stat(logPath); !os.IsNotExist(err) {
		t.Fatalf("active log should not exist with rotation lock held, stat error: %v", err)
	}
	if err := unix.Flock(int(lock.Fd()), unix.LOCK_UN); err != nil {
		t.Fatal(err)
	}
	if out := runCLI(t, home, nil, 0, "version"); out != "points "+version+"\n" {
		t.Fatalf("unexpected output after releasing rotation lock: %q", out)
	}
	log, err := os.ReadFile(logPath)
	if err != nil {
		t.Fatal(err)
	}
	checkOutcomeLogs(t, log, "[INFO] points.cli: Command succeeded command=version outcome=success")
	checkSpans(t, filepath.Join(root, "telemetry.db"),
		`{"command":"version","outcome":"success"}`,
		`{"command":"version","outcome":"success"}`)
}
