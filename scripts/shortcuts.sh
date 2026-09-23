#!/usr/bin/env bash
# Global shortcuts.
#
#   status              what is bound, and what would conflict
#   set <action> <key>  bind a key   (launcher, search, settings, ask, clipboard,
#                                     sidebar, keys, switcher, switcher-reverse,
#                                     overview, overview-reverse, screenshot,
#                                     screenshot-screen, screenshot-window)
#   clear <action>      unbind one
#   sync [--quiet]      make KDE's shortcuts match the shell's configuration
#   migrate             move keys off the old desktop-file entries
#   revert              undo everything this project bound
#
# The keys are the shell's configuration: `shortcuts.<action>` in the profile,
# with Meta for the menu and Meta+Space for search shipped as the defaults. A
# key there is enforced -- `sync` takes it from whoever holds it, and the
# session daemon runs `sync` whenever it starts, so a key another program
# took back while the shell was not looking (KRunner and Meta+Space) is ours
# again at the next login. An empty value is not managed at all: whatever KDE
# has bound stays bound. "none" keeps an action unbound.
#
# `set` and `clear` write both places, so the configuration and KDE never
# disagree after either. When a key someone else holds is taken, they are
# named, and revert gives it back.
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
source "$REPO_ROOT/scripts/lib/config.sh"

ACTIONS=(launcher search settings ask clipboard sidebar keys switcher switcher-reverse
         overview overview-reverse screenshot screenshot-screen screenshot-window)

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
        screenshot) printf 'Screenshot of a region' ;;
        screenshot-screen) printf 'Screenshot of the screen' ;;
        screenshot-window) printf 'Screenshot of the active window' ;;
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

# What the shell's configuration wants for an action: a key, "none", or ""
# when it leaves the action to whatever KDE has. Read from the merged JSON a
# caller already has, since `sync` asks for all fourteen at login.
configured_key() {   # <action> [merged json]
    local merged=${2:-$(config_merged)}
    jq -r --arg a "$1" '.shortcuts[$a] // ""' <<< "$merged" 2>/dev/null
}

# Writes an action's key into the active profile, so the configuration says
# what KDE was just told.
configure_key() {   # <action> <key|none>
    local profile tmp
    profile="$CONFIG_DIR/profiles/$(config_active_profile)/shell.json"
    mkdir -p "$(dirname "$profile")"
    if [ -f "$profile" ] && ! jq -e . "$profile" >/dev/null 2>&1; then
        log_warn "$profile does not parse; the shortcut is bound but not saved in the configuration"
        return 1
    fi
    tmp=$(mktemp)
    if [ -f "$profile" ]; then
        jq --arg a "$1" --arg k "$2" '.shortcuts = ((.shortcuts // {}) + {($a): $k})' "$profile" > "$tmp"
    else
        jq -n --arg a "$1" --arg k "$2" '{shortcuts: {($a): $k}}' > "$tmp"
    fi && mv "$tmp" "$profile" || { rm -f "$tmp"; return 1; }
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
        # The settings page reads this rather than parsing the table below:
        # one answer to "what is bound", so the window and the terminal cannot
        # disagree about it.
        if [ "${1:-}" = "--json" ]; then
            merged=$(config_merged)
            actions=$(for a in "${ACTIONS[@]}"; do
                cur=$(action_key "$a"); [ "$cur" = none ] && cur=""
                old=$(legacy_key "$a"); [ "$old" = none ] && old=""
                jq -cn --arg id "$a" --arg label "$(action_label "$a")" \
                       --arg shortcut "$cur" --arg legacy "$old" \
                       --arg configured "$(configured_key "$a" "$merged")" \
                       '{id: $id, label: $label, shortcut: $shortcut, legacy: $legacy, configured: $configured}'
            done | jq -sc '.')
            jq -n --arg component "$COMPONENT" \
                  --argjson active "$(accel_component_active "$COMPONENT" | grep -qx true && echo true || echo false)" \
                  --argjson actions "$actions" \
                  '{component: $component, active: $active, actions: $actions}'
            exit 0
        fi

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

        # A key this machine cannot convert to kglobalaccel's integer is
        # refused here rather than written. The write itself always succeeds
        # -- it is a line in a file -- so binding an unconvertible key used to
        # report success and grab nothing, which is indistinguishable from a
        # key another component is holding.
        accel_keycode "$key" >/dev/null \
            || die "'$key' is not a key this can bind -- write it as kglobalaccel does (Meta+Shift+S, Meta+/, Meta+Print)"

        # Taken from whoever holds it, each named as it goes (accel_take), so
        # the key does not end up claimed twice with the winner left to chance.
        # The old desktop-file entry is one of those holders, so binding a key
        # that used to live there takes it back without a separate step.
        ACCEL_FRIENDLY_HINT=$(action_label "$action")
        accel_take shortcuts "$key" "$COMPONENT" "$action" replace
        accel_reload
        configure_key "$action" "$key"
        log_step "$action ($(action_label "$action")) -> $key"
        ;;

    clear)
        action=${1:?usage: $ALIAS shortcuts clear <action>}
        valid_action "$action" || die "unknown action '$action'"
        ACCEL_FRIENDLY_HINT=$(action_label "$action")
        accel_clear shortcuts "$COMPONENT" "$action"
        accel_reload
        configure_key "$action" none
        log_step "$action unbound"
        ;;

    # KDE made to match the configuration. Only what differs is touched, and
    # a key is "ours" only when nothing else holds it too: kglobalaccel gives
    # a key held twice to whichever registered last, and KRunner registers at
    # every login.
    sync)
        quiet=0; [ "${1:-}" = "--quiet" ] && quiet=1
        merged=$(config_merged)
        changed=0
        for a in "${ACTIONS[@]}"; do
            want=$(configured_key "$a" "$merged")
            [ -n "$want" ] || continue
            cur=$(action_key "$a")
            ACCEL_FRIENDLY_HINT=$(action_label "$a")
            if [ "$want" = none ]; then
                [ -z "$cur" ] || [ "$cur" = none ] && continue
                accel_clear shortcuts "$COMPONENT" "$a"
                [ "$quiet" = 1 ] || log_step "$a unbound, as configured"
                changed=$((changed + 1))
                continue
            fi
            if ! accel_keycode "$want" >/dev/null; then
                log_warn "$a: '$want' in the configuration is not a key this can bind"
                continue
            fi
            others=$(accel_holders "$want" | awk -F'\t' -v c="$COMPONENT" -v a="$a" '!($1 == c && $2 == a)')
            [ "$cur" = "$want" ] && [ -z "$others" ] && continue
            accel_take shortcuts "$want" "$COMPONENT" "$a" replace
            [ "$quiet" = 1 ] || log_step "$a -> $want, as configured"
            changed=$((changed + 1))
        done
        if [ "$changed" -gt 0 ]; then
            accel_reload
        elif [ "$quiet" = 0 ]; then
            log_info "every configured shortcut is already bound"
        fi
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

    # Gives every key back -- and leaves every action unmanaged in the
    # profile, or the defaults (Meta, Meta+Space) would take them straight
    # back at the next login.
    revert)
        kconfig_revert shortcuts
        accel_reload
        for a in "${ACTIONS[@]}"; do configure_key "$a" "" || break; done
        ;;

    *) die "unknown command: $cmd" ;;
esac
