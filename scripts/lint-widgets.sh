#!/usr/bin/env bash
# Fails on the widget mistakes that only show up at load time.
#
# qmllint does not resolve BarWidget, so it cannot see that a widget has
# defined a function with the same name as one of the base type's signals.
# QML rejects the whole file for it -- "Duplicate method name: invalid override
# of property change signal or superclass signal" -- and the widget silently
# does not appear on the panel. It cost an afternoon once; it costs a lint now.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
cd "$REPO_ROOT"

BASE=shell/ui/primitives/BarWidget.qml
[ -f "$BASE" ] || die "no BarWidget at $BASE"

# The signals a widget must handle with `onX`, never redefine as a function.
mapfile -t signals < <(grep -oE '^\s*signal\s+[a-zA-Z_][a-zA-Z0-9_]*' "$BASE" \
                       | awk '{print $2}' | sort -u)

# Every function a widget defines under a signal's name, as "<file>:<name>",
# by one grep over every widget file for every signal at once -- it was a grep
# a file a signal. Sorted by file, then by name, and each pair once, as that
# loop reported them.
redefinitions() {
    local names
    [ "${#signals[@]}" -gt 0 ] || return 0
    printf -v names '%s|' "${signals[@]}"
    find shell/widgets -name '*.qml' -type f -exec grep -HoE "^\s*function\s+(${names%|})\s*\(" {} + \
        | sed -E 's/:\s*function\s+([a-zA-Z0-9_]+).*/:\1/' \
        | sort -t: -k1,1 -k2,2 -u
}

fail=0
while IFS=: read -r file name; do
    log_error "$file: defines function ${name}(), which is a signal on BarWidget"
    log_error "  QML refuses to load the file; handle it as on${name^} instead"
    fail=1
done < <(redefinitions)

[ "$fail" -eq 0 ] || exit 1
log_step "widget lint clean (${#signals[@]} base signal(s) checked)"
