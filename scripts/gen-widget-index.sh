#!/usr/bin/env bash
# Bundles every built-in widget.json into shell/widgets/index.json.
#
# Built-in widgets are known at build time, so the shell reads one file at
# startup instead of scanning directories and spawning a process per widget.
# Third-party widgets are discovered at runtime -- they are the case that has
# to be dynamic; built-ins are not, and paying that cost for them would slow
# every launch for no benefit.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
cd "$REPO_ROOT"

command -v jq >/dev/null 2>&1 || die "jq is required"

out=shell/widgets/index.json
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

count=0
: > "$tmp"
for manifest in shell/widgets/*/widget.json; do
    [ -e "$manifest" ] || continue
    dir=$(dirname "$manifest")
    id=$(basename "$dir")

    jq -e . "$manifest" >/dev/null 2>&1 || die "$manifest is not valid JSON"

    # The directory name is authoritative: it is what the loader resolves a
    # widget path from, so a manifest claiming a different id would produce a
    # widget that can be configured but never loaded.
    declared=$(jq -r '.id // empty' "$manifest")
    [ "$declared" = "$id" ] || die "$manifest declares id '$declared' but lives in '$id/'"

    jq -c --arg id "$id" '. + {id: $id, builtin: true}' "$manifest" >> "$tmp"
    count=$((count + 1))
done

jq -s '{generated: true, widgets: .}' "$tmp" > "$out"
log_step "indexed $count built-in widget(s) -> $out"
