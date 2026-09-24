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

# lib/accel.sh reads the list, from shortcut-actions.tsv: the daemon that owns
# the component and the edges that run the same actions have that one too.
ACTIONS=("${ACCEL_ACTIONS[@]}")

# The component every action belongs to, and the group it is kept in.
COMPONENT=$SLUG

action_desktop() { printf '%s-%s.desktop' "$SLUG" "$1"; }
action_label() { printf '%s' "${ACCEL_ACTION_LABEL[$1]:-}"; }

valid_action() { [ -n "$1" ] && [ -n "${ACCEL_ACTION_LABEL[$1]+x}" ]; }

# Every action's key now, and what the old form still holds for it, from one
# read of the file: into CUR and OLD, by action, as the first field of the
# value with a tab between two keys made a space -- "" when there is none.
#
# One awk rather than kreadconfig6 twice an action, piped through three more
# processes each time: `sync` runs at every login, and that was ninety
# processes before the first key was compared. Read again after every write,
# so what is compared is always what is in the file. KConfig's escapes are
# undone as kreadconfig6 undoes them, the ones a key can hold.
declare -A CUR=() OLD=()
read_bound() {
    local kind action value
    CUR=(); OLD=()
    while IFS=$'\t' read -r kind action value; do
        case "$kind" in
            cur) CUR[$action]=$value ;;
            old) OLD[$action]=$value ;;
        esac
    done < <(awk -v ours="[$COMPONENT]" -v legacy="[services][$SLUG-" '
        function unescape(s,    out, i, c) {
            out = ""
            for (i = 1; i <= length(s); i++) {
                c = substr(s, i, 1)
                if (c != "\\" || i == length(s)) { out = out c; continue }
                c = substr(s, ++i, 1)
                if (c == "s") out = out " "
                else if (c == "t" || c == "n" || c == "r") out = out " "
                else if (c == "\\") out = out "\\"
                else out = out "\\" c
            }
            return out
        }
        /^[ \t]*\[/ { group = $0; gsub(/^[ \t]+|[ \t]+$/, "", group); next }
        /^[ \t]*#/ || index($0, "=") == 0 { next }
        {
            i = index($0, "=")
            key = substr($0, 1, i - 1); gsub(/^[ \t]+|[ \t]+$/, "", key)
            value = substr($0, i + 1); gsub(/^[ \t]+|[ \t]+$/, "", value)
            if (group == ours) { kind = "cur"; action = key }
            else if (key == "_launch" && index(group, legacy) == 1 && group ~ /\.desktop\]$/) {
                kind = "old"
                action = substr(group, length(legacy) + 1)
                sub(/\.desktop\]$/, "", action)
            } else next
            value = unescape(value)
            sub(/,.*/, "", value)
            gsub(/\t/, " ", value)
            gsub(/^ +| +$/, "", value)
            print kind "\t" action "\t" value
        }' "$XDG_CONFIG_HOME/$ACCEL_FILE" 2>/dev/null)
}

# What the shell's configuration wants for every action, into WANT: a key,
# "none", or "" when it leaves the action to whatever KDE has. One jq over the
# merged JSON a caller already has, since `sync` asks about all of them.
declare -A WANT=()
read_configured() {   # <merged json>
    local action value
    WANT=()
    while IFS=$'\t' read -r action value; do
        WANT[$action]=$value
    done < <(jq -r '.shortcuts // {} | to_entries[] | "\(.key)\t\(.value // "" | tostring)"' <<< "$1" 2>/dev/null)
}

# Writes actions' keys into the active profile, so the configuration says what
# KDE was just told -- however many, in one write.
configure_keys() {   # <JSON object: action -> key, "none" or "">
    config_merge '.shortcuts' "$1"
    case $? in
        0) return 0 ;;
        2) log_warn "$(profile_file) does not parse; the shortcut is bound but not saved in the configuration"
           return 1 ;;
        *) return 1 ;;
    esac
}
configure_key() { configure_keys "$(jq -n -c --arg a "$1" --arg k "$2" '{($a): $k}')"; }   # <action> <key|none>

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
            read_bound
            read_configured "$(config_merged)"
            fields=()
            for a in "${ACTIONS[@]}"; do
                cur=${CUR[$a]:-}; [ "$cur" = none ] && cur=""
                old=${OLD[$a]:-}; [ "$old" = none ] && old=""
                fields+=("$a" "$(action_label "$a")" "$cur" "$old" "${WANT[$a]:-}")
            done
            # Five fields an action, handed over as arguments so that nothing
            # in a key or a name can be mistaken for a separator.
            jq -n --arg component "$COMPONENT" \
                  --argjson active "$(accel_component_active "$COMPONENT" | grep -qx true && echo true || echo false)" \
                  '{component: $component, active: $active,
                    actions: [$ARGS.positional as $f | range(0; $f | length; 5) | $f[.:. + 5]
                              | {id: .[0], label: .[1], shortcut: .[2], legacy: .[3], configured: .[4]}]}' \
                  --args "${fields[@]}"
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
        read_bound
        for a in "${ACTIONS[@]}"; do
            cur=${CUR[$a]:-}
            [ "$cur" = none ] && cur=""
            [ -n "$cur" ] || cur='<unbound>'
            old=${OLD[$a]:-}
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
        read_configured "$(config_merged)"
        read_bound
        changed=0
        for a in "${ACTIONS[@]}"; do
            want=${WANT[$a]:-}
            [ -n "$want" ] || continue
            cur=${CUR[$a]:-}
            ACCEL_FRIENDLY_HINT=$(action_label "$a")
            if [ "$want" = none ]; then
                [ -z "$cur" ] || [ "$cur" = none ] && continue
                accel_clear shortcuts "$COMPONENT" "$a"
                read_bound
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
            # Taking a key takes it from whoever held it -- another of ours
            # included -- so what the rest are compared against is read again.
            read_bound
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
        read_bound
        for a in "${ACTIONS[@]}"; do
            old=${OLD[$a]:-}
            [ -n "$old" ] && [ "$old" != none ] || continue
            cur=${CUR[$a]:-}
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
        read_bound
        lost=""
        for a in "${!want[@]}"; do
            [ "${CUR[$a]:-}" = "${want[$a]}" ] || lost="$lost $a"
        done
        if [ -n "$lost" ]; then
            log_warn "kglobalaccel wrote over:$lost -- trying once more"
            write_wanted
            read_bound
        fi

        for a in "${!want[@]}"; do
            cur=${CUR[$a]:-}
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
        configure_keys "$(printf '%s\n' "${ACTIONS[@]}" | jq -R -s -c 'split("\n") | map(select(length > 0) | {(.): ""}) | add')" || true
        ;;

    *) die "unknown command: $cmd" ;;
esac
