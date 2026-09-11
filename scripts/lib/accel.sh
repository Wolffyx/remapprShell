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

# kglobalaccel reads the file when it starts, and every program holding a
# shortcut registers again when it comes back, so a restart is what applies
# an edit. The service is the user's own whatever HOME says: without the
# check, every run of the test suite restarted it.
accel_reload() {
    session_available || return 0
    systemctl --user restart plasma-kglobalaccel.service 2>/dev/null \
      || kquitapp6 kglobalacceld 2>/dev/null \
      || log_warn "could not reload kglobalaccel; the change applies at next login"
}
