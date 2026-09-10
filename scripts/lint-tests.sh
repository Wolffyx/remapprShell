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

        while IFS= read -r qml; do
            if grep -qE '^\s*import\s+Quickshell' "$qml"; then
                log_error "$test imports $module, which cannot load outside a running shell"
                log_error "  $qml imports Quickshell, so qmltestrunner cannot instantiate the module"
                log_error "  move the pure code into a leaf module of its own, as qs.domain.osd.events is"
                fail=1
            fi
        done < <(find "$dir" -maxdepth 1 -name '*.qml' -type f | sort)
    done < <(grep -oE '^\s*import\s+qs\.[a-zA-Z0-9_.]+' "$test" | awk '{print $2}')
done

[ "$fail" -eq 0 ] || exit 1
log_step "test import lint clean ($checked module(s) checked)"
