# shellcheck shell=bash
# KWin's own screen edges and corners: what each can be set to, where KWin
# keeps it, and the commands that read and set them.
#
# Sourced by edges.sh, never executed. Requires brand.sh, log.sh, kconfig.sh
# and kwin.sh.

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

# The table above, split once. Everything below used to cut a field out of it
# with a process per lookup -- `status --json` came to about three hundred.
declare -A ACTION_STORE=() ACTION_LABEL=() STORE_ACTION=()
ACTION_IDS=()
EFFECT_STORES=()
_actions_load() {
    local a id store label
    for a in "${ACTIONS[@]}"; do
        IFS='|' read -r id store label <<< "$a"
        ACTION_IDS+=("$id")
        ACTION_STORE[$id]=$store
        ACTION_LABEL[$id]=$label
        [ -n "$store" ] && [ -z "${STORE_ACTION[$store]+x}" ] && STORE_ACTION[$store]=$id
    done
    # The effect keys, each once, in the order they are always written in.
    mapfile -t EFFECT_STORES < <(printf '%s\n' "${ACTION_STORE[@]}" | grep ':' | sort -u)
}
_actions_load

action_field() {   # <id> <2 = store, 3 = label>
    [ -n "$1" ] && [ -n "${ACTION_LABEL[$1]+x}" ] || return 1
    case "$2" in
        2) printf '%s\n' "${ACTION_STORE[$1]}" ;;
        3) printf '%s\n' "${ACTION_LABEL[$1]}" ;;
    esac
}
action_ids() { printf '%s\n' "${ACTION_IDS[@]}"; }
action_for_store() { printf '%s' "${STORE_ACTION[$1]:-}"; }

# The edges each effect is bound to, as "i,j" in order -- 9 and junk dropped,
# nothing at all for no edge -- read from kwinrc once and kept up to date by
# every write below.
declare -A EFFECT_EDGES=()
EFFECT_EDGES_READ=0
effect_edges_read() {
    local s
    for s in "${EFFECT_STORES[@]}"; do
        EFFECT_EDGES[$s]=$(_edge_list_with \
            "$(kreadconfig6 --file kwinrc --group "${s%%:*}" --key "${s#*:}" --default 9)")
    done
    EFFECT_EDGES_READ=1
}

# A list of edges with one added or taken out: sorted, each once, only 0-7.
_edge_list_with() {   # <"i,j,..."> [add|remove <index>]
    local -a parts=() seen=()
    local p out=""
    IFS=, read -ra parts <<< "$1"
    for p in "${parts[@]}"; do
        [[ $p =~ ^[0-7]$ ]] && seen[p]=1
    done
    case "${2:-}" in
        add)    seen[$3]=1 ;;
        remove) unset 'seen[$3]' ;;
    esac
    for p in "${!seen[@]}"; do out+=${out:+,}$p; done
    printf '%s' "$out"
}

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
    [ "$EFFECT_EDGES_READ" = 1 ] || effect_edges_read
    for store in "${EFFECT_STORES[@]}"; do
        case ",${EFFECT_EDGES[$store]}," in
            *",$idx,"*) action_for_store "$store"; return ;;
        esac
    done
    printf 'none'
}

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

    [ "$EFFECT_EDGES_READ" = 1 ] || effect_edges_read
    for s in "${EFFECT_STORES[@]}"; do
        old=${EFFECT_EDGES[$s]}
        if [ "$s" = "$store" ]; then
            new=$(_edge_list_with "$old" add "$idx")
        else
            new=$(_edge_list_with "$old" remove "$idx")
        fi
        [ "$new" = "$old" ] && continue
        kconfig_set edges kwinrc "${s%%:*}" "${s#*:}" "${new:-9}"
        EFFECT_EDGES[$s]=$new
    done
}

status_json() {
    local e rows=""
    effect_edges_read
    for e in "${EDGE_NAMES[@]}"; do
        rows+="$e"$'\t'"$(edge_action "$e")"$'\n'
    done
    local customised=false led
    led=$(kconfig_ledger)
    [ -s "$led" ] && jq -e '[.entries[] | select(.scope == "edges" or .scope == "edges-off")] | length > 0' "$led" >/dev/null 2>&1 \
        && customised=true

    local actions id
    actions=$(for id in "${ACTION_IDS[@]}"; do printf '%s\t%s\n' "$id" "${ACTION_LABEL[$id]}"; done \
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

# ---- the commands ------------------------------------------------------------

edges_status() {   # [--json]
    local e a scripts
    if [ "${1:-}" = "--json" ]; then
        status_json
        echo
        exit 0
    fi
    printf 'mouse triggers: %s\n\n' "$(triggers_off && echo "off  ($ALIAS edges enable-all puts them back)" || echo on)"
    echo "corners and edges:"
    effect_edges_read
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
}

edges_actions() {
    local a
    for a in "${ACTION_IDS[@]}"; do
        printf '%-20s %s\n' "$a" "${ACTION_LABEL[$a]}"
    done
}

edges_set() {   # <Edge> <action>
    local edge action
    edge=${1:?usage: $ALIAS edges set <Edge> <action>}
    action=${2:?usage: $ALIAS edges set <Edge> <action>}
    action=${action,,}
    require_triggers_on
    set_edge "$edge" "$action"
    kwin_reconfigure
    log_step "$edge -> $(action_field "$action" 3)"
}

edges_effect() {   # <name> <Edge|none>
    local fx edge store
    fx=${1:?usage: $ALIAS edges effect <name> <Edge|none>}
    edge=${2:?usage: $ALIAS edges effect <name> <Edge|none>}
    [ "$fx" = desktopgrid ] \
        && die "KWin 6 has no desktop grid effect; the grid is part of the overview now: $ALIAS edges set <Edge> grid"
    store=$(action_field "$fx" 2)
    [[ "$store" == *:* ]] || die "unknown effect '$fx' (one of: $(for s in "${EFFECT_STORES[@]}"; do action_for_store "$s"; printf ' '; done))"
    require_triggers_on
    if [ "$edge" = none ]; then
        effect_edges_read
        [ -z "${EFFECT_EDGES[$store]}" ] || kconfig_set edges kwinrc "${store%%:*}" "${store#*:}" 9
    else
        set_edge "$edge" "$fx"
    fi
    kwin_reconfigure
    log_step "$fx -> $edge"
}

edges_snap() {   # on|off
    local state v
    state=${1:?usage: $ALIAS edges snap on|off}
    case "$state" in
        on)  v=true ;;
        off) v=false ;;
        *) die "expected on or off" ;;
    esac
    require_triggers_on
    kconfig_set edges kwinrc Windows ElectricBorderTiling "$v"
    kconfig_set edges kwinrc Windows ElectricBorderMaximize "$v"
    kwin_reconfigure
    log_step "window snapping $state"
}

edges_disable_all() {
    local e s
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
    for s in "${EFFECT_STORES[@]}"; do
        kconfig_set edges-off kwinrc "${s%%:*}" "${s#*:}" 9
    done
    kconfig_set edges-off kwinrc Windows ElectricBorderTiling false
    kconfig_set edges-off kwinrc Windows ElectricBorderMaximize false
    kwin_reconfigure
    log_step "all mouse edge triggers disabled"
    log_info "turn them back on with: $ALIAS edges enable-all"
}

edges_enable_all() {
    if ! triggers_off; then
        log_info "mouse triggers are already on"
        exit 0
    fi
    kconfig_revert edges-off
    kwin_reconfigure
}
