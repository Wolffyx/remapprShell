#!/usr/bin/env bash
# Global shortcuts.
#
#   status              what is bound, and what would conflict
#   set <action> <key>  bind a key   (launcher, search, settings, ask, clipboard,
#                                     sidebar, keys, switcher, switcher-reverse,
#                                     overview, overview-reverse)
#   clear <action>      unbind one
#   migrate             move keys off the old desktop-file entries
#   revert              undo everything this project bound
#
# Nothing is bound by default. A shortcut is the one setting a user is
# guaranteed to notice being taken, and the obvious keys here -- Meta for the
# menu, Meta+Space for search -- are exactly the ones another shell is most
# likely to be holding. So this reports the situation and binds only what is
# asked for. When it is asked for a key someone else holds, it takes it from
# them, and says so; revert gives it back.
#
# Each action belongs to this project's own kglobalaccel component, [<slug>],
# the same place any other shell keeps its keys. That is not cosmetic: a
# shortcut is only grabbed when its component has a *running owner*, and the
# owner is the session daemon (bin/windowsd.py.in). The desktop-file form this
# used before -- [services][<id>.desktop] _launch -- is read by kglobalaccel
# only when it starts, and on Plasma 6.7 kglobalaccel runs inside kwin_wayland
# and cannot be restarted, so every key bound after login was filed and never
# pressed. `migrate` moves an old binding across. See lib/accel.sh.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/kconfig.sh"
source "$REPO_ROOT/scripts/lib/accel.sh"

ACTIONS=(launcher search settings ask clipboard sidebar keys switcher switcher-reverse
         overview overview-reverse)

# The component every action belongs to, and the group it is kept in.
COMPONENT=$SLUG

action_desktop() { printf '%s-%s.desktop' "$SLUG" "$1"; }
action_label() {
    case "$1" in
        launcher) printf 'Application menu' ;;
        search)   printf 'Search' ;;
        settings) printf 'Settings' ;;
        ask)      printf 'Ask about the last notification' ;;
        clipboard) printf 'Clipboard history' ;;
        sidebar)  printf 'Sidebar' ;;
        keys)     printf 'Keyboard shortcuts' ;;
        switcher) printf 'Window switcher' ;;
        switcher-reverse) printf 'Window switcher (backwards)' ;;
        overview) printf 'Desktops' ;;
        overview-reverse) printf 'Desktops (backwards)' ;;
    esac
}

valid_action() { printf '%s\n' "${ACTIONS[@]}" | grep -qxF "$1"; }

# The key an action is bound to now, or "" -- the first field of the value.
action_key() {
    kreadconfig6 --file kglobalshortcutsrc --group "$COMPONENT" --key "$1" --default '' \
        | cut -d, -f1 | tr '\t' ' ' | sed 's/^ *//; s/ *$//'
}

# What the old form still holds for an action, or "".
legacy_key() {
    kreadconfig6 --file kglobalshortcutsrc --group services --group "$(action_desktop "$1")" \
        --key _launch --default '' | cut -d, -f1 | tr '\t' ' ' | sed 's/^ *//; s/ *$//'
}

# Everything currently bound to a key, as "group: name", so a conflict can be
# named rather than discovered when the shortcut silently does nothing.
holders_of() {
    accel_holders "$1" | awk -F'\t' '{ print $1 ": " ($3 != "" ? $3 : $2) }'
}

cmd=${1:-status}
[ $# -gt 0 ] && shift

case "$cmd" in
    status)
        # "active" is the whole question: a shortcut kglobalaccel has a record
        # of but no running owner for is never grabbed, and looks from the
        # outside exactly like a key that does nothing.
        active=$(accel_component_active "$COMPONENT")
        case "$active" in
            true)  state="grabbed" ;;
            false) state="NOT grabbed -- no owner is running" ;;
            *)     state="unknown -- kglobalaccel did not answer" ;;
        esac
        printf 'component %s: %s\n\n' "$COMPONENT" "$state"

        printf '%-12s %-28s %s\n' ACTION SHORTCUT 'OLD ENTRY'
        for a in "${ACTIONS[@]}"; do
            cur=$(action_key "$a")
            [ "$cur" = none ] && cur=""
            [ -n "$cur" ] || cur='<unbound>'
            old=$(legacy_key "$a")
            [ "$old" = none ] && old=""
            printf '%-12s %-28s %s\n' "$a" "$cur" "${old:+$old -- run '$ALIAS shortcuts migrate'}"
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

        # Taken from whoever holds it, each named as it goes (accel_take), so
        # the key does not end up claimed twice with the winner left to chance.
        # The old desktop-file entry is one of those holders, so binding a key
        # that used to live there takes it back without a separate step.
        ACCEL_FRIENDLY_HINT=$(action_label "$action")
        accel_take shortcuts "$key" "$COMPONENT" "$action" replace
        accel_reload
        log_step "$action ($(action_label "$action")) -> $key"
        ;;

    clear)
        action=${1:?usage: $ALIAS shortcuts clear <action>}
        valid_action "$action" || die "unknown action '$action'"
        ACCEL_FRIENDLY_HINT=$(action_label "$action")
        accel_clear shortcuts "$COMPONENT" "$action"
        accel_reload
        log_step "$action unbound"
        ;;

    # One-way, and safe to run twice: an action already bound in the new form
    # is left alone. The old groups go entirely, so System Settings stops
    # listing eight of this project's entries that can never be pressed.
    migrate)
        moved=0
        # In two passes, and the order is the whole trick. The old holder has
        # to give the key up in the *running* server before the new one asks
        # for it: kglobalaccel refuses a key it already has recorded against a
        # live component, and rewriting the file underneath it changes nothing.
        declare -A want=()
        for a in "${ACTIONS[@]}"; do
            old=$(legacy_key "$a")
            [ -n "$old" ] && [ "$old" != none ] || continue
            cur=$(action_key "$a")
            if [ -n "$cur" ] && [ "$cur" != none ]; then
                log_info "$a is already bound to $cur; dropping the old $old"
            else
                want[$a]=$old
            fi
            d=$(action_desktop "$a")
            accel_release shortcuts "services/$d" _launch
            accel_unregister "$d" _launch
        done

        # kglobalaccel writes its whole state back on a timer after an
        # unregister, from memory, which lands on top of whatever was written
        # to the file in the meantime. So the second pass waits for that
        # writeout rather than racing it -- and checks afterwards, because a
        # migration that silently left every key unbound is what the first
        # attempt at this did.
        session_available && sleep 1

        write_wanted() {
            local a
            for a in "${!want[@]}"; do
                ACCEL_FRIENDLY_HINT=$(action_label "$a")
                accel_bind shortcuts "$COMPONENT" "$a" "${want[$a]}" replace
            done
            # Purged rather than left at "none": the group only ever held our
            # key, and an emptied group is still a line in System Settings.
            # Safe only after the unregister above, or it comes straight back.
            for a in "${ACTIONS[@]}"; do
                kconfig_purge_group kglobalshortcutsrc "services/$(action_desktop "$a")"
            done
            accel_reload
        }

        write_wanted
        lost=""
        for a in "${!want[@]}"; do
            [ "$(action_key "$a")" = "${want[$a]}" ] || lost="$lost $a"
        done
        if [ -n "$lost" ]; then
            log_warn "kglobalaccel wrote over:$lost -- trying once more"
            write_wanted
        fi

        for a in "${!want[@]}"; do
            cur=$(action_key "$a")
            if [ "$cur" = "${want[$a]}" ]; then
                log_step "$a -> $cur (was a desktop-file entry)"
                moved=$((moved + 1))
            else
                log_warn "$a could not take ${want[$a]}; bind it by hand: $ALIAS shortcuts set $a ${want[$a]}"
            fi
        done
        [ "$moved" = 0 ] && log_info "nothing to move" || log_step "$moved shortcut(s) moved"
        ;;

    revert)
        kconfig_revert shortcuts
        accel_reload
        ;;

    *) die "unknown command: $cmd" ;;
esac
