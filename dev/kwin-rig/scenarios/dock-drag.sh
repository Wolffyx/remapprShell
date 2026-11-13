# Dragging the dock's tiles, in a KWin of its own, with nothing of the real
# desktop touched:
#   dev/kwin-rig/run.sh scenarios/dock-drag.sh
#
# The real Dock.qml in a quickshell inside the rig (dev/kwin-rig/dock.sh),
# holding three applications and nothing else -- no start button, no places,
# nothing running -- and the fake pointer dragging them: a little way up and
# back (nothing changes), off and back again (nothing), along by one (the
# order changes, `dock.rearrange`), and up off the dock (it is taken out,
# `dock.dragToRemove`). Then with dragToRemove off, up off it again: it stays.
# What the dock keeps is read from what it says ("DOCK pinned=...").
#
# At 1920x1080 and 48 px tiles 6 px apart, three tiles have their centres at
# x 906, 960 and 1014, two at 933 and 987; y 1039 is the middle of the glass.

source "$RIG/dock.sh"
input_start
send "move 960 400" "sleep 100"
dock_start '{ "dock": { "enabled": true, "position": "bottom", "visibility": "always", "magnify": false,
  "launcher": false, "places": false, "running": false,
  "pinned": ["org.kde.dolphin", "org.kde.konsole", "org.kde.kate"] } }'
dock_wait 'pinned=["org.kde.dolphin"' 15
sleep 1.5

# Press at x1 y1, carry it through each "x y" given, let go at the last.
carry() {
    local x=$1 y=$2 cmds=() px py
    shift 2
    px=$x py=$y
    cmds+=("move $x $y" "sleep 80" "down" "sleep 80")
    while [ $# -ge 2 ]; do
        cmds+=("glide $px $py $1 $2 12 15" "sleep 120")
        px=$1 py=$2
        shift 2
    done
    send "${cmds[@]}" "up" "sleep 400"
    sleep $(( 2 + ${#cmds[@]} / 6 ))
}

kept() { dock_said pinned; }

echo "== to start with"
check "three kept" "$(kept)" '["org.kde.dolphin","org.kde.konsole","org.kde.kate"]'

echo "== a little way up, and let go"
carry 960 1039 960 1009
check "30 px off the glass takes nothing out" "$(kept)" '["org.kde.dolphin","org.kde.konsole","org.kde.kate"]'

echo "== off and back again"
carry 960 1039 960 900 960 1036
check "brought back before letting go, it stays" "$(kept)" '["org.kde.dolphin","org.kde.konsole","org.kde.kate"]'

echo "== along by one"
carry 960 1039 1014 1039
check "Konsole after Kate" "$(kept)" '["org.kde.dolphin","org.kde.kate","org.kde.konsole"]'

echo "== up off the dock"
send "move 1014 1039" "sleep 80" "down" "sleep 80" "glide 1014 1039 1014 880 12 15"
sleep 1.2
shot pulled-off
send "up" "sleep 400"
sleep 1.2
check "let go off the dock, Konsole is taken out" "$(kept)" '["org.kde.dolphin","org.kde.kate"]'

echo "== with dock.dragToRemove off"
before=$(dock_count pinned)
printf '%s\n' '{ "dock": { "enabled": true, "position": "bottom", "visibility": "always", "magnify": false,
  "launcher": false, "places": false, "running": false, "dragToRemove": false,
  "pinned": ["org.kde.kate", "org.kde.dolphin"] } }' > "$XDG_CONFIG_HOME/$SLUG/profiles/default/shell.json"
for _ in $(seq 25); do [ "$(dock_count pinned)" -gt "$before" ] && break; sleep 0.2; done
sleep 1
check "the profile is read again" "$(kept)" '["org.kde.kate","org.kde.dolphin"]'
carry 933 1039 933 880
check "up off the dock, Kate stays" "$(kept)" '["org.kde.kate","org.kde.dolphin"]'
carry 933 1039 987 1039
check "and is still dragged along it" "$(kept)" '["org.kde.dolphin","org.kde.kate"]'

input_stop
dock_errors
