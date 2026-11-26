#!/usr/bin/env bash
set -euo pipefail

archive=${1:?Usage: render-release-notes.sh RUNTIME_ARCHIVE}
sources=$(tar -xOzf "$archive" licenses/sources.txt)
if [[ $sources != *[![:space:]]* ]]; then
    echo 'Runtime release source manifest is empty.' >&2
    exit 1
fi

printf '%s\n\n%s\n\n%s\n\n%s\n' \
    'Linux amd64 runtime for the Points Ethos handoff gate.' \
    'Corresponding sources for the bundled tools:' \
    "$sources" \
    'The archive also includes the Points Go module sources and the locked Markdownlint packages.'
