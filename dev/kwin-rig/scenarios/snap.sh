# Snap layouts (kwin/snap), dragged for real: dev/kwin-rig/run.sh scenarios/snap.sh
#
# The panel hangs from the top of a 1920x1080 screen, centred, with the
# cards from layouts.js's `arrange`: two rows of three, 96x54 each, 14 apart
# across and 12 down, 8 in from the panel's edge. So, in the screen's pixels,
# the halves card's zones are centred at (826, 35) and (874, 35), and the
# thirds card's at (1046, 35), (1078, 35) and (1110, 35). The scenario
# measures nothing else: what it checks is where KWin put each window.
#
# The window list (kwin/windows) is loaded too, reporting to a stand-in
# daemon, because the panel is a window inside KWin and was once listed on
# the taskbar for as long as a drag lasted.

window left 900 600 steelblue
window right 700 500 seagreen
windows_stub
load kwin/windows
# Snap Assist off: it would offer `right` once `left` is snapped, and its
# window would take the press that starts the next drag. It has a scenario
# of its own, snap-assist.sh.
load kwin/snap Assist=false
input_start

echo "== the panel is no window of the taskbar's"
read -r tx ty <<< "$(titlebar left)"
send "move $tx $ty" "sleep 60" "down" "sleep 60" "glide $tx $ty 960 235 10 10" "glide 960 235 960 35 10 10" "sleep 300"
sleep 1.2
shot snap-panel
check "the panel is up" "$(kwin_windows)" "1"
check "mid-drag, the taskbar has the two windows only" "$(taskbar)" "left right"
send "key 1" "sleep 150" "up" "sleep 300"
sleep 0.8

echo "== snapping into a layout"
drag left 826 35
shot snap-left
check "left half: in KWin's tile" "$(geom left | cut -d' ' -f5)" "0,0,960,1080"

GRAB=85 drag right 874 35
check "right half: the same layout, a second tile" "$(geom right | cut -d' ' -f5)" "960,0,960,1080"
check "and the first window keeps its tile" "$(geom left | cut -d' ' -f5)" "0,0,960,1080"

echo "== another layout lets the others go"
GRAB=85 drag right 1046 35
check "into the first third" "$(geom right | cut -d' ' -f5)" "0,0,640,1080"
check "the left window is out of its tile" "$(geom left | cut -d' ' -f5)" "none"
check "and still where it was" "$(geom left | cut -d' ' -f3)" "954"

echo "== dragged out, a window gets its size back"
read -r x y _ <<< "$(geom right)"
send "move $((x + 300)) $((y + 12))" "sleep 60" "down" "sleep 60" "glide $((x + 300)) $((y + 12)) 1300 600 20 10" "sleep 150" "up" "sleep 400"
sleep 1.6
check "out of the tile" "$(geom right | cut -d' ' -f5)" "none"
check "at its own size" "$(geom right | cut -d' ' -f3-4)" "700 528"

echo "== Escape over a zone snaps nothing"
before=$(geom right)
GRAB=50 drag right 1078 35 "key 1" "sleep 150"
check "the window is back where it was" "$(geom right)" "$before"

echo "== the panel, open over a zone"
read -r tx ty <<< "$(titlebar right)"
send "move $tx $ty" "sleep 60" "down" "sleep 60" "glide $tx $ty 1078 235 10 10" "glide 1078 235 1078 35 10 10"
sleep 1
shot snap-open
check "a sixth drag still opens the panel" "$(kwin_windows)" "1"
send "key 1" "sleep 100" "up"
sleep 0.5

input_stop
