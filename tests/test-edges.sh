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

# Stand-ins for everything that reaches the running desktop. A throwaway HOME
# does not make a throwaway KWin, so the suite must never reach the real one;
# these record any call that gets through.
FAKEBIN="$SANDBOX/bin"; mkdir -p "$FAKEBIN"
CALLS="$SANDBOX/session-calls"; : > "$CALLS"
for t in qdbus6 busctl systemctl kquitapp6; do
    printf '#!/bin/sh\nprintf "%%s\\n" "%s $*" >> "%s"\n' "$t" "$CALLS" > "$FAKEBIN/$t"
    chmod +x "$FAKEBIN/$t"
done
export PATH="$FAKEBIN:$PATH"
export "$NO_SESSION_VAR=1"

pass=0; fail=0
check() { if [ "$2" = "$3" ]; then printf '  PASS  %s\n' "$1"; pass=$((pass+1));
          else printf '  FAIL  %s (expected %q, got %q)\n' "$1" "$3" "$2" >&2; fail=$((fail+1)); fi; }
edges() { "$REPO_ROOT/scripts/edges.sh" "$@" >/dev/null 2>&1; }
key() { kreadconfig6 --file kwinrc --group "$1" --key "$2" --default '<unset>'; }
js() { "$REPO_ROOT/scripts/edges.sh" status --json 2>/dev/null | jq -r "$1"; }
scoped() { jq "[.entries[] | select(.scope == \"$1\")] | length" "$STATE_DIR/kconfig-ledger.json"; }

# A user who has already configured an edge themselves. Their choice must
# survive everything below and come back on revert.
kwriteconfig6 --file kwinrc --group ElectricBorders --key TopLeft "krunner"

echo "== set =="
edges set BottomRight showdesktop
check "corner bound"            "$(key ElectricBorders BottomRight)" "showdesktop"
check "rejects unknown edge"    "$(edges set Nowhere showdesktop && echo ran || echo refused)" "refused"
check "rejects unknown action"  "$(edges set Top nonsense && echo ran || echo refused)" "refused"

echo "== an effect keeps a list of edges =="
edges set TopRight overview
check "overview on the top-right (1)"   "$(key Effect-overview BorderActivate)" "1"
edges set BottomLeft overview
check "and the bottom-left too (1,5)"   "$(key Effect-overview BorderActivate)" "1,5"

echo "== an edge is in one place only =="
edges set TopRight grid
check "grid is the overview's grid key" "$(key Effect-overview GridBorderActivate)" "1"
check "top-right left the overview"     "$(key Effect-overview BorderActivate)" "5"
edges set TopLeft windowview
check "user's corner action cleared"    "$(key ElectricBorders TopLeft)" "None"
check "window view on the top-left"     "$(key Effect-windowview BorderActivate)" "7"
edges set BottomLeft none
check "overview on no edge is 9"        "$(key Effect-overview BorderActivate)" "9"
check "an unchanged key is not written" "$(key ElectricBorders BottomLeft)" "<unset>"
check "nothing writes desktopgrid"      "$(key Effect-desktopgrid BorderActivate)" "<unset>"

echo "== status --json =="
check "top-left reads as window view"   "$(js .edges.TopLeft)" "windowview"
check "top-right reads as grid"         "$(js .edges.TopRight)" "grid"
check "bottom-right reads as a border"  "$(js .edges.BottomRight)" "showdesktop"
check "untouched edge reads as none"    "$(js .edges.Bottom)" "none"
check "triggers on"                     "$(js .triggers)" "true"
check "customised"                      "$(js .customised)" "true"
check "every action is offered"         "$(js '.actions | length')" "11"
kwriteconfig6 --file kwinrc --group Plugins --key krohnkiteEnabled true
check "a tiling script is named"        "$(js '.tilingScripts | join(",")')" "krohnkite"
kwriteconfig6 --file kwinrc --group Plugins --key krohnkiteEnabled --delete

echo "== effect, kept for scripts =="
edges effect overview Top
check "effect binds an edge"            "$(key Effect-overview BorderActivate)" "0"
edges effect overview none
check "effect none takes it off"        "$(key Effect-overview BorderActivate)" "9"
check "rejects desktopgrid, gone in KWin 6" "$(edges effect desktopgrid Top && echo ran || echo refused)" "refused"
check "rejects a border action"         "$(edges effect showdesktop Top && echo ran || echo refused)" "refused"

echo "== snap =="
edges snap off
check "tiling off"              "$(key Windows ElectricBorderTiling)" "false"
check "maximise off"            "$(key Windows ElectricBorderMaximize)" "false"

echo "== master switch off =="
edges disable-all
check "border action neutralised"   "$(key ElectricBorders BottomRight)" "None"
check "window view neutralised"     "$(key Effect-windowview BorderActivate)" "9"
check "grid neutralised"            "$(key Effect-overview GridBorderActivate)" "9"
check "reads as off"                "$(js .triggers)" "false"
check "set refused while off"       "$(edges set Top overview && echo ran || echo refused)" "refused"
check "snap refused while off"      "$(edges snap on && echo ran || echo refused)" "refused"
check "off twice is harmless"       "$(edges disable-all && echo ok)" "ok"

echo "== master switch on puts back the moment before, not the install =="
edges enable-all
check "our corner back"             "$(key ElectricBorders BottomRight)" "showdesktop"
check "window view back"            "$(key Effect-windowview BorderActivate)" "7"
check "grid back"                   "$(key Effect-overview GridBorderActivate)" "1"
check "top-left stays as we set it" "$(key ElectricBorders TopLeft)" "None"
check "snap stays as we set it"     "$(key Windows ElectricBorderTiling)" "false"
check "reads as on"                 "$(js .triggers)" "true"
check "switch records dropped"      "$(scoped edges-off)" "0"

echo "== revert restores the user's own configuration =="
edges revert
check "user's krunner corner back" "$(key ElectricBorders TopLeft)" "krunner"
check "our corner removed"         "$(key ElectricBorders BottomRight)" "<unset>"
check "snap keys removed"          "$(key Windows ElectricBorderTiling)" "<unset>"
check "overview key removed"       "$(key Effect-overview BorderActivate)" "<unset>"
check "grid key removed"           "$(key Effect-overview GridBorderActivate)" "<unset>"
check "window view key removed"    "$(key Effect-windowview BorderActivate)" "<unset>"
check "not customised"             "$(js .customised)" "false"

echo "== revert while the switch is off =="
edges set BottomRight showdesktop
edges disable-all
edges revert
check "user's corner back"         "$(key ElectricBorders TopLeft)" "krunner"
check "ours gone, not resurrected" "$(key ElectricBorders BottomRight)" "<unset>"
check "reads as on"                "$(js .triggers)" "true"
check "ledger holds no edges"      "$(( $(scoped edges) + $(scoped edges-off) ))" "0"

echo "== this shell's own edges =="
edges shell Left sidebar
check "binding written"          "$(key "Script-$KWIN_EDGES_SCRIPT_ID" Bindings)" "Left:sidebar"
check "script switched on"       "$(key Plugins "${KWIN_EDGES_SCRIPT_ID}Enabled")" "true"
check "script rendered"          "$([ -f "$KWIN_SCRIPTS_DIR/$KWIN_EDGES_SCRIPT_ID/contents/code/main.js" ] && echo yes || echo no)" "yes"
# ElectricBorder 6 is Left. A wrong number here is an edge that silently does
# nothing, which is indistinguishable from the script not loading.
check "rendered as the border"   "$(sed -n 's/^const BINDINGS = //p' "$KWIN_SCRIPTS_DIR/$KWIN_EDGES_SCRIPT_ID/contents/code/main.js")" '[[6,"sidebar"]];'
check "no placeholder left"      "$(grep -c '@[A-Z_]*@' "$KWIN_SCRIPTS_DIR/$KWIN_EDGES_SCRIPT_ID/contents/code/main.js")" "0"

# An edge runs one action. Binding it again replaces rather than stacking.
edges shell Left launcher
check "rebound, not doubled"     "$(key "Script-$KWIN_EDGES_SCRIPT_ID" Bindings)" "Left:launcher"

edges shell Right sidebar
check "a second edge is kept"    "$(key "Script-$KWIN_EDGES_SCRIPT_ID" Bindings)" "Left:launcher,Right:sidebar"

check "rejects unknown action"   "$(edges shell Top nonsense && echo ran || echo refused)" "refused"
check "rejects unknown edge"     "$(edges shell Nowhere sidebar && echo ran || echo refused)" "refused"

edges shell Left none
check "one edge released"        "$(key "Script-$KWIN_EDGES_SCRIPT_ID" Bindings)" "Right:sidebar"

# The last one going takes the package with it: a loaded script claiming no
# edge is a thing to explain rather than a thing to keep.
edges shell Right none
check "last edge released"       "$(key "Script-$KWIN_EDGES_SCRIPT_ID" Bindings)" ""
check "script switched off"      "$(key Plugins "${KWIN_EDGES_SCRIPT_ID}Enabled")" "false"
check "script removed"           "$([ -d "$KWIN_SCRIPTS_DIR/$KWIN_EDGES_SCRIPT_ID" ] && echo yes || echo no)" "no"

edges shell Left sidebar
edges revert
check "revert takes it away"     "$(key "Script-$KWIN_EDGES_SCRIPT_ID" Bindings)" "<unset>"
check "revert removes the script" "$([ -d "$KWIN_SCRIPTS_DIR/$KWIN_EDGES_SCRIPT_ID" ] && echo yes || echo no)" "no"

echo "== the live session =="
check "no call reached the session" "$(wc -l < "$CALLS")" "0"
env -u "$NO_SESSION_VAR" "$REPO_ROOT/scripts/edges.sh" revert >/dev/null 2>&1
check "with one, KWin is asked to reload" "$(grep -c reconfigure "$CALLS")" "1"

echo
if [ "$fail" -gt 0 ]; then printf 'FAILED: %d passed, %d failed\n' "$pass" "$fail" >&2; exit 1; fi
printf 'OK: %d passed\n' "$pass"
