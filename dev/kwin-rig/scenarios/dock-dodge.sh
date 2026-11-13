# The dock stepping aside for windows (`dock.visibility: dodge`), in a KWin
# of its own, with nothing of the real desktop touched:
#   dev/kwin-rig/run.sh scenarios/dock-dodge.sh
#
# The real Dock.qml in a quickshell inside the rig (dev/kwin-rig/dock.sh),
# told about windows the way the shell is: kwin/windows pushes the list to
# the stand-in daemon, which signals it on. One window, moved by a KWin
# script: clear of the dock (it stays), down into its space (it hides), the
# pointer to the edge (it comes back over the window), the pointer away (it
# hides again), the window up and clear (it comes back). Then the window
# minimised in the dock's space (it stays).
#
# The dock reaches thickness + margin = 74 px up from the bottom at the
# default 48 px tiles, so a window whose bottom edge is below y 1005 is in
# its space.

windows_stub
load kwin/windows
window a 600 400 steelblue

place() {   # <x> <y> <w> <h>
    kjs place <<JS
for (const w of workspace.windowList()) if (w.caption === "a")
    w.frameGeometry = { x: $1, y: $2, width: $3, height: $4 };
JS
    sleep 1.2
}

source "$RIG/dock.sh"
input_start
send "move 960 200" "sleep 100"
place 100 100 600 400
dock_start '{ "dock": { "enabled": true, "position": "bottom", "visibility": "dodge", "magnify": false } }'
dock_wait 'hidden=' 15
sleep 2.5

echo "== a window clear of the dock"
check "it is shown" "$(dock_said hidden)" "false"

echo "== the window down into the dock's space"
place 600 640 700 420
check "it hides" "$(dock_said hidden)" "true"

echo "== the pointer to the edge, over the window"
send "glide 960 200 960 1079 12 15" "sleep 1500"
sleep 2.2
check "the edge brings it back" "$(dock_said hidden)" "false"

echo "== the pointer away again"
send "glide 960 1079 960 300 10 15" "sleep 1500"
sleep 2.0
check "it hides again" "$(dock_said hidden)" "true"

echo "== the window up and clear"
place 600 100 700 420
check "it comes back" "$(dock_said hidden)" "false"

echo "== the window minimised in the dock's space"
place 600 640 700 420
check "down again, it hides" "$(dock_said hidden)" "true"
kjs minimise <<'JS'
for (const w of workspace.windowList()) if (w.caption === "a") w.minimized = true;
JS
sleep 1.2
check "minimised, it comes back" "$(dock_said hidden)" "false"

input_stop
dock_errors
