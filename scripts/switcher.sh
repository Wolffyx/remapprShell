#!/usr/bin/env bash
# Switching windows: Alt+Tab, and Meta+Tab for the task view.
#
#   status [--json]         Alt+Tab's look, and who holds Alt+Tab and Meta+Tab
#   layout <id>             choose Alt+Tab's look, from the installed switchers
#   give alt-tab|meta-tab   hand a key to KWin -- Alt+Tab to its window
#                           switcher, Meta+Tab to its Overview -- taking it from
#                           whatever holds it
#   revert                  undo everything this set
#
# KWin draws both; nothing here reimplements either. What a shell running
# beside it can do is take the keys, as caelestia does on the machine this was
# written on, for its own switcher and overview. So this says who holds each
# key before anything else, and moves one only when asked. Every write is
# ledgered, the one taking a key from its holder included, so revert gives it
# back.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/kconfig.sh"
source "$REPO_ROOT/scripts/lib/accel.sh"
source "$REPO_ROOT/scripts/lib/kwin.sh"

SCOPE=switching

# id | key | its reverse | KWin's action | KWin's reverse action | what it is
#
# Windows' Win+Tab is the task view, which on Plasma is the Overview.
KEYS=(
    "alt-tab|Alt+Tab|Alt+Shift+Tab|Walk Through Windows|Walk Through Windows (Reverse)|Switch windows"
    "meta-tab|Meta+Tab||Overview||Task view"
)

key_entry() {
    local k
    for k in "${KEYS[@]}"; do
        [ "${k%%|*}" = "$1" ] && { printf '%s' "$k"; return 0; }
    done
    return 1
}

# What KWin uses when [TabBox] LayoutName is unset.
DEFAULT_LAYOUT=thumbnail_grid

# Every installed window-switcher package, "<id>\t<name>". KWin 6 looks under
# both kwin/ and kwin-wayland/ in each data directory; the user's own come
# first, so theirs wins a duplicate id.
switcher_layouts() {
    local d m id name dirs
    local -A seen=()
    IFS=: read -r -a dirs <<< "$XDG_DATA_HOME:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
    for d in "${dirs[@]}"; do
        [ -n "$d" ] || continue
        for m in "$d"/kwin/tabbox/*/metadata.json "$d"/kwin-wayland/tabbox/*/metadata.json; do
            [ -f "$m" ] || continue
            id=$(jq -r '.KPlugin.Id // empty' "$m" 2>/dev/null)
            [ -n "$id" ] || id=$(basename "$(dirname "$m")")
            [ -n "${seen[$id]:-}" ] && continue
            seen[$id]=1
            name=$(jq -r '.KPlugin.Name // empty' "$m" 2>/dev/null)
            printf '%s\t%s\n' "$id" "${name:-$id}"
        done
    done
}

current_layout() { kreadconfig6 --file kwinrc --group TabBox --key LayoutName --default "$DEFAULT_LAYOUT"; }

customised() {
    local led
    led=$(kconfig_ledger)
    [ -s "$led" ] && jq -e --arg s "$SCOPE" '[.entries[] | select(.scope == $s)] | length > 0' "$led" >/dev/null 2>&1
}

tsv_to_json() {   # field names...
    jq -R -s -c --args '[split("\n")[] | select(length > 0) | split("\t") as $f
        | [$ARGS.positional, [range($ARGS.positional | length)]] | transpose
        | map({key: .[0], value: ($f[.[1]] // "")}) | from_entries]' "$@"
}

status_json() {
    local k id key rkey action raction label holders keys=""
    for k in "${KEYS[@]}"; do
        IFS='|' read -r id key rkey action raction label <<< "$k"
        holders=$(accel_holders "$key" | tsv_to_json group action name)
        keys+=$(jq -n -c --arg id "$id" --arg key "$key" --arg label "$label" --arg action "$action" \
                    --argjson holders "$holders" \
                    '{id: $id, key: $key, label: $label, kwinAction: $action, holders: $holders,
                      kwin: ([$holders[] | select(.group == "kwin" and .action == $action)] | length > 0)}')$'\n'
    done
    jq -n -c \
        --arg layout "$(current_layout)" \
        --argjson layouts "$(switcher_layouts | tsv_to_json id name)" \
        --argjson keys "$(printf '%s' "$keys" | jq -s -c .)" \
        --argjson customised "$(customised && echo true || echo false)" \
        '{layout: $layout, layouts: $layouts, keys: $keys, customised: $customised}'
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
        printf 'Alt+Tab looks like: %s\n\n' "$(current_layout)"
        echo "installed switchers:"
        switcher_layouts | while IFS=$'\t' read -r id name; do printf '  %-20s %s\n' "$id" "$name"; done
        echo
        echo "keys:"
        for k in "${KEYS[@]}"; do
            IFS='|' read -r id key rkey action raction label <<< "$k"
            h=$(accel_holders "$key" | awk -F'\t' '{ printf "%s%s: %s", (NR > 1 ? "; " : ""), $1, ($3 != "" ? $3 : $2) }')
            printf '  %-10s %-16s %s\n' "$key" "$label" "${h:-nothing}"
        done
        echo
        echo "ledger (what revert would undo):"
        kconfig_ledger_summary "$SCOPE"
        ;;

    layout)
        want=${1:?usage: $ALIAS switcher layout <id>}
        switcher_layouts | cut -f1 | grep -qxF "$want" \
            || die "no window switcher '$want' is installed (one of: $(switcher_layouts | cut -f1 | tr '\n' ' '))"
        kconfig_set "$SCOPE" kwinrc TabBox LayoutName "$want"
        kwin_reconfigure
        log_step "Alt+Tab looks like $want"
        ;;

    give)
        id=${1:?usage: $ALIAS switcher give alt-tab|meta-tab}
        entry=$(key_entry "$id") || die "unknown key '$id' (alt-tab or meta-tab)"
        IFS='|' read -r id key rkey action raction label <<< "$entry"
        accel_take "$SCOPE" "$key" kwin "$action" add
        [ -n "$rkey" ] && accel_take "$SCOPE" "$rkey" kwin "$raction" add
        accel_reload
        log_step "$key -> KWin's $action"
        log_info "undo with: $ALIAS switcher revert"
        ;;

    revert)
        kconfig_revert "$SCOPE"
        accel_reload
        kwin_reconfigure
        ;;

    *) die "unknown command: $cmd" ;;
esac
