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

fail=0
while IFS= read -r file; do
    for name in "${signals[@]}"; do
        if grep -qE "^\s*function\s+${name}\s*\(" "$file"; then
            log_error "$file: defines function ${name}(), which is a signal on BarWidget"
            log_error "  QML refuses to load the file; handle it as on$(printf '%s' "${name:0:1}" | tr '[:lower:]' '[:upper:]')${name:1} instead"
            fail=1
        fi
    done
done < <(find shell/widgets -name '*.qml' -type f | sort)

[ "$fail" -eq 0 ] || exit 1
log_step "widget lint clean (${#signals[@]} base signal(s) checked)"
