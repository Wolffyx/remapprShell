#!/usr/bin/env bash
# Runs the QML test suite.
#
# Uses the same synthetic `qs` import root as the QML lint, so tests import
# shell code exactly the way the shell does.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
cd "$REPO_ROOT"

RUNNER=${QMLTESTRUNNER_BIN:-/usr/lib/qt6/bin/qmltestrunner}
[ -x "$RUNNER" ] || die "qmltestrunner not found (install qt6-declarative, or set QMLTESTRUNNER_BIN)"

[ -f shell/core/Branding.qml ] || scripts/gen-branding.sh >/dev/null
scripts/gen-qmldir.sh >/dev/null

IMPORT_ROOT=$(mktemp -d)
LOGS=$(mktemp -d)
trap 'rm -rf "$IMPORT_ROOT" "$LOGS"' EXIT
ln -s "$REPO_ROOT/shell" "$IMPORT_ROOT/qs"

# The redaction test reads its fixture corpus with XMLHttpRequest, and Qt 6
# refuses local-file reads unless this is set. Without it the test fails in a
# way that looks like a JSON parse error rather than a permissions one.
#
# Offscreen, because the tests are pure functions and need no window -- and on
# Wayland qmltestrunner opens a real one per test file, on the desktop of
# whoever runs `make test`, and waits for it to be shown. With the screen
# locked it never is: every file then took exactly five seconds, the suite
# fifty instead of five, on 2026-09-11.
QT_QPA_PLATFORM=offscreen QML_XHR_ALLOW_FILE_READ=1 "$RUNNER" -import "$IMPORT_ROOT" -input tests "$@"

# Shell-level tests, each inside its own throwaway HOME.
#
# A HOME is not a session. systemd and the session bus are the user's real
# ones whatever $HOME says, so every suite runs with the switch that keeps our
# scripts away from them -- set here once, rather than trusted to each suite.
# One suite without it (test-update) restarted the user's running shell on
# every run until 2026-09-11.
source "$REPO_ROOT/scripts/lib/brand.sh"
export "$NO_SESSION_VAR=1"

# The same for reads. kreadconfig6 falls back through XDG_CONFIG_DIRS for a
# key a file does not set, and on Plasma that starts with the user's own
# ~/.config/kdedefaults -- an absolute path no sandbox HOME changes. A suite
# reading an unset key was reading the real desktop's answer.
export XDG_CONFIG_DIRS=/etc/xdg

# Every suite in tests/, found rather than listed: a list is a place for a new
# suite to be forgotten.
#
# They run side by side. Each has a HOME of its own, and most of their time is
# spent waiting rather than working -- test-theme's on Night Light, which no
# sandbox has -- so one after another they took three minutes, and side by
# side they take as long as the slowest. Each writes a log of its own, and the
# logs are printed in the order the suites are named, each as soon as it and
# the ones before it are done: the output reads as it did when they ran in
# turn. TEST_JOBS=1 runs them in turn.
suites=("$REPO_ROOT"/tests/test-*.sh)
max_jobs=${TEST_JOBS:-$(nproc 2>/dev/null || echo 4)}

run_suite() {   # <suite>: its output to its log, then its status beside it
    local name rc=0
    name=$(basename "$1" .sh)
    "$1" > "$LOGS/$name.log" 2>&1 || rc=$?
    echo "$rc" > "$LOGS/$name.rc.new" && mv "$LOGS/$name.rc.new" "$LOGS/$name.rc"
}

(
    for t in "${suites[@]}"; do
        while [ "$(jobs -rp | wc -l)" -ge "$max_jobs" ]; do wait -n || true; done
        run_suite "$t" &
    done
    wait
) &
pool=$!

failed=()
for t in "${suites[@]}"; do
    name=$(basename "$t" .sh)
    while [ ! -f "$LOGS/$name.rc" ] && kill -0 "$pool" 2>/dev/null; do sleep 0.1; done
    log_step "$name"
    cat "$LOGS/$name.log" 2>/dev/null || true
    [ "$(cat "$LOGS/$name.rc" 2>/dev/null)" = 0 ] || failed+=("$name")
done
wait "$pool" || true
[ ${#failed[@]} -eq 0 ] || die "failed: ${failed[*]}"

# The lock screen in Plasma's real greeter. The suites above use a stand-in;
# this is the check that catches what qmllint does not -- a type that is not
# installed, which the greeter refuses by drawing its built-in locker. It runs
# offscreen with no session bus, so nothing reaches the desktop.
source "$REPO_ROOT/scripts/lib/lockscreen.sh"
if lockscreen_greeter >/dev/null; then
    log_step "lock screen, in Plasma's greeter"
    "$REPO_ROOT/scripts/lockscreen.sh" check || exit 1
else
    log_warn "Plasma's greeter is not installed; the lock screen was not loaded"
fi
