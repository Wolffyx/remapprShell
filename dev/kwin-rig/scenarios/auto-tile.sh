# rig: global-shortcuts
#
# Auto-tiling (kwin/tile): Hyprland's dwindle layout in KWin's own tiles.
#   dev/kwin-rig/run.sh scenarios/auto-tile.sh
#
# Windows are opened one after another and each must take half of the one
# focused before it, along that one's longer side; then the keys -- invoked
# through kglobalaccel as `windows tile` does, there being no session daemon
# here -- floating, closing, a resize, and the desktop's own switch. Every
# check is a tile, as KWin has it: the tile is the place, the window sits
# KWin's padding inside it. At 1920x1080, so a half is 960 wide.

invoke() { qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut "Auto Tile: $1" >/dev/null; sleep 0.6; }

load kwin/tile

echo "== windows as they open"
window a 600 400 steelblue
check "a alone: the whole screen" "$(tile a)" "0,0,1920,1080"
window b 600 400 seagreen
check "b: a keeps the left half" "$(tile a)" "0,0,960,1080"
check "b: the right half" "$(tile b)" "960,0,960,1080"
window c 600 400 indianred
check "c splits b, taller than wide: b on top" "$(tile b)" "960,0,960,540"
check "c: under b" "$(tile c)" "960,540,960,540"
window d 600 400 goldenrod
check "d splits c, wider than tall: c on the left" "$(tile c)" "960,540,480,540"
check "d: right of c" "$(tile d)" "1440,540,480,540"
check "the frame is the padding inside the tile" "$(geom d | cut -d' ' -f1-4)" "1442 542 474 534"
shot auto-tile-four

echo "== a dialog floats"
cat > "$RUN/dialog.qml" <<'QML'
import QtQuick
import QtQuick.Window
Window { id: main; title: "owner"; width: 300; height: 200; visible: true
    Window { title: "dialog"; transientParent: main; flags: Qt.Dialog; width: 200; height: 120; visible: true } }
QML
QT_QPA_PLATFORMTHEME=generic qml6 "$RUN/dialog.qml" > "$RUN/dialog.client.log" 2>&1 &
sleep 1.5
check "the dialog has no tile" "$(tile dialog)" "none"
check "its owner does" "$([ "$(tile owner)" = none ] && echo none || echo tiled)" "tiled"
kill %?dialog.qml 2>/dev/null; pkill -f "$RUN/dialog.qml"; sleep 1
check "the owner gone: d has its place back" "$(tile d)" "1440,540,480,540"

echo "== the keys"
activate d
invoke "Focus Left"
check "focus left of d is c" "$(active)" "c"
invoke "Focus Up"
check "focus up from c is b" "$(active)" "b"
invoke "Swap Left"
check "b swapped left: b on the left half" "$(tile b)" "0,0,960,1080"
check "and a where b was" "$(tile a)" "960,0,960,540"
invoke "Swap Left"
check "nothing further left: b stays" "$(tile b)" "0,0,960,1080"
activate d
invoke "Move Up"
check "d moved up, past a: above it" "$(tile d)" "960,0,960,270"
check "a under it" "$(tile a)" "960,270,960,270"
check "c takes the whole bottom" "$(tile c)" "960,540,960,540"

echo "== floating, and back"
activate c
invoke "Toggle Floating"
check "c floats" "$(tile c)" "none"
check "a fills what c left" "$(tile a)" "960,540,960,540"
invoke "Toggle Floating"
check "c tiled again, splitting a" "$(tile c)" "1440,540,480,540"

echo "== a window closed gives its half to its sibling"
pkill -f "$RUN/c.qml"; sleep 1
check "a has the bottom again" "$(tile a)" "960,540,960,540"
pkill -f "$RUN/b.qml"; sleep 1
check "b gone: d takes the top of the screen" "$(tile d)" "0,0,1920,540"
check "and a the bottom" "$(tile a)" "0,540,1920,540"

echo "== the desktop's switch"
invoke "Toggle Desktop"
check "off: a has no tile" "$(tile a)" "none"
window e 500 300 orchid
check "off: a new window is left alone" "$(tile e)" "none"
invoke "Toggle Desktop"
check "on again: everything tiled" "$(for t in a d e; do [ "$(tile $t)" = none ] && echo n || echo y; done | tr -d '\n')" "yyy"
