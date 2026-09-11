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
QML_XHR_ALLOW_FILE_READ=1 "$RUNNER" -import "$IMPORT_ROOT" -input tests "$@"

# Shell-level tests, each inside its own throwaway HOME.
#
# A HOME is not a session. systemd and the session bus are the user's real
# ones whatever $HOME says, so every suite runs with the switch that keeps our
# scripts away from them -- set here once, rather than trusted to each suite.
# One suite without it (test-update) restarted the user's running shell on
# every run until 2026-09-11.
source "$REPO_ROOT/scripts/lib/brand.sh"
export "$NO_SESSION_VAR=1"

for t in test-snapshot test-kconfig test-theme test-edges test-shortcuts test-update test-renderer test-redact test-report test-windows test-ask test-crash; do
    log_step "$t"
    "$REPO_ROOT/tests/$t.sh" || exit 1
done
