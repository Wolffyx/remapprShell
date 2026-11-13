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
# DOCK_FROM=<rev> runs the dock's files as they were at that commit instead,
# to see a fault before the fix that cured it.

QS=$RUN/qs
cp -r "$REPO_ROOT/shell/." "$QS/"
if [ -n "${DOCK_FROM:-}" ]; then
    for f in features/dock/Dock.qml features/dock/DockBody.qml features/dock/DockMenu.qml domain/dock/DockItems.qml; do
        git -C "$REPO_ROOT" show "$DOCK_FROM:shell/$f" > "$QS/$f"
    done
fi
# The schema and the defaults from this tree, not the installed ones.
sed -i "s|\${Paths.dataDir}/config/schema|$REPO_ROOT/config/schema|" "$QS/domain/config/Schema.qml"
sed -i "s|\${root.dataDir}/config/defaults|$REPO_ROOT/config/defaults|" "$QS/core/Paths.qml"
sed -i '0,/^    id: root$/s//    id: root\
    Component.onCompleted: console.warn(`DOCK hidden=${root.hidden}`)\
    onHiddenChanged: console.warn(`DOCK hidden=${root.hidden}`)/' "$QS/features/dock/Dock.qml"
cat > "$QS/shell.qml" <<'QML'
import QtQuick
import Quickshell
import qs.features.dock

ShellRoot {
    Variants {
        model: Quickshell.screens
        Dock {}
    }
}
QML
profile=$XDG_CONFIG_HOME/$SLUG/profiles/default
mkdir -p "$profile"
printf '{ "dock": { "enabled": true, "position": "bottom", "visibility": "autohide", "magnify": false } }\n' > "$profile/shell.json"

input_start
send "move 960 400" "sleep 100"
QT_QUICK_BACKEND=software quickshell -p "$QS" > "$RUN/qs.log" 2>&1 &
# The dock first speaks before the profile is read, as `always` (hidden=false);
# hidden=true is the profile's autohide. Then a moment for the surface to
# settle before the pointer moves.
for _ in $(seq 75); do grep -qa "DOCK hidden=true" "$RUN/qs.log" && break; sleep 0.2; done
sleep 1.5

# The dock's last word, and how many times it has spoken since `mark`.
state() { grep -a "DOCK hidden=" "$RUN/qs.log" | tail -1 | sed 's/.*DOCK hidden=//'; }
mark() { MARK=$(grep -ac "DOCK hidden=" "$RUN/qs.log"); }
flips() { echo $(( $(grep -ac "DOCK hidden=" "$RUN/qs.log") - MARK )); }

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
if grep -a -E 'TypeError|ReferenceError|is not a function|failed to load' "$RUN/qs.log" >/dev/null; then
    echo "  quickshell's log has errors:"
    grep -a -E 'TypeError|ReferenceError|is not a function|failed to load' "$RUN/qs.log" | head -5 | sed 's/^/    /'
    failed=$((failed + 1))
fi
echo "  quickshell's log: ${RUN#"$REPO_ROOT"/}/qs.log"
