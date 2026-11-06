# rig: global-shortcuts
#
# Meta+Z (kwin/snap/contents/ui/Picker.qml): the snap layouts panel for the
# active window, chosen from with the pointer and the keys:
#   dev/kwin-rig/run.sh scenarios/snap-key.sh
#
# The key is this project's -- the session daemon holds it, and pressing it
# runs `windows snap pick` -- and there is no daemon here, so the scenario
# runs that command, which is all the key does from there on. It reaches the
# script through kglobalaccel, which KWin runs inside itself: hence the line
# above, and this KWin's own shortcut server on this rig's own bus.
#
# The panel and its zones are where snap.sh says: halves at (826, 35) and
# (874, 35), thirds at (1046, 35), (1078, 35) and (1110, 35). Linux key
# codes: Escape 1, "3" 4, Enter 28, Right 106.

window a 900 600 steelblue
window b 700 500 seagreen
load kwin/snap
input_start

pick() { "$REPO_ROOT/scripts/windows.sh" snap pick; sleep 0.8; }

echo "== the script's action is KWin's to invoke"
check "kglobalaccel has it" \
    "$(qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.shortcutNames | grep -cxF 'Snap Layouts: Active Window')" "1"

echo "== a click on a zone"
activate a
pick
shot key-open
click 826 35
check "a: the left half" "$(tile a)" "0,0,960,1080"
send "key 1" "sleep 300"
sleep 0.6
check "b, offered for the other half and let go with Escape, stays out" "$(tile b)" "none"

echo "== the arrows and Enter"
activate b
pick
send "key 106" "sleep 100" "key 106" "sleep 100" "key 28" "sleep 400"
sleep 0.8
check "Right starts on the halves, Right again, Enter: b, the right half" "$(tile b)" "960,0,960,1080"
check "and a keeps the left" "$(tile a)" "0,0,960,1080"

echo "== a layout's number, then a zone's"
activate a
pick
send "key 4" "sleep 150"
shot key-numbered
send "key 4" "sleep 400"
sleep 0.8
check "3 and 3: a, the last third" "$(tile a)" "1280,0,640,1080"
send "key 28" "sleep 400"
sleep 0.8
check "and Snap Assist after it: Enter puts b in the first third" "$(tile b)" "0,0,640,1080"

echo "== Escape, a click on no zone, and the key again choose nothing"
activate a
before=$(geom a)
pick
send "key 1" "sleep 300"
sleep 0.5
check "Escape: a stays" "$(geom a)" "$before"
pick
click 960 600
check "a click below the panel: a stays" "$(geom a)" "$before"
pick
pick
click 826 35
check "pressed twice, the panel is gone before the click: a stays" "$(geom a)" "$before"

echo "== with the script not loaded, the command says so"
scripting unloadScript "$KWIN_SNAP_SCRIPT_ID" >/dev/null
check "and fails" "$("$REPO_ROOT/scripts/windows.sh" snap pick >/dev/null 2>&1; echo $?)" "1"

input_stop
