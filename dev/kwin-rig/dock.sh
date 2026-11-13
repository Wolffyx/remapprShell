# The shell's dock on its own, for the dock's scenarios to source inside the
# rig (scenarios/dock-*.sh):
#
#   dock_start '<profile json>'   copy this tree's shell into the run, give it
#                                 that profile, and start a quickshell with
#                                 the real Dock.qml on every screen and
#                                 nothing else of the shell
#   dock_said <what>              the dock's last word on <what>: "hidden"
#                                 (true or false), "pinned" (the list kept
#                                 in it, as JSON) or "menu" (the application
#                                 whose menu is open, empty for none)
#   dock_count <what>             how many times it has spoken of <what>
#
# The copy speaks into $RUN/qs.log -- "DOCK hidden=..." whenever it hides or
# shows, "DOCK pinned=..." whenever the list it keeps changes, "DOCK menu=..."
# whenever its menu opens or closes. The schema and
# the defaults are this tree's, not the installed ones.
#
# DOCK_FROM=<rev> runs the dock's files as they were at that commit instead,
# to see a fault before the fix that cured it.

dock_start() {
    local qs=$RUN/qs profile=$XDG_CONFIG_HOME/$SLUG/profiles/default f
    cp -r "$REPO_ROOT/shell/." "$qs/"
    if [ -n "${DOCK_FROM:-}" ]; then
        for f in features/dock/Dock.qml features/dock/DockBody.qml features/dock/DockMenu.qml domain/dock/DockItems.qml; do
            git -C "$REPO_ROOT" show "$DOCK_FROM:shell/$f" > "$qs/$f"
        done
    fi
    sed -i "s|\${Paths.dataDir}/config/schema|$REPO_ROOT/config/schema|" "$qs/domain/config/Schema.qml"
    sed -i "s|\${root.dataDir}/config/defaults|$REPO_ROOT/config/defaults|" "$qs/core/Paths.qml"
    sed -i '0,/^    id: root$/s//    id: root\
    Component.onCompleted: console.warn(`DOCK hidden=${root.hidden}`)\
    onHiddenChanged: console.warn(`DOCK hidden=${root.hidden}`)\
    onConfiguredPinsChanged: console.warn(`DOCK pinned=${JSON.stringify(root.configuredPins)}`)\
    onMenuItemChanged: console.warn(`DOCK menu=${root.menuItem ? root.menuItem.appKey : ""}`)/' \
        "$qs/features/dock/Dock.qml"
    cat > "$qs/shell.qml" <<'QML'
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
    mkdir -p "$profile"
    printf '%s\n' "$1" > "$profile/shell.json"
    QT_QUICK_BACKEND=software quickshell -p "$qs" > "$RUN/qs.log" 2>&1 &
}

dock_said() { grep -a "DOCK $1=" "$RUN/qs.log" | tail -1 | sed "s/.*DOCK $1=//"; }
dock_count() { grep -ac "DOCK $1=" "$RUN/qs.log"; }

# Waits up to `seconds` for the dock to say `<what>=<value>`.
dock_wait() {   # <what>=<value> <seconds>
    local _
    for _ in $(seq $(( ${2:-15} * 5 ))); do grep -qaF "DOCK $1" "$RUN/qs.log" && return 0; sleep 0.2; done
    return 1
}

dock_errors() {
    if grep -a -E 'TypeError|ReferenceError|is not a function|failed to load' "$RUN/qs.log" >/dev/null; then
        echo "  quickshell's log has errors:"
        grep -a -E 'TypeError|ReferenceError|is not a function|failed to load' "$RUN/qs.log" | head -5 | sed 's/^/    /'
        failed=$((failed + 1))
    fi
    echo "  quickshell's log: ${RUN#"$REPO_ROOT"/}/qs.log"
}
