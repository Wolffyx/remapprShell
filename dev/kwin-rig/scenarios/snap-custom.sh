# rig: global-shortcuts
#
# Snap layouts of the user's own (kwin/snap, layouts.js `custom`), saved
# through the real CLI -- `windows snap layouts save`, which writes the
# script's group and reloads it -- and dragged into:
#   dev/kwin-rig/run.sh scenarios/snap-custom.sh
#
# Three are saved: one for tall screens only, first, so that if it were
# shown on this wide one it would take the seventh card; then "Sides", zones
# as narrow as the editor draws them (0.155 of the screen, 298 px here --
# KWin makes none of 0.15) either side of the rest; then "Main", 0.6 beside
# a stack of two. With eight cards the
# panel is two rows of four (layouts.js `arrange`): 442 px wide, centred, so
# card i is at x = 747 + (i % 4) * 110, y = 8 + floor(i / 4) * 66, 96x54.
# Sides is card 6 (967, 74): its zones are centred at x 974, 1015 and
# 1056, y 101. Main is card 7 (1077, 74): its main zone at (1106, 101), the
# stack's at (1154, 87) and (1154, 114). Linux key codes: "8" 9, "3" 4.

window a 900 600 steelblue
window b 700 500 seagreen
# Opened as it was before snapApproach and snapDelay (72 px, no wait): the
# drags here go straight to a card. snap-trigger.sh has the trigger itself.
load kwin/snap Assist=false Approach=72 Delay=0
input_start

layouts() { "$REPO_ROOT/scripts/windows.sh" snap layouts "$@" >/dev/null 2>&1; sleep 0.4; }
pick() { "$REPO_ROOT/scripts/windows.sh" snap pick; sleep 0.8; }
# The second row is below where the panel opens (within 72 px of the top):
# up to the first row, then down to it, as a hand would.
lower() {   # <title> <x> <y> [cmd...]
    local title=$1 x=$2 y=$3
    shift 3
    drag "$title" "$x" 35 "glide $x 35 $x $y 6 10" "sleep 200" "$@"
}
group() { kreadconfig6 --file kwinrc --group "Script-$SLUG-snap" --key Layouts; }

echo "== saved through the CLI"
layouts save Tall '{"dir":"v","parts":[0.5,0.5]}' tall
layouts save Sides '{"dir":"h","parts":[0.155,0.69,0.155]}'
layouts save Main '{"dir":"h","parts":[0.6,{"size":0.4,"dir":"v","parts":[0.5,0.5]}]}'
check "three, in the script's group" "$(group | jq -r 'map(.name) | join(" ")')" "Tall Sides Main"
check "a zone of 0.15 is refused" \
    "$("$REPO_ROOT/scripts/windows.sh" snap layouts save Thin '{"dir":"h","parts":[0.15,0.85]}' >/dev/null 2>&1; echo $?)" "1"
check "and the script is loaded again" "$(qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.isScriptLoaded "$SLUG-snap")" "true"

echo "== the panel, held open over Sides' first zone, and let go with Escape"
read -r tx ty <<< "$(titlebar a)"
send "move $tx $ty" "sleep 60" "down" "sleep 60" "glide $tx $ty 974 235 10 10" "glide 974 235 974 35 10 10" \
     "glide 974 35 974 101 6 10" "sleep 300"
sleep 1.2
shot custom-panel
send "key 1" "sleep 150" "up" "sleep 300"
sleep 0.8
check "nothing snapped" "$(tile a)" "none"

echo "== the narrowest zones the editor draws"
lower a 974 101
check "a: the left side, 0.155 of the screen" "$(tile a)" "0,0,298,1080"
GRAB=70 lower b 1056 101
check "b: the right side" "$(tile b)" "1622,0,298,1080"
check "and a keeps its own" "$(tile a)" "0,0,298,1080"
GRAB=70 lower b 1015 101
check "b: the middle, between them" "$(tile b)" "298,0,1325,1080"

echo "== a layout with a stack"
GRAB=30 lower a 1154 87
shot custom-main
check "a: the top of the stack" "$(tile a)" "1152,0,768,540"
check "b, in another layout, is let go" "$(tile b)" "none"

echo "== by its number, from the keys"
activate b
pick
send "key 9" "sleep 150"
shot custom-numbered
send "key 4" "sleep 400"
sleep 0.8
check "8 and 3: b, the bottom of Main's stack" "$(tile b)" "1152,540,768,540"
check "and a keeps the top" "$(tile a)" "1152,0,768,540"

echo "== removed, it is gone from the panel"
layouts remove Sides
check "two left" "$(group | jq -r 'map(.name) | join(" ")')" "Tall Main"
# Seven cards, still four across: Main is card 6 now, where Sides was, its
# main zone 0..58 of the card -- centred at x 996.
GRAB=50 lower a 996 101
check "Main took the seventh card: a, its main zone" "$(tile a)" "0,0,1152,1080"

input_stop
