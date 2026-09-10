#!/usr/bin/env bash
# Runs qmllint over the project's QML.
#
# With no arguments it covers shell/ and theme/. The theme QML is drawn by
# Plasma rather than by us -- the OSD, the window switcher -- which makes it
# more important to lint, not less: a syntax error there means Alt+Tab silently
# does nothing, with nothing in our own journal to say why.
#
# Given file arguments it lints exactly those, which is what the crash reporter
# uses to say something useful about the file a failure came from.
#
# Two things this gets right that a naive `find | xargs qmllint` does not:
#
#   1. It uses the Qt6 qmllint. On Arch, /usr/bin/qmllint belongs to
#      qt5-declarative and reports version "1.0"; handed a Qt6/Quickshell file
#      it exits 255 with no output at all. Linting against the wrong Qt major
#      is worse than not linting.
#   2. It runs one file per invocation and aggregates, so every bad file is
#      reported rather than aborting at the first.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/render.sh"
cd "$REPO_ROOT"

# Resolve the Qt6 qmllint explicitly; $PATH usually finds the Qt5 one first.
QMLLINT=""
for candidate in "${QMLLINT_BIN:-}" /usr/lib/qt6/bin/qmllint "$(command -v qmllint6 2>/dev/null || true)"; do
    [ -n "$candidate" ] && [ -x "$candidate" ] || continue
    if "$candidate" --version 2>&1 | grep -qE 'qmllint 6\.'; then
        QMLLINT=$candidate
        break
    fi
done
# Last resort: a $PATH qmllint, but only if it really is Qt6.
if [ -z "$QMLLINT" ] && command -v qmllint >/dev/null 2>&1; then
    if qmllint --version 2>&1 | grep -qE 'qmllint 6\.'; then
        QMLLINT=$(command -v qmllint)
    fi
fi
[ -n "$QMLLINT" ] || die "Qt6 qmllint not found (install qt6-declarative, or set QMLLINT_BIN)"
log_debug "using $QMLLINT ($("$QMLLINT" --version 2>&1))"

# The generated singleton must exist or every import of it is a false positive.
[ -f shell/core/Branding.qml ] || scripts/gen-branding.sh >/dev/null

# Quickshell special-cases the `qs.` import prefix, mapping it to the config
# root. qmllint does not: it resolves the module URI `qs.core` to the directory
# `<importpath>/qs/core`. So build a throwaway import root containing a single
# `qs` symlink to shell/, and point qmllint at that.
IMPORT_ROOT=$(mktemp -d)
trap 'rm -rf "$IMPORT_ROOT"' EXIT
ln -s "$REPO_ROOT/shell" "$IMPORT_ROOT/qs"

# QML that ships as a template is rendered and linted too. It is installed as
# real QML, so an error in one is an error that reaches the user -- and the
# splash screen, being a template, would otherwise be the one file nothing ever
# checks.
render_templates() {
    local src rendered
    while IFS= read -r src; do
        rendered="$IMPORT_ROOT/rendered/${src%.in}"
        mkdir -p "$(dirname "$rendered")"
        if render_template "$src" "$rendered" >/dev/null 2>&1; then
            printf '%s\n' "$rendered"
        else
            log_error "$src: unresolved placeholders"
            failed=$((failed + 1))
        fi
    done < <(find shell theme -name '*.qml.in' -type f | sort)
}

failed=0
checked=0
while IFS= read -r file; do
    checked=$((checked + 1))
    if ! out=$("$QMLLINT" -I "$IMPORT_ROOT" -I shell "$file" 2>&1); then
        log_error "$file"
        [ -n "$out" ] && printf '%s\n' "$out" >&2
        failed=$((failed + 1))
    elif [ -n "$out" ]; then
        # qmllint reports warnings on a zero exit; surface them without failing.
        printf '%s\n' "$out" >&2
    fi
done < <(if [ $# -gt 0 ]; then
             printf '%s\n' "$@"
         else
             find shell theme -name '*.qml' -type f | sort
             render_templates
         fi)

if [ "$failed" -gt 0 ]; then
    die "qmllint: $failed of $checked file(s) failed"
fi
log_step "qml lint clean ($checked files, $("$QMLLINT" --version 2>&1))"
