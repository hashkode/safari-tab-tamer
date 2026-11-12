#!/bin/sh
# Pure fixture checks only: never invoke an interactive Safari mode here.
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
scratch=$(mktemp -d "${TMPDIR:-/tmp}/safari-tab-tamer-check.XXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

osacompile -o "$scratch/safari-tab-tamer.scpt" "$root/scripts/safari-tab-tamer.applescript"
version=$(osascript "$scratch/safari-tab-tamer.scpt" --version)
if [ "$version" != '1.0.0' ]; then
    printf '%s\n' "Unexpected version: $version" >&2
    exit 1
fi
osascript "$scratch/safari-tab-tamer.scpt" --self-test
osascript "$scratch/safari-tab-tamer.scpt" --help > "$scratch/help.txt"
test -s "$scratch/help.txt"
if osascript "$scratch/safari-tab-tamer.scpt" --not-a-real-option > "$scratch/invalid.txt" 2>&1; then
    printf '%s\n' 'Unknown options must fail without accessing Safari.' >&2
    exit 1
fi
printf '%s\n' 'Compilation, version, help, fixture tests, and invalid-option checks passed.'
