#!/usr/bin/env bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "$0")/.." && pwd)
output=${1:?Usage: build-handoff-runtime.sh OUTPUT_DIRECTORY}
mkdir -p -- "$output"
output=$(cd -- "$output" && pwd)
cd "$repo"

[[ $(uname -s)/$(uname -m) == Linux/x86_64 ]]
export GOENV=off GOTOOLCHAIN=local GOFLAGS=-modcacherw
unset GOROOT
go_version=$(awk '$1 == "go" { print $2 }' go.mod)
golangci_version=$(awk '$1 == "GOLANGCI_LINT_VERSION" { print $3 }' Makefile)
actionlint_version=$(awk '$1 == "ACTIONLINT_VERSION" { print $3 }' Makefile)
shellcheck_version=v0.11.0
node_version=v22.23.5
[[ $(go env GOVERSION) == "go$go_version" ]]
[[ $(node --version) == "$node_version" ]]
node_binary=$(node -p 'process.execPath')
node_notice=$(dirname -- "$node_binary")/../LICENSE
test -s "$node_notice"

work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
runtime="$work/runtime"
mkdir -p "$runtime"/{bin,go,cache/go-mod,lib/markdownlint-cli2,licenses}
cp -a "$(go env GOROOT)/." "$runtime/go/"
find "$runtime/go" -type d -exec chmod u+w {} +
install -m 0755 "$node_binary" "$runtime/bin/node"
install -m 0644 "$node_notice" "$runtime/licenses/node-LICENSE"

shellcheck="shellcheck-$shellcheck_version"
curl --fail --silent --show-error --location --retry 3 \
    "https://github.com/koalaman/shellcheck/releases/download/$shellcheck_version/$shellcheck.linux.x86_64.tar.gz" \
    --output "$work/shellcheck.tar.gz"
printf '%s  %s\n' b7af85e41cc99489dcc21d66c6d5f3685138f06d34651e6d34b42ec6d54fe6f6 \
    "$work/shellcheck.tar.gz" | sha256sum --check -
tar -xzf "$work/shellcheck.tar.gz" -C "$work"
install -m 0755 "$work/$shellcheck/shellcheck" "$runtime/bin/shellcheck"
install -m 0644 "$work/$shellcheck/LICENSE.txt" "$runtime/licenses/shellcheck-LICENSE.txt"

export GOBIN="$runtime/bin" GOMODCACHE="$work/tool-mod"
go install -trimpath "github.com/golangci/golangci-lint/v2/cmd/golangci-lint@$golangci_version"
go install -trimpath "github.com/rhysd/actionlint/cmd/actionlint@$actionlint_version"
go version -m "$GOBIN/golangci-lint" "$GOBIN/actionlint" |
    awk '$1 == "mod" || $1 == "dep" { print $2 "@" $3 }' | sort -u > "$work/tool-modules.txt"
while IFS= read -r module; do
    source_dir=$(go mod download -json "$module" | jq -er '.Dir')
    notice_dir="$runtime/licenses/go-tools/$module"
    mkdir -p "$notice_dir"
    find "$source_dir" -maxdepth 1 -type f \
        \( -iname 'license*' -o -iname 'licence*' -o -iname 'copying*' -o -iname 'notice*' -o -iname 'copyright*' \) \
        -exec install -m 0644 -t "$notice_dir" {} +
done < "$work/tool-modules.txt"
cp -R "$GOMODCACHE/github.com/golangci/golangci-lint/v2@$golangci_version/third_party" \
    "$runtime/licenses/go-tools/github.com/golangci/golangci-lint/v2@$golangci_version/"
test -s "$runtime/licenses/go-tools/github.com/golangci/golangci-lint/v2@$golangci_version/LICENSE"
test -s "$runtime/licenses/go-tools/github.com/rhysd/actionlint@$actionlint_version/LICENSE.txt"
{
    printf -- '- Go %s: <%s>\n' "$go_version" "https://go.dev/dl/go$go_version.src.tar.gz"
    printf -- '- Node.js %s: <%s>\n' "$node_version" "https://nodejs.org/dist/$node_version/node-$node_version.tar.gz"
    printf -- '- ShellCheck %s: <%s>\n' "$shellcheck_version" \
        "https://github.com/koalaman/shellcheck/archive/refs/tags/$shellcheck_version.tar.gz"
    printf -- '- golangci-lint %s: <%s>\n' "$golangci_version" \
        "https://github.com/golangci/golangci-lint/archive/refs/tags/$golangci_version.tar.gz"
    printf -- '- actionlint %s: <%s>\n' "$actionlint_version" \
        "https://github.com/rhysd/actionlint/archive/refs/tags/$actionlint_version.tar.gz"
    printf '\n<details>\n<summary>Exact Go linter module sources</summary>\n\n'
    while IFS=@ read -r module version; do
        escaped=$(printf '%s' "$module" | LC_ALL=C sed -E 's/([A-Z])/!\L\1/g')
        printf -- '- %s@%s: <https://proxy.golang.org/%s/@v/%s.zip>\n' "$module" "$version" "$escaped" "$version"
    done < "$work/tool-modules.txt"
    printf '\n</details>\n'
} > "$runtime/licenses/sources.txt"
GOMODCACHE="$runtime/cache/go-mod" go mod download
find "$runtime/cache/go-mod/cache/download" -type f -name '*.lock' -delete

cp "$repo/scripts/handoff-runtime/"{package.json,package-lock.json} "$runtime/lib/markdownlint-cli2/"
npm --prefix "$runtime/lib/markdownlint-cli2" ci --ignore-scripts --omit=dev --no-audit --no-fund --no-bin-links
test -s "$runtime/lib/markdownlint-cli2/node_modules/markdownlint-cli2/LICENSE"
cat > "$runtime/bin/markdownlint-cli2" <<'SH'
#!/bin/sh
bin=${0%/*}
exec "$bin/node" "$bin/../lib/markdownlint-cli2/node_modules/markdownlint-cli2/markdownlint-cli2-bin.mjs" "$@"
SH
chmod 0755 "$runtime/bin/markdownlint-cli2"

archive=points-handoff-linux-amd64-v1.tar.gz
LC_ALL=C tar --sort=name --format=gnu --mtime=@0 --numeric-owner --owner=0 --group=0 \
    --hard-dereference -C "$runtime" -cf - bin cache go lib licenses | gzip -n > "$output/$archive"
(cd "$output" && sha256sum "$archive" | tee "$archive.sha256")
