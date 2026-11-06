# Auto-tiling (kwin/tile) under the pointer, and around it:
#   dev/kwin-rig/run.sh scenarios/auto-tile-drag.sh
#
# A window dragged onto another swaps with it; one dragged nowhere goes back;
# the edge two tiled windows share, dragged, moves both and stays where it
# was left when the next window comes. Then the gap the script was given, a
# window of one size, the snap layouts standing aside, another desktop, and
# the script unloaded. 1920x1080, as auto-tile.sh.

load kwin/snap AutoTile=true
load kwin/tile Gap=10
input_start

window a 600 400 steelblue
window b 600 400 seagreen
echo "== the gap"
check "a's tile, the left half" "$(tile a)" "0,0,960,1080"
check "the frame 10 px in at the screen's edge, 5 at the shared one" "$(geom a | cut -d' ' -f1-4)" "10 10 945 1060"

echo "== dragged onto the other: the two swap"
drag a 1400 500
check "a is on the right" "$(tile a)" "960,0,960,1080"
check "b on the left" "$(tile b)" "0,0,960,1080"
check "and the snap layouts took nothing: no panel up" "$(kwin_windows)" "0"
shot drag-swapped

echo "== dragged to the top, where the snap layouts would open: back to its tile"
drag b 960 5
check "b is in its tile again" "$(tile b)" "0,0,960,1080"

echo "== the shared edge, dragged"
send "move 955 600" "sleep 80" "down" "sleep 80" "glide 955 600 1300 600 12 15" "sleep 150" "up" "sleep 500"
sleep 1.2
check "b, wider" "$(tile b | cut -d, -f3)" "$(tile b | cut -d, -f3 | awk '$1 > 1100 { print }')"
edge=$(tile b | cut -d, -f3)
check "a gave up what b took" "$(tile a)" "$edge,0,$((1920 - edge)),1080"
window c 600 400 indianred
check "c comes and splits b, the edge with a staying" "$(tile a)" "$edge,0,$((1920 - edge)),1080"
check "c, beside b, which is wider than tall" "$(tile c)" "$((edge / 2)),0,$((edge / 2)),1080"
shot drag-resized

echo "== one size only: floats"
cat > "$RUN/fixed.qml" <<'QML'
import QtQuick
import QtQuick.Window
Window { title: "fixed"; width: 320; height: 240; minimumWidth: 320; maximumWidth: 320
         minimumHeight: 240; maximumHeight: 240; visible: true; color: "orchid" }
QML
QT_QPA_PLATFORMTHEME=generic qml6 "$RUN/fixed.qml" > "$RUN/fixed.client.log" 2>&1 &
sleep 1.5
check "the fixed window has no tile" "$(tile fixed)" "none"
check "and its size" "$(geom fixed | cut -d' ' -f3-4)" "320 $(geom fixed | cut -d' ' -f4)"

echo "== another desktop"
kjs desktops <<'JS'
workspace.createDesktop(1, "two");
JS
sleep 0.5
kjs send <<'JS'
const w = workspace.windowList().find(w => w.caption === "c");
w.desktops = [workspace.desktops[1]];
JS
sleep 1
check "c left: the first desktop's tiles close up" "$(tile b)" "0,0,$edge,1080"
# KWin names a window's tile for the desktop in front only: c's is seen from
# the second desktop.
kjs second <<'JS'
workspace.currentDesktop = workspace.desktops[1];
JS
sleep 0.8
check "c alone on the second: the whole screen" "$(tile c)" "0,0,1920,1080"
kjs first <<'JS'
workspace.currentDesktop = workspace.desktops[0];
JS
sleep 0.8

# Switched off in kwinrc before it is unloaded, as `behaviour set autoTile
# false` does: letting the windows go saves KWin's tiles, the reconfigure
# that follows loads every enabled script that is not running, and the
# script came straight back and tiled them all again.
echo "== unloaded: every window let go, where it is"
before=$(geom a | cut -d' ' -f1-4)
kwriteconfig6 --file kwinrc --group Plugins --key "$SLUG-tileEnabled" false
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "$SLUG-tile" >/dev/null
sleep 1
check "a has no tile" "$(tile a)" "none"
check "and has not moved" "$(geom a | cut -d' ' -f1-4)" "$before"
input_stop
