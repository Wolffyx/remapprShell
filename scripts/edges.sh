#!/usr/bin/env bash
# Screen edges and corners.
#
#   status [--json]        what every edge and corner does, and whether
#                          mouse triggers are on
#   actions                what an edge can be set to
#   set <edge> <action>    bind a corner or edge to one action
#   effect <name> <edge|none>
#                          the same as `set <edge> <name>`; with `none`, take
#                          that effect off every edge
#   snap on|off            Aero-Snap style edge tiling and maximise
#   disable-all            the master switch: every mouse trigger off
#   enable-all             ...and back on, exactly as they were
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
source "$REPO_ROOT/scripts/lib/kwin.sh"

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

# Everything an edge can do: id | where KWin keeps it | what to call it.
#
# Two kinds. A `border` action is the corner's own value in
# [ElectricBorders]. An effect instead keeps a *list* of edges in its own
# group, `Effect-<name>:<key>`, so one effect can sit on several corners and
# a corner's action is whichever of the two places names it.
#
# The keys were read out of KWin 6.7's own effect configuration modules, not
# remembered. KWin 6.1 folded the desktop grid into the overview: the grid is
# `GridBorderActivate` there, and an `Effect-desktopgrid` key -- which this
# file used to write -- is read by nothing at all.
ACTIONS=(
    "none||Nothing"
    "showdesktop|border|Show the desktop"
    "overview|Effect-overview:BorderActivate|Overview"
    "grid|Effect-overview:GridBorderActivate|Grid of desktops"
    "windowview|Effect-windowview:BorderActivate|Windows on this desktop"
    "windowview-all|Effect-windowview:BorderActivateAll|Windows on every desktop"
    "windowview-class|Effect-windowview:BorderActivateClass|Windows of this application"
    "krunner|border|Search"
    "applicationlauncher|border|Plasma's application launcher"
    "activitymanager|border|Activities"
    "lockscreen|border|Lock the screen"
)

action_field() {   # <id> <2 = store, 3 = label>
    local a
    for a in "${ACTIONS[@]}"; do
        [ "${a%%|*}" = "$1" ] && { cut -d'|' -f"$2" <<< "$a"; return 0; }
    done
    return 1
}
action_ids() { local a; for a in "${ACTIONS[@]}"; do printf '%s\n' "${a%%|*}"; done; }
effect_stores() { local a; for a in "${ACTIONS[@]}"; do cut -d'|' -f2 <<< "$a"; done | grep ':' | sort -u; }

# The edges an effect is bound to, one index per line, 9 and junk dropped.
effect_list() {
    local store=$1
    kreadconfig6 --file kwinrc --group "${store%%:*}" --key "${store#*:}" --default 9 \
      | tr ',' '\n' | grep -xE '[0-7]' | sort -n | uniq
}
joined() { local j; j=$(grep . | paste -sd,); printf '%s' "${j:-9}"; }

# What one edge does. The corner's own action wins over an effect on the same
# edge, as it does in KWin, where the border action is reserved first.
edge_action() {
    local edge=$1 idx cur store
    idx=$(edge_index "$edge")
    cur=$(kreadconfig6 --file kwinrc --group ElectricBorders --key "$edge" --default None)
    cur=${cur,,}
    if [ -n "$cur" ] && [ "$cur" != none ]; then
        printf '%s' "$cur"
        return
    fi
    while IFS= read -r store; do
        if effect_list "$store" | grep -qxF "$idx"; then
            action_for_store "$store"
            return
        fi
    done < <(effect_stores)
    printf 'none'
}
action_for_store() { local a; for a in "${ACTIONS[@]}"; do [ "$(cut -d'|' -f2 <<< "$a")" = "$1" ] && { printf '%s' "${a%%|*}"; return; }; done; }

# The master switch is off exactly while its own ledger scope holds records:
# turning it back on is reverting that scope, so there is no second copy of
# the state to fall out of step with.
triggers_off() {
    local led
    led=$(kconfig_ledger)
    [ -s "$led" ] && jq -e '[.entries[] | select(.scope == "edges-off")] | length > 0' "$led" >/dev/null 2>&1
}

# A corner set while the switch is off would be overwritten by turning it back
# on, which puts back what was there before the switch. Refused, rather than
# silently lost.
require_triggers_on() {
    triggers_off && die "mouse triggers at the screen edges are switched off; turn them back on first: $ALIAS edges enable-all"
    return 0
}

snap_key() { kreadconfig6 --file kwinrc --group Windows --key "$1" --default true; }

reconfigure() {
    session_available || return 0
    qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 \
      || busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure >/dev/null 2>&1 \
      || log_warn "could not ask KWin to reload; changes apply at next login"
}

# set_edge <Edge> <action>
#
# The edge ends up in exactly one place: the corner's own value, or the list
# of the one effect chosen, and out of every other list. Only keys whose value
# actually changes are written, so the ledger records nothing we did not need
# to touch.
set_edge() {
    local edge=$1 action=$2 idx store want cur s old new
    idx=$(edge_index "$edge") || die "unknown edge '$edge' (one of: ${EDGE_NAMES[*]})"
    store=$(action_field "$action" 2) || die "unknown action '$action' (one of: $(action_ids | tr '\n' ' '))"

    want=None
    [ "$store" = border ] && want=$action
    cur=$(kreadconfig6 --file kwinrc --group ElectricBorders --key "$edge" --default None)
    [ "${cur,,}" = "${want,,}" ] || kconfig_set edges kwinrc ElectricBorders "$edge" "$want"

    while IFS= read -r s; do
        old=$(effect_list "$s" | joined)
        if [ "$s" = "$store" ]; then
            new=$({ effect_list "$s"; printf '%s\n' "$idx"; } | sort -n | uniq | joined)
        else
            new=$(effect_list "$s" | grep -vxF "$idx" | joined)
        fi
        [ "$new" = "$old" ] || kconfig_set edges kwinrc "${s%%:*}" "${s#*:}" "$new"
    done < <(effect_stores)
}

status_json() {
    local e rows=""
    for e in "${EDGE_NAMES[@]}"; do
        rows+="$e"$'\t'"$(edge_action "$e")"$'\n'
    done
    local customised=false led
    led=$(kconfig_ledger)
    [ -s "$led" ] && jq -e '[.entries[] | select(.scope == "edges" or .scope == "edges-off")] | length > 0' "$led" >/dev/null 2>&1 \
        && customised=true

    local actions
    actions=$(for a in "${ACTIONS[@]}"; do printf '%s\t%s\n' "${a%%|*}" "$(cut -d'|' -f3 <<< "$a")"; done \
        | jq -R -s -c 'split("\n") | map(select(length > 0) | split("\t") | {id: .[0], label: .[1]})')

    printf '%s' "$rows" | jq -R -s -c \
        --argjson triggers "$(triggers_off && echo false || echo true)" \
        --argjson tiling "$([ "$(snap_key ElectricBorderTiling)" = true ] && echo true || echo false)" \
        --argjson maximize "$([ "$(snap_key ElectricBorderMaximize)" = true ] && echo true || echo false)" \
        --argjson customised "$customised" \
        --argjson actions "$actions" \
        --arg scripts "$(kwin_tiling_scripts)" \
        '{
            triggers: $triggers,
            edges: (split("\n") | map(select(length > 0) | split("\t") | {key: .[0], value: .[1]}) | from_entries),
            snap: {tiling: $tiling, maximize: $maximize},
            tilingScripts: ($scripts | split("\n") | map(select(length > 0))),
            customised: $customised,
            actions: $actions
        }'
}

cmd=${1:-status}
[ $# -gt 0 ] && shift

case "$cmd" in
    status)
        if [ "${1:-}" = "--json" ]; then
            status_json
            echo
            exit 0
        fi
        printf 'mouse triggers: %s\n\n' "$(triggers_off && echo "off  ($ALIAS edges enable-all puts them back)" || echo on)"
        echo "corners and edges:"
        for e in "${EDGE_NAMES[@]}"; do
            a=$(edge_action "$e")
            printf '  %-12s %s\n' "$e" "$(action_field "$a" 3 || printf '%s (not one of ours)' "$a")"
        done
        echo
        echo "window snapping:"
        printf '  %-12s %s\n' "tiling"   "$(snap_key ElectricBorderTiling)"
        printf '  %-12s %s\n' "maximise" "$(snap_key ElectricBorderMaximize)"
        scripts=$(kwin_tiling_scripts | tr '\n' ' ')
        [ -n "$scripts" ] && printf '  %-12s %s-- dragging to an edge may go to it instead\n' "tiling script" "$scripts"
        echo
        echo "ledger (what revert would undo):"
        kconfig_ledger_summary edges
        kconfig_ledger_summary edges-off
        ;;

    actions)
        for a in "${ACTIONS[@]}"; do
            printf '%-20s %s\n' "${a%%|*}" "$(cut -d'|' -f3 <<< "$a")"
        done
        ;;

    set)
        edge=${1:?usage: $ALIAS edges set <Edge> <action>}
        action=${2:?usage: $ALIAS edges set <Edge> <action>}
        action=${action,,}
        require_triggers_on
        set_edge "$edge" "$action"
        reconfigure
        log_step "$edge -> $(action_field "$action" 3)"
        ;;

    effect)
        fx=${1:?usage: $ALIAS edges effect <name> <Edge|none>}
        edge=${2:?usage: $ALIAS edges effect <name> <Edge|none>}
        [ "$fx" = desktopgrid ] \
            && die "KWin 6 has no desktop grid effect; the grid is part of the overview now: $ALIAS edges set <Edge> grid"
        store=$(action_field "$fx" 2)
        [[ "$store" == *:* ]] || die "unknown effect '$fx' (one of: $(effect_stores | while read -r s; do action_for_store "$s"; printf ' '; done))"
        require_triggers_on
        if [ "$edge" = none ]; then
            [ "$(effect_list "$store" | joined)" = 9 ] || kconfig_set edges kwinrc "${store%%:*}" "${store#*:}" 9
        else
            set_edge "$edge" "$fx"
        fi
        reconfigure
        log_step "$fx -> $edge"
        ;;

    snap)
        state=${1:?usage: $ALIAS edges snap on|off}
        case "$state" in
            on)  v=true ;;
            off) v=false ;;
            *) die "expected on or off" ;;
        esac
        require_triggers_on
        kconfig_set edges kwinrc Windows ElectricBorderTiling "$v"
        kconfig_set edges kwinrc Windows ElectricBorderMaximize "$v"
        reconfigure
        log_step "window snapping $state"
        ;;

    disable-all)
        # The master switch. Its writes go to a scope of their own, so turning
        # it back on reverts exactly them: the corners as they were the moment
        # before -- the user's own, and any set here -- rather than as they
        # were before this project touched anything.
        if triggers_off; then
            log_info "mouse triggers are already off"
            exit 0
        fi
        for e in "${EDGE_NAMES[@]}"; do
            kconfig_set edges-off kwinrc ElectricBorders "$e" None
        done
        while IFS= read -r s; do
            kconfig_set edges-off kwinrc "${s%%:*}" "${s#*:}" 9
        done < <(effect_stores)
        kconfig_set edges-off kwinrc Windows ElectricBorderTiling false
        kconfig_set edges-off kwinrc Windows ElectricBorderMaximize false
        reconfigure
        log_step "all mouse edge triggers disabled"
        log_info "turn them back on with: $ALIAS edges enable-all"
        ;;

    enable-all)
        if ! triggers_off; then
            log_info "mouse triggers are already on"
            exit 0
        fi
        kconfig_revert edges-off
        reconfigure
        ;;

    revert)
        # The switch first: its records hold what the corners were after our
        # own changes, and reverting ours afterwards is what gets back to the
        # user's.
        triggers_off && kconfig_revert edges-off
        kconfig_revert edges
        reconfigure
        ;;

    *) die "unknown command: $cmd" ;;
esac
