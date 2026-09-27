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
declare -A offenders=()   # module -> its singletons that import Quickshell

# quickshell_singletons <dir>: the singletons of the module in <dir> that import
# Quickshell, one to a line. The qmldir names the singletons: "singleton <Type>
# <version> <file>".
quickshell_singletons() {
    local dir=$1
    local -a singletons
    [ -f "$dir/qmldir" ] || return 0
    mapfile -t singletons < <(awk '$1 == "singleton" { print "'"$dir"'/" $NF }' "$dir/qmldir" | sort)
    [ "${#singletons[@]}" -gt 0 ] || return 0
    # -s: a singleton the qmldir names but that is not there is not this lint's
    # to report.
    grep -lsE '^\s*import\s+Quickshell' "${singletons[@]}" || true
}

# check_module <test> <module>: 1 when a singleton of the module imports
# Quickshell, and so keeps the whole module from loading under qmltestrunner.
# Each module is read once, however many tests import it -- most import the
# same few, and it was read again for every one.
check_module() {
    local test=$1 module=$2 dir qml
    # qs.domain.osd.events -> shell/domain/osd/events
    dir="shell/${module#qs.}"
    dir=${dir//./\/}
    [ -d "$dir" ] || return 0
    checked=$((checked + 1))

    [ -n "${offenders[$module]+set}" ] || offenders[$module]=$(quickshell_singletons "$dir")
    [ -n "${offenders[$module]}" ] || return 0
    while IFS= read -r qml; do
        log_error "$test imports $module, which cannot load outside a running shell"
        log_error "  $qml is a singleton of that module and imports Quickshell,"
        log_error "  so qmltestrunner instantiates it and the whole module fails"
        log_error "  move the pure code into a leaf module of its own, as qs.domain.osd.events is"
    done <<< "${offenders[$module]}"
    return 1
}

# Every test's qs imports, as "<test>:<import line>", by one grep over them all
# rather than a grep and an awk a test.
shopt -s nullglob
tests=(tests/tst_*.qml)
while IFS=: read -r test line; do
    check_module "$test" "${line##*[[:space:]]}" || fail=1
done < <(grep -HoE '^\s*import\s+qs\.[a-zA-Z0-9_.]+' "${tests[@]}" < /dev/null)

[ "$fail" -eq 0 ] || exit 1
log_step "test import lint clean ($checked module(s) checked)"
