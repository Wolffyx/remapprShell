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

"$RUNNER" -import "$IMPORT_ROOT" -input tests "$@"

# Shell-level tests. These run against a throwaway HOME, never the caller's.
log_step "snapshot/restore tests"
"$REPO_ROOT/tests/test-snapshot.sh"
