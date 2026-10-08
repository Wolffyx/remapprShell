#!/usr/bin/env bash
# Fails if a committed generated file is not what its sources make.
#
# Branding.qml and the widget index are generated, and committed because the
# shell reads them as it starts (see scripts/lib/generated.sh). A committed
# copy can go stale -- branding.json or VERSION changed, a widget.json edited
# -- and nothing at runtime would say so. Checked before `make brand` runs,
# which would quietly make them right in the working tree and hide it.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"

fail=0
"$REPO_ROOT/scripts/gen-branding.sh" --check     || fail=1
"$REPO_ROOT/scripts/gen-widget-index.sh" --check || fail=1

[ "$fail" -eq 0 ] || exit 1
log_step "generated-files lint clean"
