# What opens the snap layouts panel during a drag (kwin/snap main.qml
# `wantsPanel`): the pointer within snapApproach px of the top of the
# screen, kept there for snapDelay ms -- 24 and 250 unless set:
#   dev/kwin-rig/run.sh scenarios/snap-trigger.sh
#
# A window let go over a zone is snapped only if the panel was open, so
# where it lands says whether it opened. The zones are where snap.sh says:
# halves at (826, 35) and (874, 35), thirds at (1046, 35). Each drag comes up
# from 200 px below the zone, goes to the trigger height, and then to the
# zone -- which, at 35 px, is outside a 24 px approach: the panel open stays
# open there, a panel shut does not open there. A drag let go where it was
# pressed has not moved the window and snaps nothing, so each drag of the
# same window holds it somewhere else along its title bar (GRAB).

window a 900 600 steelblue
window b 700 500 seagreen
load kwin/snap Assist=false
input_start

# <title> <x> <trigger y> <ms at the trigger> <ms over the zone>
reach() {
    local tx ty
    read -r tx ty <<< "$(titlebar "$1")"
    send "move $tx $ty" "sleep 60" "down" "sleep 60" "glide $tx $ty $2 200 10 10" \
         "glide $2 200 $2 $3 4 10" "sleep $4" "glide $2 $3 $2 35 3 10" "sleep $5" "up" "sleep 400"
    sleep 1.4
}

echo "== the defaults: 24 px, 250 ms"
check "read from nothing set" "$(kreadconfig6 --file kwinrc --group "Script-$SLUG-snap" --key Delay --default unset)" "unset"
reach a 826 10 0 60
check "a fast pass over the top opens nothing" "$(tile a)" "none"
GRAB=40 reach a 826 10 50 300
check "nor 50 ms at the top, though it waits over the zone after" "$(tile a)" "none"
GRAB=30 reach a 826 10 400 150
check "400 ms at the top opens it: a, the left half" "$(tile a)" "0,0,960,1080"

echo "== the approach"
GRAB=70 reach b 874 40 600 150
check "40 px from the top, however long, opens nothing" "$(tile b)" "none"
GRAB=60 reach b 874 20 400 150
check "20 px does: b, the right half" "$(tile b)" "960,0,960,1080"

echo "== set through the CLI: 60 px, no wait"
"$REPO_ROOT/scripts/windows.sh" behaviour set snapApproach 60 >/dev/null 2>&1
"$REPO_ROOT/scripts/windows.sh" behaviour set snapDelay 0 >/dev/null 2>&1
sleep 0.8
check "written to the script's group" \
    "$(kreadconfig6 --file kwinrc --group "Script-$SLUG-snap" --key Approach),$(kreadconfig6 --file kwinrc --group "Script-$SLUG-snap" --key Delay)" "60,0"
reach a 1046 55 0 60
check "a fast pass 55 px down opens it now: a, the first third" "$(tile a)" "0,0,640,1080"

input_stop
