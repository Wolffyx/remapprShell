# shellcheck shell=bash
# Global shortcuts, as kglobalaccel keeps them in kglobalshortcutsrc.
#
# Two formats share the file. A component's action -- [kwin], a running
# shell's own -- is "active,default,friendly", and the default and friendly
# name must survive a change: they are what System Settings resets to and
# shows. A desktop file's launch shortcut, [services][<id>.desktop] _launch, is
# the key alone; every entry Plasma writes there looks like `_launch=Meta+E`.
# Either may hold several keys, separated by a tab ("\t" in the file).
#
# shortcuts.sh used to write the three-field form into [services]. kglobalaccel
# took the first field as the key and rewrote the line as "Meta+Shift+R, ,
# Settings": it worked, by accident.
#
# Requires brand.sh, log.sh, kconfig.sh.

ACCEL_FILE=kglobalshortcutsrc

# accel_holders <key>
#
# Every action bound to exactly that key, one per line:
# "<group>\t<action>\t<friendly name>", the group written "A/B" for [A][B] as
# kconfig_set takes it. Read from the file itself, so a key anywhere in a
# multi-key binding counts; the check this replaced saw only a key that came
# first.
accel_holders() {
    local file="$XDG_CONFIG_HOME/$ACCEL_FILE"
    [ -f "$file" ] || return 0
    awk -v want="$1" '
        /^\[/ { g = $0; sub(/^\[/, "", g); sub(/\]$/, "", g); gsub(/\]\[/, "/", g); next }
        /^[^#].*=/ {
            i = index($0, "=")
            action = substr($0, 1, i - 1)
            value = substr($0, i + 1)
            # Fields end at a comma that is not escaped.
            n = 0; field[0] = ""; field[1] = ""; field[2] = ""
            for (j = 1; j <= length(value); j++) {
                c = substr(value, j, 1)
                if (c == "\\") { field[n] = field[n] c substr(value, j + 1, 1); j++; continue }
                if (c == "," && n < 2) { n++; continue }
                field[n] = field[n] c
            }
            friendly = field[2]; gsub(/^ +| +$/, "", friendly)
            count = split(field[0], keys, /\\t/)
            for (k = 1; k <= count; k++) {
                key = keys[k]; gsub(/^ +| +$/, "", key)
                if (key == want) { print g "\t" action "\t" friendly; break }
            }
        }' "$file"
}

accel_value() {   # <group> <action>
    local -a gargs=()
    mapfile -t gargs < <(_kconfig_group_args "$1")
    kreadconfig6 --file "$ACCEL_FILE" "${gargs[@]}" --key "$2" --default ''
}

# Splits a value into ACCEL_ACTIVE, ACCEL_DEFAULT and ACCEL_FRIENDLY.
# kreadconfig6 has already turned "\t" into a real tab.
_accel_fields() {
    local v=$1 rest
    ACCEL_ACTIVE=$v; ACCEL_DEFAULT=none; ACCEL_FRIENDLY=""
    if [[ $v == *,* ]]; then
        ACCEL_ACTIVE=${v%%,*}
        rest=${v#*,}
        if [[ $rest == *,* ]]; then
            ACCEL_DEFAULT=${rest%%,*}
            ACCEL_FRIENDLY=${rest#*,}
        else
            ACCEL_DEFAULT=$rest
        fi
    fi
    ACCEL_ACTIVE=$(printf '%s' "$ACCEL_ACTIVE" | sed 's/^ *//; s/ *$//')
    ACCEL_DEFAULT=$(printf '%s' "$ACCEL_DEFAULT" | sed 's/^ *//; s/ *$//')
    ACCEL_FRIENDLY=$(printf '%s' "$ACCEL_FRIENDLY" | sed 's/^ *//; s/ *$//')
    [ -n "$ACCEL_DEFAULT" ] || ACCEL_DEFAULT=none
}

# The keys in an active field, one per line, "none" dropped.
_accel_keys() {
    printf '%s\n' "$1" | tr '\t' '\n' | sed 's/^ *//; s/ *$//' | grep -vx none | grep . || true
}

# Writes an action's active keys in the form its group uses. Reads the other
# two fields from the last _accel_fields.
_accel_write() {   # <scope> <group> <action> <active>
    _accel_touch "$2" "$3"
    if [[ $2 == services/* ]]; then
        kconfig_set "$1" "$ACCEL_FILE" "$2" "$3" "$4"
    else
        kconfig_set "$1" "$ACCEL_FILE" "$2" "$3" "$4,$ACCEL_DEFAULT,${ACCEL_FRIENDLY:-$3}"
    fi
}

# accel_bind <scope> <group> <action> <key> <add|replace>
#
# `add` keeps the keys the action already has -- Overview keeps its Meta+W
# when it gains Meta+Tab. `replace` leaves it only this one.
accel_bind() {
    local scope=$1 group=$2 action=$3 key=$4 mode=$5 keys
    _accel_fields "$(accel_value "$group" "$action")"
    if [ "$mode" = add ]; then
        keys=$({ _accel_keys "$ACCEL_ACTIVE"; printf '%s\n' "$key"; } | awk '!seen[$0]++' | paste -sd '\t')
    else
        keys=$key
    fi
    _accel_write "$scope" "$group" "$action" "${keys:-none}"
}

# Takes one key off an action, leaving any others it has.
accel_remove_key() {   # <scope> <group> <action> <key>
    local keys
    _accel_fields "$(accel_value "$2" "$3")"
    keys=$(_accel_keys "$ACCEL_ACTIVE" | grep -vxF "$4" | paste -sd '\t')
    _accel_write "$1" "$2" "$3" "${keys:-none}"
}

# accel_take <scope> <key> <group> <action> <add|replace>
#
# Binds the key to one action and takes it from every other. kglobalaccel
# gives a key to one action only, and with two claiming it in the file, which
# one gets it depends on the order they register in -- so "binding it here
# takes it from them" has to be done, not only said. Every write is ledgered
# under the scope, the one to the other holder included, so reverting the
# scope gives the key back.
accel_take() {
    local scope=$1 key=$2 group=$3 action=$4 mode=$5 g a f
    while IFS=$'\t' read -r g a f; do
        [ "$g" = "$group" ] && [ "$a" = "$action" ] && continue
        log_warn "$key taken from $g: ${f:-$a}"
        accel_remove_key "$scope" "$g" "$a" "$key"
    done < <(accel_holders "$key")
    accel_bind "$scope" "$group" "$action" "$key" "$mode"
}

# ---- applying an edit to the running session ------------------------------
#
# Restarting the service is what this used to do, and on Plasma 6.7 it does
# nothing at all: **KWin owns `org.kde.kglobalaccel`**, so
# plasma-kglobalaccel.service starts, finds the name taken, and exits 0
# immediately. Every shortcut this project set was therefore applying at the
# next login and not before -- silently, because the restart "succeeded".
#
# What does work is telling the running server, which takes Qt key codes
# rather than the strings the file holds. Hence the table below.

# Qt::KeyboardModifier values, ORed into the key.
_ACCEL_MOD_Meta=268435456      # 0x10000000
_ACCEL_MOD_Ctrl=67108864       # 0x04000000
_ACCEL_MOD_Alt=134217728       # 0x08000000
_ACCEL_MOD_Shift=33554432      # 0x02000000

# Qt::Key values for everything that is not a letter or a digit, which are
# their ASCII codes. Only what a person is likely to bind: an unknown name
# makes the conversion fail, and the caller falls back to the restart.
_accel_base_code() {
    local k=$1
    case "$k" in
        [A-Za-z])  printf '%d' "'$(printf '%s' "$k" | tr '[:lower:]' '[:upper:]')" ; return 0 ;;
        [0-9])     printf '%d' "'$k" ; return 0 ;;
        F[1-9]|F1[0-9]|F2[0-5]) printf '%d' $(( 16777264 + ${k#F} - 1 )) ; return 0 ;;
    esac
    case "$k" in
        Space)        printf '32' ;;
        Tab)          printf '16777217' ;;
        Backtab)      printf '16777218' ;;
        Return|Enter) printf '16777220' ;;
        Escape|Esc)   printf '16777216' ;;
        Backspace)    printf '16777219' ;;
        Delete|Del)   printf '16777223' ;;
        Insert|Ins)   printf '16777222' ;;
        Home)         printf '16777232' ;;
        End)          printf '16777233' ;;
        PgUp|PageUp)  printf '16777238' ;;
        PgDown|PageDown) printf '16777239' ;;
        Left)         printf '16777234' ;;
        Up)           printf '16777235' ;;
        Right)        printf '16777236' ;;
        Down)         printf '16777237' ;;
        Print|SysReq) printf '16777225' ;;
        Menu)         printf '16777301' ;;
        Comma)        printf '44' ;;
        Period)       printf '46' ;;
        Slash)        printf '47' ;;
        Semicolon)    printf '59' ;;
        Equal)        printf '61' ;;
        Minus)        printf '45' ;;
        Plus)         printf '43' ;;
        *) return 1 ;;
    esac
}

# accel_keycode <key>   -- "Meta+Shift+Print" -> one integer, Qt's encoding.
# Fails on anything it does not know rather than guessing a wrong key.
accel_keycode() {
    local spec=$1 part total=0 base="" bases=0 mod
    local IFS='+'
    for part in $spec; do
        [ -n "$part" ] || continue
        case "$part" in
            Meta|Super|Win) mod=$_ACCEL_MOD_Meta ;;
            Ctrl|Control)   mod=$_ACCEL_MOD_Ctrl ;;
            Alt)            mod=$_ACCEL_MOD_Alt ;;
            Shift)          mod=$_ACCEL_MOD_Shift ;;
            # Anything else is the key itself. A second one means a modifier
            # nobody here knows -- "Hyper+Q" must fail rather than quietly
            # binding Q on its own.
            *)              base=$part; bases=$(( bases + 1 )); continue ;;
        esac
        total=$(( total | mod ))
    done
    # A modifier on its own is a key in its own right -- kglobalaccel accepts
    # "Meta" as a binding, which is how a bare Super key opens a launcher.
    if [ -z "$base" ] && [ "$bases" = 0 ]; then
        case "$spec" in
            Meta|Super|Win) printf '16777250'; return 0 ;;
            Ctrl|Control)   printf '16777249'; return 0 ;;
            Shift)          printf '16777248'; return 0 ;;
            Alt)            printf '16777251'; return 0 ;;
        esac
    fi

    [ -n "$base" ] && [ "$bases" = 1 ] || return 1
    local code
    code=$(_accel_base_code "$base") || return 1
    printf '%d' $(( total | code ))
}

# Every (group, action) an edit has touched, so the reload knows what to push
# rather than pushing the whole file.
ACCEL_TOUCHED=()
_accel_touch() { ACCEL_TOUCHED+=("$1"$'\t'"$2"); }

# The four-part action id kglobalaccel wants: component, action, and a
# friendly name for each. A [services][x.desktop] group is its own component.
_accel_push_live() {   # <group> <action>
    local group=$1 action=$2 component friendly keys key code
    case "$group" in
        services/*) component=${group#services/} ;;
        *)          component=$group ;;
    esac

    _accel_fields "$(accel_value "$group" "$action")"
    friendly=${ACCEL_FRIENDLY:-$action}

    local -a codes=()
    while IFS= read -r key; do
        code=$(accel_keycode "$key") || return 1
        codes+=("$code")
    done < <(_accel_keys "$ACCEL_ACTIVE")

    # Register before setting. A component kglobalaccel has not seen accepts
    # the call and keeps nothing: it reads [services] entries when it starts,
    # so an action added afterwards -- which is every action this project
    # binds -- is unknown to it until something says so.
    busctl --user call org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel \
        doRegister as 4 "$component" "$action" "$component" "$friendly" >/dev/null 2>&1

    local -a args=("asa(ai)" 4 "$component" "$action" "$component" "$friendly" "${#codes[@]}")
    for code in "${codes[@]}"; do args+=(1 "$code"); done

    busctl --user call org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel \
        setForeignShortcutKeys "${args[@]}" >/dev/null 2>&1
}

# Applies what was written to the running session. Pushes each touched action
# to the server; falls back to the restart when anything is not convertible or
# the server is not there, so a key this table does not know still ends up
# right at the next login.
accel_reload() {
    session_available || return 0

    local entry group action pushed=1
    for entry in "${ACCEL_TOUCHED[@]:-}"; do
        [ -n "$entry" ] || continue
        IFS=$'\t' read -r group action <<< "$entry"
        _accel_push_live "$group" "$action" || { pushed=0; break; }
    done

    [ "$pushed" = 1 ] && [ "${#ACCEL_TOUCHED[@]}" -gt 0 ] && return 0

    systemctl --user restart plasma-kglobalaccel.service 2>/dev/null \
      || kquitapp6 kglobalacceld 2>/dev/null \
      || log_warn "could not reload kglobalaccel; the change applies at next login"
}
