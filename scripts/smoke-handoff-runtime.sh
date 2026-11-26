#!/usr/bin/env bash
set -euo pipefail

assets=${1:?Usage: smoke-handoff-runtime.sh ASSET_DIRECTORY}
archive=points-handoff-linux-amd64-v1.tar.gz
(cd "$assets" && sha256sum --check "$archive.sha256")

scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
runtime="$scratch/runtime"
mkdir -p "$runtime" "$scratch"/{home,tmp,host-bin}
tar -xzf "$assets/$archive" -C "$runtime"
test -s "$runtime/go/LICENSE"
test -s "$runtime/licenses/node-LICENSE"
test -s "$runtime/licenses/shellcheck-LICENSE.txt"
test -s "$runtime/lib/markdownlint-cli2/node_modules/markdownlint-cli2/LICENSE"
cp -a "$runtime/cache/go-mod" "$scratch/go-mod"

for tool in make git sh bash sed cut grep gcc as ld; do
    test -x "/usr/bin/$tool"
    ln -s "/usr/bin/$tool" "$scratch/host-bin/$tool"
done
env -i HOME="$scratch/home" TMPDIR="$scratch/tmp" \
    PATH="$runtime/go/bin:$runtime/bin:$scratch/host-bin" \
    CGO_ENABLED=1 GOENV=off GOTOOLCHAIN=local GOPROXY=off \
    GOBIN="$runtime/bin" GOMODCACHE="$scratch/go-mod" GOCACHE="$scratch/go-build" \
    bash -eu -c '
        command -v markdownlint-cli2
        if command -v npx; then
            echo "Unexpected npx on the offline PATH" >&2
            exit 1
        fi
        shellcheck --version
        make check
    '
