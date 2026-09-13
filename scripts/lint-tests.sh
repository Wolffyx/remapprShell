#!/usr/bin/env bash
# Fails when a QML test imports a module that cannot be loaded without a
# running shell.
#
# qmltestrunner instantiates every singleton in a module it imports. One
# singleton that touches the Quickshell runtime therefore makes the WHOLE
# module unimportable -- and every pure function sitting beside it becomes
# untestable by association, with an error that names the wrong type:
#
#   FAIL!  : qmltestrunner::tst_Redact::compile() Type CrashWatch unavailable
#
# The test that breaks is not the test that was changed, which is what makes
# this worth a lint. It has happened twice: once when the notification watcher
# landed beside the OSD parser, once when the crash watcher landed beside the
# redaction. The fix both times was to move the pure part into a leaf module of
# its own, and that is what this enforces.
#
# Singletons only, which is what the paragraph above actually says. An ordinary
# component is compiled with the module and instantiated only where a test
# writes it down, so a component that touches the runtime costs nothing to the
# tests that never build one -- qs.ui.primitives has no singletons at all, and
# the wider rule refused a test of BarWidget that runs perfectly well.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
cd "$REPO_ROOT"

fail=0
checked=0

for test in tests/tst_*.qml; do
    [ -f "$test" ] || continue
    while IFS= read -r module; do
        # qs.domain.osd.events -> shell/domain/osd/events
        dir="shell/${module#qs.}"
        dir=${dir//./\/}
        [ -d "$dir" ] || continue
        checked=$((checked + 1))

        # The qmldir names the singletons: "singleton <Type> <version> <file>".
        [ -f "$dir/qmldir" ] || continue

        while IFS= read -r qml; do
            [ -f "$qml" ] || continue
            if grep -qE '^\s*import\s+Quickshell' "$qml"; then
                log_error "$test imports $module, which cannot load outside a running shell"
                log_error "  $qml is a singleton of that module and imports Quickshell,"
                log_error "  so qmltestrunner instantiates it and the whole module fails"
                log_error "  move the pure code into a leaf module of its own, as qs.domain.osd.events is"
                fail=1
            fi
        done < <(awk '$1 == "singleton" { print "'"$dir"'/" $NF }' "$dir/qmldir" | sort)
    done < <(grep -oE '^\s*import\s+qs\.[a-zA-Z0-9_.]+' "$test" | awk '{print $2}')
done

[ "$fail" -eq 0 ] || exit 1
log_step "test import lint clean ($checked module(s) checked)"
