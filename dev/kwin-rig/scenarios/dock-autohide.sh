# The dock hiding itself (`dock.visibility: autohide`), in a KWin of its
# own, with nothing of the real desktop touched:
#   dev/kwin-rig/run.sh scenarios/dock-autohide.sh
#
# Not a KWin script: the shell's own dock, the real Dock.qml, in a quickshell
# started inside the rig with a profile of the run's own -- the dock on, at
# the bottom, hiding -- and nothing else of the shell. A copy of it says
# every time the dock hides or shows ("DOCK hidden=..." in qs.log), and the
# fake pointer goes where a hand would: to the edge, onto the dock, along
# the edge past it, and away.
#
# DOCK_FROM=<rev> runs the dock as it was at that commit (dev/kwin-rig/dock.sh).

source "$RIG/dock.sh"
input_start
send "move 960 400" "sleep 100"
dock_start '{ "dock": { "enabled": true, "position": "bottom", "visibility": "autohide", "magnify": false } }'
# The dock first speaks before the profile is read, as `always` (hidden=false);
# hidden=true is the profile's autohide. Then a moment for the surface to
# settle before the pointer moves.
dock_wait hidden=true 15
sleep 1.5

# The dock's last word, and how many times it has spoken since `mark`.
state() { dock_said hidden; }
mark() { MARK=$(dock_count hidden); }
flips() { echo $(( $(dock_count hidden) - MARK )); }

# At 1920x1080 and the default 48 px tiles the glass runs from y 1006 to
# 1072, 8 px clear of the edge, centred along it.
echo "== hidden to start with"
check "the dock starts hidden" "$(state)" "true"

echo "== the pointer comes to rest at the edge, under the dock"
mark
send "glide 960 400 960 1079 12 15" "sleep 2000"
sleep 2.6
check "it shows" "$(state)" "false"
check "and stays shown, once" "$(flips)" "1"
shot edge-under

echo "== a hand at rest is never quite still"
mark
send "glide 960 1079 975 1078 6 80" "glide 975 1078 950 1079 6 80" "sleep 900"
sleep 2.0
check "trembling at the edge, it stays" "$(flips)$(state)" "0false"

echo "== up from the edge onto the glass"
mark
send "glide 960 1079 960 1040 8 20" "sleep 1500"
sleep 2.0
check "from the strip to the glass, it stays" "$(flips)$(state)" "0false"

echo "== back down and along the edge, past the end of the dock"
mark
send "glide 960 1040 960 1079 8 20" "glide 960 1079 120 1079 20 20" "sleep 1500"
sleep 2.3
check "along the edge, it stays" "$(flips)$(state)" "0false"

echo "== away"
mark
send "glide 120 1079 700 500 10 15" "sleep 1500"
sleep 2.0
check "it hides, once" "$(flips)$(state)" "1true"
shot away

echo "== back to the edge to the side of the dock"
mark
send "glide 700 500 300 1079 10 15" "sleep 2000"
sleep 2.4
check "the edge anywhere along it brings it back, once" "$(flips)$(state)" "1false"

input_stop
dock_errors
