#!/usr/bin/env bash
# Screen edges and corners.
#
#   status                 what every edge and corner currently does
#   set <edge> <action>    bind a corner or edge to a built-in action
#   effect <name> <edge>   bind a KWin effect to an edge (overview, windowview, ...)
#   snap on|off            Aero-Snap style edge tiling and maximise
#   disable-all            neutralise every mouse trigger
#   revert                 undo everything this project set
#
# KWin already implements all of this. Nothing here reimplements an edge
# trigger; it configures the ones KWin has and records the previous value so
# every change can be undone. That is the whole difference between a shell that
# co-operates with the desktop and one that fights it.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/kconfig.sh"

# KWin's ElectricBorder enum. 9 is ElectricNone -- a binding set to 9 is off,
# which is why an edge can read as "configured" and still do nothing.
EDGE_NAMES=(Top TopRight Right BottomRight Bottom BottomLeft Left TopLeft)
edge_index() {
    local want=$1 i
    for i in "${!EDGE_NAMES[@]}"; do
        [ "${EDGE_NAMES[$i]}" = "$want" ] && { printf '%s' "$i"; return 0; }
    done
    return 1
}
edge_name() {
    local n=$1
    [ "$n" = 9 ] && { printf 'none'; return; }
    printf '%s' "${EDGE_NAMES[$n]:-?}"
}

# Actions KWin accepts in [ElectricBorders].
VALID_ACTIONS=(None showdesktop lockscreen krunner applicationlauncher activitymanager)

# Effects that can be triggered from an edge. The first is the task view --
# what Meta+Tab shows on Windows.
EFFECTS=(overview windowview desktopgrid)

reconfigure() {
    qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 \
      || busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure >/dev/null 2>&1 \
      || log_warn "could not ask KWin to reload; changes apply at next login"
}

cmd=${1:-status}
[ $# -gt 0 ] && shift

case "$cmd" in
    status)
        echo "corners and edges:"
        for e in "${EDGE_NAMES[@]}"; do
            printf '  %-12s %s\n' "$e" "$(kreadconfig6 --file kwinrc --group ElectricBorders --key "$e" --default 'None (default)')"
        done
        echo
        echo "effects bound to an edge:"
        for fx in "${EFFECTS[@]}"; do
            v=$(kreadconfig6 --file kwinrc --group "Effect-$fx" --key BorderActivate --default 9)
            printf '  %-12s %s\n' "$fx" "$(edge_name "$v")"
        done
        echo
        echo "window snapping:"
        printf '  %-12s %s\n' "tiling"   "$(kreadconfig6 --file kwinrc --group Windows --key ElectricBorderTiling --default 'true (default)')"
        printf '  %-12s %s\n' "maximise" "$(kreadconfig6 --file kwinrc --group Windows --key ElectricBorderMaximize --default 'true (default)')"
        echo
        echo "ledger (what revert would undo):"
        kconfig_ledger_summary edges
        ;;

    set)
        edge=${1:?usage: $ALIAS edges set <Edge> <action>}
        action=${2:?usage: $ALIAS edges set <Edge> <action>}
        edge_index "$edge" >/dev/null || die "unknown edge '$edge' (one of: ${EDGE_NAMES[*]})"
        printf '%s\n' "${VALID_ACTIONS[@]}" | grep -qxF "$action" \
            || die "unknown action '$action' (one of: ${VALID_ACTIONS[*]})"
        kconfig_set edges kwinrc ElectricBorders "$edge" "$action"
        reconfigure
        log_step "$edge -> $action"
        ;;

    effect)
        fx=${1:?usage: $ALIAS edges effect <name> <Edge|none>}
        edge=${2:?usage: $ALIAS edges effect <name> <Edge|none>}
        printf '%s\n' "${EFFECTS[@]}" | grep -qxF "$fx" || die "unknown effect '$fx' (one of: ${EFFECTS[*]})"
        if [ "$edge" = none ]; then
            idx=9
        else
            idx=$(edge_index "$edge") || die "unknown edge '$edge' (one of: ${EDGE_NAMES[*]}, or none)"
        fi
        kconfig_set edges kwinrc "Effect-$fx" BorderActivate "$idx"
        reconfigure
        log_step "$fx -> $(edge_name "$idx")"
        ;;

    snap)
        state=${1:?usage: $ALIAS edges snap on|off}
        case "$state" in
            on)  v=true ;;
            off) v=false ;;
            *) die "expected on or off" ;;
        esac
        kconfig_set edges kwinrc Windows ElectricBorderTiling "$v"
        kconfig_set edges kwinrc Windows ElectricBorderMaximize "$v"
        reconfigure
        log_step "window snapping $state"
        ;;

    disable-all)
        # The master switch. Everything it turns off is recorded first, so
        # turning it back on is `revert` and restores exactly what was there --
        # including edges the user had configured themselves.
        for e in "${EDGE_NAMES[@]}"; do
            kconfig_set edges kwinrc ElectricBorders "$e" None
        done
        for fx in "${EFFECTS[@]}"; do
            kconfig_set edges kwinrc "Effect-$fx" BorderActivate 9
        done
        kconfig_set edges kwinrc Windows ElectricBorderTiling false
        kconfig_set edges kwinrc Windows ElectricBorderMaximize false
        reconfigure
        log_step "all mouse edge triggers disabled"
        log_info "restore them with: $ALIAS edges revert"
        ;;

    revert)
        kconfig_revert edges
        reconfigure
        ;;

    *) die "unknown command: $cmd" ;;
esac
