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
# asked for.
#
# KDE stores each binding as "active,default,friendly". Both other fields are
# preserved: the default is what "reset to defaults" in System Settings restores
# to, and the friendly name is what the shortcuts editor displays.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/kconfig.sh"

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

# Everything currently bound to a key, so a conflict can be named rather than
# discovered when the shortcut silently does nothing.
holders_of() {
    local key=$1
    grep -nE "^[^=]+=${key}(,|$|\\\\t)" "$XDG_CONFIG_HOME/kglobalshortcutsrc" 2>/dev/null \
      | sed 's/=.*//' | sed 's/^[0-9]*://' || true
}

reload_accel() {
    # kglobalaccel reads the file at startup; without a reload a new binding
    # does nothing until the next login, which looks exactly like a bug.
    #
    # A throwaway HOME does not make this a throwaway kglobalaccel: the
    # service is the user's own, so without the check every run of the test
    # suite restarted it -- four times, at every `make test`.
    session_available || return 0
    systemctl --user restart plasma-kglobalaccel.service 2>/dev/null \
      || kquitapp6 kglobalacceld 2>/dev/null \
      || log_warn "could not reload kglobalaccel; the binding applies at next login"
}

cmd=${1:-status}
[ $# -gt 0 ] && shift

case "$cmd" in
    status)
        printf '%-12s %-28s %s\n' ACTION SHORTCUT ENTRY
        for a in "${ACTIONS[@]}"; do
            d=$(action_desktop "$a")
            cur=$(kreadconfig6 --file kglobalshortcutsrc --group services --group "$d" --key _launch --default '' | cut -d, -f1)
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

        holders=$(holders_of "$key")
        if [ -n "$holders" ]; then
            log_warn "$key is already used by: $(printf '%s' "$holders" | tr '\n' ' ')"
            log_warn "binding it here will take it from them"
        fi

        # active,default,friendly -- the last two are what System Settings uses.
        kconfig_set shortcuts kglobalshortcutsrc "services/$d" _launch "$key,none,$(action_label "$action")"
        reload_accel
        log_step "$action -> $key"
        ;;

    clear)
        action=${1:?usage: $ALIAS shortcuts clear <action>}
        valid_action "$action" || die "unknown action '$action'"
        d=$(action_desktop "$action")
        kconfig_set shortcuts kglobalshortcutsrc "services/$d" _launch "none,none,$(action_label "$action")"
        reload_accel
        log_step "$action unbound"
        ;;

    revert)
        kconfig_revert shortcuts
        reload_accel
        ;;

    *) die "unknown command: $cmd" ;;
esac
