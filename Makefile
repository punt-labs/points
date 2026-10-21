# points — build and quality gates.

BINARY  := points
CMD     := ./cmd/points
PKG     := ./...
VERSION := $(or $(shell git describe --tags --always 2>/dev/null | sed 's/^v//'),dev)
LDFLAGS := -X main.version=$(VERSION)
PREFIX  ?= $(HOME)/.local
PROB    ?= $(HOME)/Applications/ProB/probcli
PYTHON  ?= python3

GOLANGCI_LINT_VERSION := v2.13.1
ACTIONLINT_VERSION := v1.7.7
GOPLS_VERSION := v0.23.0
GOBIN := $(shell go env GOBIN)
ifeq ($(GOBIN),)
GOBIN := $(shell go env GOPATH | cut -d: -f1)/bin
endif
GOLANGCI_LINT := $(GOBIN)/golangci-lint
ACTIONLINT := $(GOBIN)/actionlint

.DEFAULT_GOAL := all

.PHONY: all
all: build check ## Build and run every quality gate

.PHONY: check
check: lint test markdownlint workflows evaluator-models ## Run every quality gate

.PHONY: check-dev
check-dev: evaluator-models ## Validate committed development-environment configuration
	./.bin/check-dev-config.sh
	./.bin/test-extract-subagent-result.sh

.PHONY: test
test: ## Run race-enabled tests without cache
	go test -race -count=1 $(PKG)

.PHONY: coverage
coverage: ## Write a coverage profile and summary
	go test -race -count=1 -coverprofile=coverage.out $(PKG)
	go tool cover -func=coverage.out | tail -1

.PHONY: lint
lint: ## Run pinned Go static analysis and formatting checks
	@test -x "$(GOLANGCI_LINT)" || { echo "golangci-lint not found at $(GOLANGCI_LINT) — run 'make tools'"; exit 1; }
	@actual=$$("$(GOLANGCI_LINT)" version --short 2>/dev/null || "$(GOLANGCI_LINT)" version); \
	  printf '%s\n' "$$actual" | grep -q "$(patsubst v%,%,$(GOLANGCI_LINT_VERSION))" || { \
	  echo "golangci-lint must be $(GOLANGCI_LINT_VERSION), got: $$actual"; exit 1; }
	"$(GOLANGCI_LINT)" run $(PKG)
	"$(GOLANGCI_LINT)" fmt --diff

.PHONY: markdownlint
markdownlint: ## Lint Markdown
	@if command -v markdownlint-cli2 >/dev/null 2>&1; then \
	  markdownlint-cli2 "**/*.md" "#node_modules" "#.punt-labs"; \
	else \
	  npx --yes markdownlint-cli2 "**/*.md" "#node_modules" "#.punt-labs"; \
	fi

.PHONY: workflows
workflows: ## Lint GitHub Actions workflows
	@test -x "$(ACTIONLINT)" || { echo "actionlint not found at $(ACTIONLINT) — run 'make tools'"; exit 1; }
	"$(ACTIONLINT)" .github/workflows/*.yml

.PHONY: evaluator-models
evaluator-models: ## Require preferred Bedrock OpenAI models for Ethos evaluators
	./.bin/check-ethos-evaluator-models.sh

.PHONY: format
format: ## Apply Go formatting
	@test -x "$(GOLANGCI_LINT)" || { echo "golangci-lint not found — run 'make tools'"; exit 1; }
	"$(GOLANGCI_LINT)" fmt

.PHONY: build
build: ## Build a static development binary
	CGO_ENABLED=0 go build -ldflags="$(LDFLAGS)" -o $(BINARY) $(CMD)

.PHONY: dist
dist: clean ## Cross-compile static release binaries
	mkdir -p dist
	CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -ldflags="-s -w $(LDFLAGS)" -o dist/$(BINARY)-darwin-arm64 $(CMD)
	CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build -ldflags="-s -w $(LDFLAGS)" -o dist/$(BINARY)-darwin-amd64 $(CMD)
	CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -ldflags="-s -w $(LDFLAGS)" -o dist/$(BINARY)-linux-arm64 $(CMD)
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w $(LDFLAGS)" -o dist/$(BINARY)-linux-amd64 $(CMD)

.PHONY: install
install: build ## Install to PREFIX/bin (default ~/.local/bin)
	install -d "$(PREFIX)/bin"
	install -m 0755 $(BINARY) "$(PREFIX)/bin/$(BINARY)"

.PHONY: uninstall
uninstall: ## Remove the installed binary
	rm -f "$(PREFIX)/bin/$(BINARY)"

.PHONY: clean
clean: ## Remove build artifacts
	rm -f $(BINARY) coverage.out
	rm -rf dist

.PHONY: tools
tools: ## Install pinned development tools
	GOBIN="$(GOBIN)" go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@$(GOLANGCI_LINT_VERSION)
	GOBIN="$(GOBIN)" go install github.com/rhysd/actionlint/cmd/actionlint@$(ACTIONLINT_VERSION)
	GOBIN="$(GOBIN)" go install golang.org/x/tools/gopls@$(GOPLS_VERSION)

.PHONY: doctor
doctor: build check-dev ## Verify the CLI and local OpenCode development services
	./$(BINARY) version
	./$(BINARY) --help >/dev/null
	@command -v bd >/dev/null || { echo 'bd is not installed'; exit 1; }
	@command -v ethos >/dev/null || { echo 'ethos is not installed'; exit 1; }
	@command -v opencode >/dev/null || { echo 'opencode is not installed'; exit 1; }
	@direnv status >/dev/null 2>&1 || { echo "direnv has not allowed this repository; run 'direnv allow'"; exit 1; }
	@ethos doctor --json | jq -e 'all(.status == "PASS")' >/dev/null
	@biff doctor | grep -q 'All required checks passed.'
	@opencode service status >/dev/null
	@./.bin/check-live-plugins.sh
	@connected=$$(opencode mcp list | grep -c 'connected' || true); \
	  test "$$connected" -eq 8 || { echo "expected 8 connected MCP servers, got $$connected"; exit 1; }
	@opencode debug agents | jq -e '([.[] | select(.id=="researcher")] | length)==1 and ([.[] | select(.id|startswith("gstack-"))] | length)==6' >/dev/null
	@direnv exec . ./.bin/check-live-models.sh
	@./.bin/check-agent-tool-smoke.sh

.PHONY: spec
spec: ## Type-check the target Z specification
	fuzz docs/spec/points.target.spec.tex

.PHONY: spec-prob
spec-prob: spec ## Check target Z assertions with ProB
	@test -x "$(PROB)" || { echo "probcli not found at $(PROB) — set PROB=/path/to/probcli"; exit 1; }
	@PROB="$(PROB)" exec /bin/bash -c 'set -euo pipefail; set -m; \
	  lock=docs/spec/.points-target-spec-prob.lock; output=docs/spec/points.target.spec.fuzz; log=docs/spec/.points-target-spec-prob.lock/prob.out; owned_lock=false; owned_output=false; acquiring=false; launching=false; pending_signal=0; child=""; watcher=""; make_pid=$$PPID; recipe_pid=$$$$; \
	  cleanup_files() { test "$$owned_output" != true || rm -f "$$output"; test "$$owned_lock" != true || { rm -f "$$log"; rmdir "$$lock"; }; }; \
	  group_alive() { test -n "$$child" && kill -0 -- "-$$child" 2>/dev/null; }; \
	  stop_child() { if test -n "$$child"; then kill -TERM -- "-$$child" 2>/dev/null || true; for ((attempt=0; attempt<100; attempt++)); do group_alive || break; sleep 0.01; done; if group_alive; then kill -KILL -- "-$$child" 2>/dev/null || true; for ((attempt=0; attempt<100; attempt++)); do group_alive || break; sleep 0.01; done; fi; wait "$$child" 2>/dev/null || true; group_alive && return 1; fi; child=""; }; \
	  stop_watcher() { if test -n "$$watcher" && kill -0 "$$watcher" 2>/dev/null; then kill "$$watcher" 2>/dev/null || true; wait "$$watcher" 2>/dev/null || true; fi; watcher=""; }; \
	  watch_parent() { while kill -0 "$$make_pid" 2>/dev/null; do sleep 0.05; done; kill -TERM "$$recipe_pid" 2>/dev/null || true; }; \
	  cleanup() { stop_watcher; if stop_child; then cleanup_files; else echo "checker process group did not terminate; preserving output and lock" >&2; return 1; fi; }; \
	  on_signal() { code=$$1; trap - EXIT; cleanup; exit "$$code"; }; \
	  handle_signal() { code=$$1; if test "$$acquiring" = true || test "$$launching" = true; then pending_signal=$$code; return; fi; on_signal "$$code"; }; \
	  trap cleanup EXIT; trap "handle_signal 129" HUP; trap "handle_signal 130" INT; trap "handle_signal 143" TERM; \
	  acquiring=true; if mkdir "$$lock" 2>/dev/null; then owned_lock=true; else acquiring=false; echo "another make spec-prob invocation is active"; exit 1; fi; acquiring=false; \
	  test "$$pending_signal" -eq 0 || on_signal "$$pending_signal"; \
	  test ! -e "$$output" && test ! -L "$$output" || { echo "refusing to replace pre-existing $$output"; exit 1; }; \
	  owned_output=true; \
	  launching=true; "$$PROB" docs/spec/points.target.spec.tex -cbc_assertions -strict >"$$log" 2>&1 & child=$$!; \
	  watch_parent & watcher=$$!; launching=false; \
	  test "$$pending_signal" -eq 0 || on_signal "$$pending_signal"; \
	  status=0; wait "$$child" || status=$$?; stop_child; stop_watcher; cat "$$log"; \
	  test "$$status" -eq 0 || exit "$$status"; \
	  test "$$(grep -Fc "No counter-example to ASSERTION exists" "$$log")" -eq 1; \
	  ! grep -Eq "COUNTER EXAMPLE FOUND|model_check_incomplete|Not all states|TIME OUT|Abnormal termination|Total Errors: [1-9]" "$$log"'

.PHONY: spec-prob-a-smoke
spec-prob-a-smoke: spec ## Generate and run the bounded Scenario A initialization/lifecycle smoke
	@test -x "$(PROB)" || { echo "probcli not found at $(PROB) — set PROB=/path/to/probcli"; exit 1; }
	@command -v "$(PYTHON)" >/dev/null || { echo "python not found at $(PYTHON)"; exit 1; }
	@PROB="$(PROB)" PYTHON="$(PYTHON)" exec /bin/bash -c 'set -euo pipefail; set -m; \
	  mkdir -p .tmp/opencode; run=$$(mktemp -d .tmp/opencode/spec-prob-a.XXXXXXXX); commands="$$run/commands.txt"; child=""; watcher=""; make_pid=$$PPID; recipe_pid=$$$$; \
	  group_alive() { test -n "$$child" && kill -0 -- "-$$child" 2>/dev/null; }; \
	  stop_child() { if test -n "$$child"; then kill -TERM -- "-$$child" 2>/dev/null || true; for ((attempt=0; attempt<100; attempt++)); do group_alive || break; sleep 0.01; done; if group_alive; then kill -KILL -- "-$$child" 2>/dev/null || true; fi; wait "$$child" 2>/dev/null || true; fi; child=""; }; \
	  stop_watcher() { if test -n "$$watcher" && kill -0 "$$watcher" 2>/dev/null; then kill "$$watcher" 2>/dev/null || true; wait "$$watcher" 2>/dev/null || true; fi; watcher=""; }; \
	  cleanup() { status=$$?; stop_watcher; stop_child; if test "$$status" -ne 0; then echo "Scenario A evidence preserved in $$run" >&2; fi; return "$$status"; }; \
	  on_signal() { code=$$1; trap - EXIT; cleanup; printf "interrupted status=%s\n" "$$code" >>"$$commands"; echo "Scenario A evidence preserved in $$run" >&2; exit "$$code"; }; \
	  trap cleanup EXIT; trap "on_signal 129" HUP; trap "on_signal 130" INT; trap "on_signal 143" TERM; \
	  watch_parent() { while kill -0 "$$make_pid" 2>/dev/null; do sleep 0.05; done; kill -TERM "$$recipe_pid" 2>/dev/null || true; }; \
	  watch_parent & watcher=$$!; \
	  run_owned() { destination=$$1; shift; { printf "+"; printf " %q" "$$@"; printf " > %q\n" "$$destination"; } >>"$$commands"; "$$@" >"$$destination" 2>&1 & child=$$!; status=0; wait "$$child" || status=$$?; child=""; printf "status=%s\n" "$$status" >>"$$commands"; test "$$status" -eq 0; }; \
	  echo "run_directory=$$run" >"$$commands"; \
	  run_owned "$$run/prob-version.txt" "$$PROB" -version; \
	  run_owned "$$run/prob-help.txt" "$$PROB" -help; \
	  run_owned "$$run/generate.out" "$$PYTHON" .bin/generate-spec-prob.py generate --source docs/spec/points.target.spec.tex --output "$$run/scenario-a.tex" --manifest "$$run/inputs.json"; \
	  run_owned "$$run/regenerate.out" "$$PYTHON" .bin/generate-spec-prob.py generate --source docs/spec/points.target.spec.tex --output "$$run/scenario-a.regenerated.tex" --manifest "$$run/inputs.regenerated.json"; \
	  cmp "$$run/scenario-a.tex" "$$run/scenario-a.regenerated.tex"; cmp "$$run/inputs.json" "$$run/inputs.regenerated.json"; rm "$$run/scenario-a.regenerated.tex" "$$run/inputs.regenerated.json"; \
	  run_owned "$$run/fuzz.out" fuzz "$$run/scenario-a.tex"; \
	  run_owned "$$run/init.out" "$$PROB" "$$run/scenario-a.tex" -init -p TIME_OUT 10000 -p MAX_INITIALISATIONS 100000 -p MAX_OPERATIONS 100000 -global_time_out 180000 -c -l "$$run/init.log" -his "$$run/init.trace" -his_option trace_file -dot state_space "$$run/init.states.dot"; \
	  run_owned "$$run/init-validation.out" "$$PYTHON" .bin/generate-spec-prob.py validate --phase init --checker-output "$$run/init.out" --dot "$$run/init.states.dot"; \
	  goal="life=ended & phase=finished & reportState=reportDelivered & committed=yes & configSyncAck=yes & lockHeld=no & events={} & cleanupDue={} & cleanupPending={} & pendingCount=pendingZero & pConfig:dom(visibleNS) & visibleNS(pConfig)=file(idCandidate) & pConfig:dom(durableNS) & durableNS(pConfig)=file(idCandidate) & pConfigStage/:dom(visibleNS) & pConfigStage/:dom(durableNS) & idCandidate:dom(visibleImages) & visibleImages(idCandidate)=imageCompleteCandidate & idCandidate:dom(syncedImages) & syncedImages(idCandidate)=imageCompleteCandidate & seen={opCreateStage,opWriteStage,opFileSyncStage,opCloseStage,opBeginRevalidation,opRevalidationSuccess,opCommitAbsent,opConfirmConfigSuccess,opBeginCleanup,opUnlinkOwned,opEndCleanupSweep,opCleanupSyncSuccess,opReleaseSuccess,opReportDelivered,opFinishTransaction} & badRevalidation=no & badFilePublication=no & badBackupOrder=no & badReplacementUnlink=no & badPrematureReport=no & badPostDeathStep=no & badImageCoverage=no & badFinalImage=no & badRetainedCleanup=no"; \
	  run_owned "$$run/lifecycle.out" "$$PROB" "$$run/scenario-a.tex" -model_check -mc_mode breadth-first -nodead -goal "$$goal" -p TIME_OUT 10000 -p MAX_INITIALISATIONS 100000 -p MAX_OPERATIONS 100000 -global_time_out 180000 -c -his "$$run/lifecycle.trace" -his_option trace_file -l "$$run/lifecycle.log" -dot state_space "$$run/lifecycle.states.dot"; \
	  run_owned "$$run/lifecycle-validation.out" "$$PYTHON" .bin/generate-spec-prob.py validate --phase lifecycle --checker-output "$$run/lifecycle.out" --dot "$$run/lifecycle.states.dot" --trace "$$run/lifecycle.trace"; \
	  stop_watcher; echo "Scenario A smoke: PASS ($$run)"'

.PHONY: test-spec-prob
test-spec-prob: ## Run deterministic Scenario A harness regressions
	bash .bin/test-spec-prob-scenarios.sh

.PHONY: help
help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | sort \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
