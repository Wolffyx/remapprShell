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
shopt -s nullglob
manifests=(shell/widgets/*/widget.json)

# Only when the one jq below has failed: which manifest, and why, one at a time
# and in order, as the loop over them all used to say it.
explain_failure() {
    local manifest id declared
    for manifest in "${manifests[@]}"; do
        jq -e . "$manifest" >/dev/null 2>&1 || die "$manifest is not valid JSON"
        id=${manifest%/widget.json}
        id=${id##*/}
        declared=$(jq -r '.id // empty' "$manifest")
        [ "$declared" = "$id" ] || die "$manifest declares id '$declared' but lives in '$id/'"
    done
    die "jq could not index the widgets, though every manifest reads"
}

# One jq for every manifest; it was three a widget. With none at all it reads
# an empty stdin rather than waiting on the terminal.
#
# The directory name is authoritative: it is what the loader resolves a widget
# path from, so a manifest claiming a different id would produce a widget that
# can be configured but never loaded.
index=$(jq -n '{generated: true, widgets: [inputs
            | (input_filename | split("/")[-2]) as $id
            | if (.id // "" | tostring) != $id then error("id") else . end
            | . + {id: $id, builtin: true}]}' "${manifests[@]}" < /dev/null 2>/dev/null) \
    || explain_failure
printf '%s\n' "$index" > "$out"
log_step "indexed ${#manifests[@]} built-in widget(s) -> $out"
