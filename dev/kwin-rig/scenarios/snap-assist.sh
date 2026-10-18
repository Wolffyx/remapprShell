# Snap Assist (kwin/snap/contents/ui/Picker.qml), dragged and clicked for real:
#   dev/kwin-rig/run.sh scenarios/snap-assist.sh
#
# The panel's zones, on a 1920x1080 screen, are where snap.sh says: halves
# at (826, 35) and (874, 35), thirds at (1046, 35), (1078, 35) and
# (1110, 35). The quarters card is the middle of the second row, its two
# left-hand zones at (936, 87) and (936, 115) -- reached from the top, since
# the panel opens only near it.
#
# Snap Assist lays the windows it offers out with layouts.js's `grid` and
# Picker.qml's metrics: cells at most 300 wide, a 16:10 picture over a 28 px
# title, 18 apart and 28 in from the zone. In a zone the screen's height,
# 960 or 640 wide, two windows are a column of two 300x216 cells centred at
# y 423 and 657; in the bottom-left quarter, at y 693 and 927. What the
# scenario checks is where KWin put each window.

window a 900 600 steelblue
window b 700 500 seagreen
window c 600 400 indianred
load kwin/snap
input_start

fields() { geom "$1" | cut -d' ' -f1-4; }

echo "== snapped into a half, the other windows are offered for the other"
drag a 826 35
shot assist-halves
check "a: the left half" "$(tile a)" "0,0,960,1080"
click 1440 423
check "the first offered, the window on top: c, into the right half" "$(tile c)" "960,0,960,1080"
check "b is left alone" "$(tile b)" "none"
click 1440 657
check "the layout is full, so nothing is offered after it" "$(tile b)" "none"

echo "== Escape puts it away, and moves nothing"
activate b
drag b 1046 35
shot assist-thirds
check "b: the first third" "$(tile b)" "0,0,640,1080"
a_was=$(fields a) c_was=$(fields c)
send "key 1" "sleep 300"
sleep 0.6
check "a is out of its tile, as another layout leaves it" "$(tile a)" "none"
check "and where it was" "$(fields a)" "$a_was"
check "c too" "$(tile c):$(fields c)" "none:$c_was"

echo "== the keys choose, and it goes on to the next empty zone"
drag b 1046 35
send "key 108" "sleep 150" "key 28" "sleep 400"
sleep 0.8
shot assist-next
check "Down, Enter: the second offered, a, into the second third" "$(tile a)" "640,0,640,1080"
send "key 28" "sleep 400"
sleep 0.8
check "Enter again: the last one, c, into the last third" "$(tile c)" "1280,0,640,1080"
check "and b where it was put" "$(tile b)" "0,0,640,1080"

echo "== a click anywhere else puts it away"
activate a
drag a 936 30 "glide 936 30 936 87 5 10" "sleep 150"
check "a: the top-left quarter" "$(tile a)" "0,0,960,540"
b_was=$(fields b) c_was=$(fields c)
click 1440 270
click 480 693
check "nothing was put in the bottom-left quarter" "$(tile b):$(tile c)" "none:none"
check "and neither window moved" "$(fields b):$(fields c)" "$b_was:$c_was"

echo "== switched off, a snap offers nothing"
load kwin/snap Assist=false
activate c
drag c 826 35
check "c: the left half" "$(tile c)" "0,0,960,1080"
send "key 28" "sleep 400"
sleep 0.8
check "and Enter places nobody" "$(tile a):$(tile b)" "none:none"

input_stop
