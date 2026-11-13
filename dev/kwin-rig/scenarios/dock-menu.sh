# The dock's menu on a dock that hides, in a KWin of its own, with nothing
# of the real desktop touched:
#   dev/kwin-rig/run.sh scenarios/dock-menu.sh
#
# The real Dock.qml in a quickshell inside the rig (dev/kwin-rig/dock.sh),
# hiding (`autohide`) and holding three applications and nothing else. The
# fake pointer brings it back, right-clicks Konsole, crosses the 8 px gap
# from the glass to the menu and rests there, goes back to the glass -- the
# menu stays open and the dock up all the while -- and leaves: both go. Then
# the menu again, and its "Remove from the dock" clicked.
#
# Konsole's tile is at x 960, the glass from y 1006 to 1072. The menu is
# centred over the tile and ends 8 px above the glass, at y 998; its rows
# are 38 px from the bottom up, past 6 px of padding: "Open" at y 973 and
# "Remove from the dock" at y 935 (Konsole has no windows, so no "Close").

source "$RIG/dock.sh"
input_start
send "move 960 400" "sleep 100"
dock_start '{ "dock": { "enabled": true, "position": "bottom", "visibility": "autohide", "magnify": false,
  "launcher": false, "places": false, "running": false,
  "pinned": ["org.kde.dolphin", "org.kde.konsole", "org.kde.kate"] } }'
dock_wait hidden=true 15
sleep 1.5

open_menu() {
    send "glide 960 400 960 1079 12 15" "sleep 600" "glide 960 1079 960 1039 4 20" "sleep 300" \
         "rdown" "sleep 60" "rup" "sleep 400"
    sleep 2.4
}

echo "== Konsole's menu"
open_menu
check "the right click opens it" "$(dock_said menu)" "org.kde.konsole"
check "the dock is up" "$(dock_said hidden)" "false"
shot menu-open

echo "== across the gap, onto the menu, and resting there"
send "glide 960 1039 960 985 10 40" "sleep 2000"
sleep 2.6
check "the menu stays open" "$(dock_said menu)" "org.kde.konsole"
check "and the dock up" "$(dock_said hidden)" "false"

echo "== back down onto the glass"
send "glide 960 985 960 1039 10 40" "sleep 1500"
sleep 2.1
check "still open" "$(dock_said menu)" "org.kde.konsole"
check "still up" "$(dock_said hidden)" "false"

echo "== away from both"
send "glide 960 1039 960 400 10 15" "sleep 1500"
sleep 2.0
check "the menu goes" "$(dock_said menu)" ""
check "and the dock hides" "$(dock_said hidden)" "true"

echo "== the menu again, and Remove from the dock"
open_menu
check "open again" "$(dock_said menu)" "org.kde.konsole"
send "glide 960 1039 960 935 10 30" "sleep 300" "down" "sleep 60" "up" "sleep 600"
sleep 1.6
check "Konsole is taken out" "$(dock_said pinned)" '["org.kde.dolphin","org.kde.kate"]'
check "and the menu closes" "$(dock_said menu)" ""

input_stop
dock_errors
