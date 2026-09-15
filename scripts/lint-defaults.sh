#!/usr/bin/env bash
# Fails if the schema and the shipped defaults disagree about a default.
#
# Two files say what a setting starts as: config/defaults/shell.json, which the
# shell actually loads, and the `default` in config/schema/shell.json, which is
# what docs/config.md tells people and what the settings window draws a "reset"
# against. When they disagree the documentation is simply wrong, and a control
# can sit at one value while the shell behaves as another -- which is how a
# corner-rounding slider came to show 18 on a shell rounding at 28.
#
# The defaults file is the truth: it is the one the shell reads.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
cd "$REPO_ROOT"

out=$(jq -n \
    --slurpfile schema config/schema/shell.json \
    --slurpfile defaults config/defaults/shell.json '
    ($defaults[0]) as $d
    | [ $schema[0].sections[]
        | (.keys // {}) | to_entries[]
        | select(.value | has("default"))
        | . as $k
        | ($k.key | split(".")) as $path
        | ($d | getpath($path)) as $have
        | if $have == null then
            "\($k.key): in the schema, missing from config/defaults/shell.json"
          elif $have != $k.value.default then
            "\($k.key): schema says \($k.value.default | tojson), defaults say \($have | tojson)"
          else empty end ]
    | .[]' -r)

if [ -n "$out" ]; then
    log_error "the schema and the shipped defaults disagree:"
    printf '%s\n' "$out" | sed 's/^/    /' >&2
    die "make them agree; config/defaults/shell.json is the one the shell reads"
fi

log_step "defaults lint clean"
