#!/usr/bin/env bash
# Tests screen-edge configuration inside a throwaway HOME.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SANDBOX=$(mktemp -d); trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME"

source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"

pass=0; fail=0
check() { if [ "$2" = "$3" ]; then printf '  PASS  %s\n' "$1"; pass=$((pass+1));
          else printf '  FAIL  %s (expected %q, got %q)\n' "$1" "$3" "$2" >&2; fail=$((fail+1)); fi; }
edges() { "$REPO_ROOT/scripts/edges.sh" "$@" >/dev/null 2>&1; }
key() { kreadconfig6 --file kwinrc --group "$1" --key "$2" --default '<unset>'; }

# A user who has already configured an edge themselves. Their choice must
# survive disable-all and come back on revert -- that is the whole point of the
# master switch being reversible rather than destructive.
kwriteconfig6 --file kwinrc --group ElectricBorders --key TopLeft "krunner"

echo "== set =="
edges set BottomRight showdesktop
check "corner bound"            "$(key ElectricBorders BottomRight)" "showdesktop"
check "rejects unknown edge"    "$(edges set Nowhere showdesktop && echo ran || echo refused)" "refused"
check "rejects unknown action"  "$(edges set Top nonsense && echo ran || echo refused)" "refused"

echo "== effect =="
edges effect overview TopLeft
check "effect bound to edge 7"  "$(key Effect-overview BorderActivate)" "7"
edges effect overview none
check "effect unbound is 9"     "$(key Effect-overview BorderActivate)" "9"
check "rejects unknown effect"  "$(edges effect nosucheffect Top && echo ran || echo refused)" "refused"

echo "== snap =="
edges snap off
check "tiling off"              "$(key Windows ElectricBorderTiling)" "false"
check "maximise off"            "$(key Windows ElectricBorderMaximize)" "false"

echo "== master switch =="
edges disable-all
check "user's corner neutralised" "$(key ElectricBorders TopLeft)" "None"
check "overview neutralised"      "$(key Effect-overview BorderActivate)" "9"

echo "== revert restores the user's own configuration =="
edges revert
check "user's krunner corner back" "$(key ElectricBorders TopLeft)" "krunner"
check "our corner removed"         "$(key ElectricBorders BottomRight)" "<unset>"
check "snap keys removed"          "$(key Windows ElectricBorderTiling)" "<unset>"
check "overview key removed"       "$(key Effect-overview BorderActivate)" "<unset>"

echo
if [ "$fail" -gt 0 ]; then printf 'FAILED: %d passed, %d failed\n' "$pass" "$fail" >&2; exit 1; fi
printf 'OK: %d passed\n' "$pass"
