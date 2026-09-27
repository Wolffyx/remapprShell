#!/usr/bin/env bash
# Tests screen-edge configuration inside a throwaway HOME.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/tests/lib/harness.sh"
harness_init

# Stand-ins for everything that reaches the running desktop. A throwaway HOME
# does not make a throwaway KWin, so the suite must never reach the real one;
# these record any call that gets through.
CALLS="$SANDBOX/session-calls"
fake_recorders "$CALLS" qdbus6 busctl systemctl kquitapp6

edges() { "$REPO_ROOT/scripts/edges.sh" "$@" >/dev/null 2>&1; }
key() { kread kwinrc "$1" "$2"; }
status() { "$REPO_ROOT/scripts/edges.sh" status --json 2>/dev/null; }
js() { status | jq -r "$1"; }

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
# One read for the checks against one state: each read is a third of a second.
s=$(status)
check "top-left reads as window view"   "$(jq -r .edges.TopLeft <<<"$s")" "windowview"
check "top-right reads as grid"         "$(jq -r .edges.TopRight <<<"$s")" "grid"
check "bottom-right reads as a border"  "$(jq -r .edges.BottomRight <<<"$s")" "showdesktop"
check "untouched edge reads as none"    "$(jq -r .edges.Bottom <<<"$s")" "none"
check "triggers on"                     "$(jq -r .triggers <<<"$s")" "true"
check "customised"                      "$(jq -r .customised <<<"$s")" "true"
check "every action is offered"         "$(jq -r '.actions | length' <<<"$s")" "11"
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
check "switch records dropped"      "$(ledger_count edges-off)" "0"

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
check "ledger holds no edges"      "$(( $(ledger_count edges) + $(ledger_count edges-off) ))" "0"

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

# An edge runs the same actions a key does, and says so from the same list the
# daemon that runs them is rendered from. It used to pick them out of the
# daemon's source with sed.
echo "== an edge offers every shortcut action =="
listed=$("$REPO_ROOT/scripts/edges.sh" shell 2>/dev/null | sed -n 's/^actions: //p' | tr ' ' '\n' | grep . | paste -sd' ')
check "the shortcut list, in order" "$listed" \
      "$(grep -v '^#' "$REPO_ROOT/scripts/lib/shortcut-actions.tsv" | cut -f1 | paste -sd' ')"
edges shell Top screenshot-window
check "and takes one of them"       "$(key "Script-$KWIN_EDGES_SCRIPT_ID" Bindings)" "Top:screenshot-window"
edges revert

harness_done
