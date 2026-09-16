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
trap 'rm -rf "$IMPORT_ROOT"' EXIT
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

for t in test-snapshot test-kconfig test-theme test-edges test-shortcuts test-switcher test-lockscreen test-update test-renderer test-redact test-report test-windows test-ask test-crash test-ctl test-config test-profiles test-setup; do
    log_step "$t"
    "$REPO_ROOT/tests/$t.sh" || exit 1
done

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
