# shellcheck shell=bash
# Title-bar buttons: where KWin draws minimise, maximise and close.
#
# Sourced by windows.sh, never executed, and by preset.sh for the part a
# layout needs (the jq below, and where "before a layout" is kept). The KDE
# half needs brand.sh, log.sh, kconfig.sh, kwin.sh and config.sh.
#
# One setting, windows.titleButtons, and what it means to KWin:
#
#   plasma   nothing written: KWin's order is whatever Plasma's Window
#            Decorations page says. Choosing it puts back what this changed.
#   right    ButtonsOnLeft= (empty)  ButtonsOnRight=IAX
#   left     ButtonsOnLeft=XIA       ButtonsOnRight= (empty) -- the
#            macOS-like layout's, close in the corner
#   custom   windows.titleButtonsLeft and windows.titleButtonsRight, strings
#            of KWin's own button letters
#
# Written to kwinrc, [org.kde.kdecoration2], through the ledger in a scope of
# its own (windows-titlebar), so going back to plasma, `behaviour revert`,
# an uninstall and a restore all put back exactly what was there -- a key that
# was unset (Breeze's MS and HIAX) deleted again, not written empty. Then KWin
# is asked to reconfigure, which redraws every open window's title bar.
#
# The setting is the shell's (the profile holds it, a layout can carry it);
# the order is KWin's. `apply` makes the second match the first, and is what
# `set`, a layout and a profile switch all end in, so the CLI and the
# Settings page cannot disagree about what a choice does.

TITLEBAR_SCOPE=windows-titlebar
TITLEBAR_GROUP=org.kde.kdecoration2

# KWin's letters, as kdecoration2 writes them: window menu, on all desktops,
# help, minimise, maximise, close, keep above, keep below, shade.
TITLEBAR_LETTERS=MSHIAXFBL

# What KWin uses when the keys are unset: Breeze's own order.
TITLEBAR_DEFAULT_LEFT=MS
TITLEBAR_DEFAULT_RIGHT=HIAX

# Each fixed choice's two sides, "left|right". Custom reads the profile.
declare -A TITLEBAR_SIDES=([right]="|IAX" [left]="XIA|")
TITLEBAR_MODES="plasma right left custom"

# The profile keys a layout may set, and the switch that says whether it may.
TITLEBAR_KEYS='["titleButtons", "titleButtonsLeft", "titleButtonsRight"]'

# What the title-bar settings were before a layout changed them, so the next
# layout that says nothing about them puts them back. Removed once it has.
titlebar_stash_file() { printf '%s/titlebar-before-layout.json' "$STATE_DIR"; }

# The jq a layout apply and the layout list share: `own` is an object's
# title-bar keys and nothing else, `bare($conf)` a configuration with the
# title-bar keys a layout's $conf does not set taken out -- they are carried
# across layouts rather than being part of one -- and the switch always.
TITLEBAR_JQ_DEFS='
def tb_keys: '"$TITLEBAR_KEYS"';
def tb_own: with_entries(select(.key as $k | tb_keys | index($k)));
def tb_drop($ks): with_entries(select(.key as $k | $ks | index($k) | not));
def tb_tidy: if (.windows | type) == "object" and .windows == {} then del(.windows) else . end;
def bare($conf):
    if (.windows | type) != "object" then .
    else (tb_keys - (($conf.windows // {}) | keys) + ["titleButtonsFromLayouts"]) as $ks
         | .windows |= tb_drop($ks) | tb_tidy end;
def unswitched: if (.windows | type) == "object"
    then .windows |= tb_drop(["titleButtonsFromLayouts"]) | tb_tidy else . end;
'

# titlebar_letters_ok <letters> -- KWin's letters only, none twice.
titlebar_letters_ok() {
    [[ "$1" =~ ^[$TITLEBAR_LETTERS]*$ ]] || return 1
    [ "$(printf '%s' "$1" | fold -w1 | sort | uniq -d)" = "" ]
}

# The sentinel kconfig_set reads an unset key as.
KCONFIG_ABSENT="__rmpr_absent_1f8b__"

# titlebar_kwin_key <key> -- what kwinrc holds, or the sentinel for unset.
titlebar_kwin_key() {
    kreadconfig6 --file kwinrc --group "$TITLEBAR_GROUP" --key "$1" --default "$KCONFIG_ABSENT" 2>/dev/null \
        || printf '%s' "$KCONFIG_ABSENT"
}

# The order KWin draws now, "left|right", unset keys read as Breeze's.
titlebar_kwin_sides() {
    local l r
    l=$(titlebar_kwin_key ButtonsOnLeft)
    r=$(titlebar_kwin_key ButtonsOnRight)
    [ "$l" = "$KCONFIG_ABSENT" ] && l=$TITLEBAR_DEFAULT_LEFT
    [ "$r" = "$KCONFIG_ABSENT" ] && r=$TITLEBAR_DEFAULT_RIGHT
    printf '%s|%s' "$l" "$r"
}

# The order the setting asks for, "left|right"; nothing and 1 for plasma,
# 2 for a setting that makes no sense (an unknown mode, letters KWin does
# not have).
titlebar_wanted() {
    local mode l r
    mode=$(config_get '.windows.titleButtons' plasma)
    [ "$mode" = plasma ] && return 1
    if [ -n "${TITLEBAR_SIDES[$mode]+x}" ]; then
        printf '%s' "${TITLEBAR_SIDES[$mode]}"
        return 0
    fi
    [ "$mode" = custom ] || { log_error "windows.titleButtons is '$mode' (one of: $TITLEBAR_MODES)"; return 2; }
    # Not config_get, which reads an empty string as absent: nothing on
    # one side is a choice.
    l=$(config_merged | jq -r --arg d "$TITLEBAR_DEFAULT_LEFT" '.windows.titleButtonsLeft // $d')
    r=$(config_merged | jq -r --arg d "$TITLEBAR_DEFAULT_RIGHT" '.windows.titleButtonsRight // $d')
    titlebar_letters_ok "$l$r" || { log_error "the custom title-bar buttons are not KWin's letters, each once: '$l' '$r'"; return 2; }
    printf '%s|%s' "$l" "$r"
}

titlebar_written() {
    local led
    led=$(kconfig_ledger)
    [ -s "$led" ] && jq -e --arg s "$TITLEBAR_SCOPE" 'any(.entries[]?; .scope == $s)' "$led" >/dev/null 2>&1
}

# KWin's order as it was before this changed it. Nothing to do when nothing
# was changed.
titlebar_release() {
    titlebar_written || return 0
    kconfig_revert "$TITLEBAR_SCOPE" >/dev/null
    kwin_reconfigure
    log_step "title-bar buttons: KWin's own order again"
}

# One side written only when kwinrc does not already hold it -- an unset key
# is not the empty string, so "" is written over an unset one.
titlebar_write_key() {   # <key> <letters>
    [ "$(titlebar_kwin_key "$1")" = "$2" ] && return 1
    kconfig_set "$TITLEBAR_SCOPE" kwinrc "$TITLEBAR_GROUP" "$1" "$2"
}

# Makes kwinrc say what the setting says. Quiet when it already does.
titlebar_apply() {
    local sides changed=0
    sides=$(titlebar_wanted)
    case $? in
        1) titlebar_release; return 0 ;;
        2) return 1 ;;
    esac
    titlebar_write_key ButtonsOnLeft "${sides%%|*}" && changed=1
    titlebar_write_key ButtonsOnRight "${sides#*|}" && changed=1
    [ "$changed" = 1 ] || return 0
    kwin_reconfigure
    log_step "title-bar buttons: left '${sides%%|*}', right '${sides#*|}'"
}

titlebar_status_json() {
    local wanted kwin
    wanted=$(titlebar_wanted 2>/dev/null) || wanted=""
    kwin=$(titlebar_kwin_sides)
    config_merged | jq -c --arg kwin "$kwin" --arg wanted "$wanted" \
        --argjson written "$(titlebar_written && echo true || echo false)" \
        --argjson stashed "$([ -f "$(titlebar_stash_file)" ] && echo true || echo false)" '
        (.windows // {}) as $w
        | { mode: ($w.titleButtons // "plasma"),
            left: ($w.titleButtonsLeft // ""), right: ($w.titleButtonsRight // ""),
            fromLayouts: ($w.titleButtonsFromLayouts != false),
            wanted: (if $wanted == "" then null
                     else ($wanted | split("|")) as [$l, $r] | {left: $l, right: ($r // "")} end),
            kwin: (($kwin | split("|")) as [$l, $r] | {left: $l, right: ($r // "")}),
            written: $written, laidOut: $stashed }'
}

titlebar_status_text() {
    local kwin
    kwin=$(titlebar_kwin_sides)
    printf 'setting:  %s\n' "$(config_get '.windows.titleButtons' plasma)"
    printf 'KWin:     left %s, right %s\n' "${kwin%%|*}" "${kwin#*|}"
    printf 'layouts:  %s\n' "$(config_get '.windows.titleButtonsFromLayouts' true)"
    echo "ledger (what plasma, or revert, would put back):"
    kconfig_ledger_summary "$TITLEBAR_SCOPE"
}

# Writes the profile, then KWin. Any choice made here is the person's own,
# so "what you had before a layout" is let go of: it is this now.
titlebar_set() {   # <mode> [<left> <right>]
    local mode=${1:-} l=${2:-} r=${3:-} values
    case " $TITLEBAR_MODES " in
        *" $mode "*) ;;
        *) die "title-bar buttons: one of $TITLEBAR_MODES, not '$mode'" ;;
    esac
    values=$(jq -nc --arg m "$mode" '{titleButtons: $m}')
    if [ "$mode" = custom ]; then
        titlebar_letters_ok "$l$r" \
            || die "custom title-bar buttons take KWin's letters ($TITLEBAR_LETTERS), each once: '$l' '$r'"
        values=$(jq -nc --arg m "$mode" --arg l "$l" --arg r "$r" \
                    '{titleButtons: $m, titleButtonsLeft: $l, titleButtonsRight: $r}')
    fi
    titlebar_config_merge "$values"
    rm -f "$(titlebar_stash_file)"
    titlebar_apply
}

titlebar_config_merge() {   # <json object>
    config_merge '.windows' "$1"
    case $? in
        0) ;;
        2) die "$(profile_file) does not parse; fix it first" ;;
        *) die "could not write $(profile_file)" ;;
    esac
}

# `windows titlebar <verb>`.
titlebar_cmd() {
    local sub=${1:-status}
    [ $# -gt 0 ] && shift
    case "$sub" in
        status)
            if [ "${1:-}" = "--json" ]; then titlebar_status_json; else titlebar_status_text; fi ;;
        set)     titlebar_set "$@" ;;
        layouts)
            case "${1:-}" in
                true|false) titlebar_config_merge "{\"titleButtonsFromLayouts\": $1}" ;;
                *) die "title-bar buttons: layouts true or false" ;;
            esac ;;
        apply)   titlebar_apply ;;
        revert)  titlebar_release ;;
        *) die "unknown command: titlebar $sub (expected status, set, layouts, apply or revert)" ;;
    esac
}

# --- layouts ----------------------------------------------------------------

# titlebar_layout_carry <layout config json>
#
# What a layout apply writes, as {config, stash}: the layout's configuration
# with the title-bar settings decided, and what to keep as "before a layout"
# (null for nothing). The switch is the person's and never a layout's, so it
# is carried whatever the layout says. Then:
#
#   switch off                  the title-bar settings stay as they are
#   the layout sets them        the layout's, and what was there is kept --
#                               unless something already is, which is older
#   the layout says nothing     what was kept, or else what is there now
#
# so the macOS-like layout puts the buttons on the left and the next layout
# puts back what the person had.
titlebar_layout_carry() {
    local conf=$1 cur stash=null file
    cur=$(jq -c . "$(profile_file)" 2>/dev/null) || cur='{}'
    [ -n "$cur" ] || cur='{}'
    file=$(titlebar_stash_file)
    [ -f "$file" ] && stash=$(jq -c . "$file" 2>/dev/null || echo null)
    jq -nc --argjson conf "$conf" --argjson cur "$cur" --argjson stash "$stash" "$TITLEBAR_JQ_DEFS"'
        (($cur.windows // {}) | if type == "object" then . else {} end) as $w
        | (($conf.windows // {}) | if type == "object" then . else {} end) as $lw
        | ($w | tb_own) as $mine
        | ($lw | tb_own) as $laid
        | (if $w.titleButtonsFromLayouts == false then {keep: $mine, stash: $stash}
           elif $laid != {} then {keep: $laid, stash: ($stash // $mine)}
           else {keep: ($stash // $mine), stash: null} end) as $d
        | (($lw | tb_drop(tb_keys + ["titleButtonsFromLayouts"])) + $d.keep
           + ($w | with_entries(select(.key == "titleButtonsFromLayouts")))) as $nw
        | {config: ($conf | .windows = $nw | tb_tidy), stash: $d.stash}'
}

# Keeps, or lets go of, "before a layout".
titlebar_stash_save() {   # <json or null>
    local file
    file=$(titlebar_stash_file)
    if [ "$1" = null ]; then rm -f "$file"; return 0; fi
    mkdir -p "${file%/*}" && printf '%s\n' "$1" > "$file"
}
