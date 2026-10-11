# points — build and quality gates.

BINARY  := points
CMD     := ./cmd/points
PKG     := ./...
VERSION := $(or $(shell git describe --tags --always 2>/dev/null | sed 's/^v//'),dev)
LDFLAGS := -X main.version=$(VERSION)
PREFIX  ?= $(HOME)/.local

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
	@opencode api get /api/plugin | jq -e 'all(.data[]; .source.type == "builtin" and .state.status == "active")' >/dev/null
	@connected=$$(opencode mcp list | grep -c 'connected' || true); \
	  test "$$connected" -eq 8 || { echo "expected 8 connected MCP servers, got $$connected"; exit 1; }
	@opencode debug agents | jq -e '([.[] | select(.id=="researcher")] | length)==1 and ([.[] | select(.id|startswith("gstack-"))] | length)==6' >/dev/null

.PHONY: spec
spec: ## Type-check the target Z specification
	fuzz docs/spec/points.target.spec.tex

.PHONY: help
help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | sort \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
