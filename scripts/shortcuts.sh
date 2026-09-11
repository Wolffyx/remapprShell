#!/usr/bin/env bash
# Global shortcuts.
#
#   status              what is bound, and what would conflict
#   set <action> <key>  bind a key   (launcher, search, settings, ask, clipboard)
#   clear <action>      unbind one
#   revert              undo everything this project bound
#
# Nothing is bound by default. A shortcut is the one setting a user is
# guaranteed to notice being taken, and the obvious keys here -- Meta for the
# menu, Meta+Space for search -- are exactly the ones another shell is most
# likely to be holding. So this reports the situation and binds only what is
# asked for. When it is asked for a key someone else holds, it takes it from
# them, and says so; revert gives it back.
#
# Each action is a desktop file's launch shortcut, [services][<id>.desktop]
# _launch, which kglobalaccel keeps as the key alone. See lib/accel.sh.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/kconfig.sh"
source "$REPO_ROOT/scripts/lib/accel.sh"

ACTIONS=(launcher search settings ask clipboard)

action_desktop() { printf '%s-%s.desktop' "$SLUG" "$1"; }
action_label() {
    case "$1" in
        launcher) printf 'Application menu' ;;
        search)   printf 'Search' ;;
        settings) printf 'Settings' ;;
        ask)      printf 'Ask about the last notification' ;;
        clipboard) printf 'Clipboard history' ;;
    esac
}

valid_action() { printf '%s\n' "${ACTIONS[@]}" | grep -qxF "$1"; }

# Everything currently bound to a key, as "group: name", so a conflict can be
# named rather than discovered when the shortcut silently does nothing.
holders_of() {
    accel_holders "$1" | awk -F'\t' '{ print $1 ": " ($3 != "" ? $3 : $2) }'
}

cmd=${1:-status}
[ $# -gt 0 ] && shift

case "$cmd" in
    status)
        printf '%-12s %-28s %s\n' ACTION SHORTCUT ENTRY
        for a in "${ACTIONS[@]}"; do
            d=$(action_desktop "$a")
            cur=$(kreadconfig6 --file kglobalshortcutsrc --group services --group "$d" --key _launch --default '' | cut -d, -f1 | tr '\t' ' ')
            [ "$cur" = none ] && cur=""
            [ -n "$cur" ] || cur='<unbound>'
            installed=$([ -f "$APPLICATIONS_DIR/$d" ] && echo installed || echo missing)
            printf '%-12s %-28s %s\n' "$a" "$cur" "$installed"
        done
        echo
        echo "keys another component is already holding:"
        for k in "Meta" "Meta+Space" "Meta+Tab" "Alt+Tab"; do
            h=$(holders_of "$k")
            if [ -n "$h" ]; then
                printf '  %-12s %s\n' "$k" "$(printf '%s' "$h" | tr '\n' ' ')"
            else
                printf '  %-12s free\n' "$k"
            fi
        done
        echo
        echo "ledger (what revert would undo):"
        kconfig_ledger_summary shortcuts
        ;;

    set)
        action=${1:?usage: $ALIAS shortcuts set <action> <key>}
        key=${2:?usage: $ALIAS shortcuts set <action> <key>}
        valid_action "$action" || die "unknown action '$action' (one of: ${ACTIONS[*]})"

        d=$(action_desktop "$action")
        [ -f "$APPLICATIONS_DIR/$d" ] || die "$APPLICATIONS_DIR/$d is missing; run 'make link' first"

        # Taken from whoever holds it, each named as it goes (accel_take), so
        # the key does not end up claimed twice with the winner left to chance.
        accel_take shortcuts "$key" "services/$d" _launch replace
        accel_reload
        log_step "$action ($(action_label "$action")) -> $key"
        ;;

    clear)
        action=${1:?usage: $ALIAS shortcuts clear <action>}
        valid_action "$action" || die "unknown action '$action'"
        d=$(action_desktop "$action")
        kconfig_set shortcuts kglobalshortcutsrc "services/$d" _launch none
        accel_reload
        log_step "$action unbound"
        ;;

    revert)
        kconfig_revert shortcuts
        accel_reload
        ;;

    *) die "unknown command: $cmd" ;;
esac
