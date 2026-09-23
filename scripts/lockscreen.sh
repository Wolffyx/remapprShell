#!/usr/bin/env bash
# The lock screen: ours, drawn by Plasma's own greeter, and off by default.
#
#   status [--json]   what is installed, what was tried, what will be drawn
#   check [--all]     load it in Plasma's greeter, offscreen and off the bus,
#                     and say what the greeter said; --all loads every style
#   try               show it for real, in the greeter's testing mode, and
#                     unlock it with your password -- that is the test
#   enable            put it in this shell's packages; refused until `try`
#                     has unlocked this exact build, in this greeter
#   disable           take it out; Plasma's lock screen from the next lock
#   set <key> <value> how it looks: style, clock, blur, media, session, idleClock,
#                     accent, dim, unlockAnimation, hibernateAt, kioskName, kioskNote
#
# The look settings go into kscreenlockerrc under the greeter's own group,
# because the greeter is where they are read: it runs as its own process with
# none of this shell's configuration, and builds its `config` object from the
# package's config.xml. Written through the ledger, like every other KDE key
# this project touches.
#
# A lock screen is the one thing this project ships that cannot be put right
# from inside the session it breaks. So nothing reaches the screen locker
# without passing through `try`, and the only way through `try` is the
# greeter's own exit status, which is 0 only once its authenticator says the
# password was right. What `enable` installs is the copy that was tried. The
# greeter it was tried with is part of the record, so an updated kscreenlocker
# means trying again before enabling -- and `doctor` says so of one already on.
#
# `disable` needs no session, no display and no bus. It is written to be run
# from a text console, because that is where it will be needed if it is.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/render.sh"
source "$REPO_ROOT/scripts/lib/kconfig.sh"
source "$REPO_ROOT/scripts/lib/lockscreen.sh"

# How long `try` leaves the lock screen up. The greeter covers every screen
# and takes the keyboard, test or not, so a lock screen that cannot unlock
# would trap its own test; this is what ends it.
TRY_SECONDS_VAR="${ENV_PREFIX}_LOCKSCREEN_TRY_SECONDS"
TRY_SECONDS=${!TRY_SECONDS_VAR:-90}

live_shell_package() {
    kreadconfig6 --file plasmashellrc --group Shell --key ShellPackage --default 'org.kde.plasma.desktop' 2>/dev/null
}

is_ours() {
    local p
    for p in "${LOCKSCREEN_PACKAGES[@]}"; do [ "$p" = "$1" ] && return 0; done
    return 1
}

mark_field() { jq -r --arg f "$1" '.[$f] // empty' "$LOCKSCREEN_MARK" 2>/dev/null; }

# The graphical session, for the way back: the one to unlock from a console,
# and the virtual terminal to return to.
graphical_session() {
    local s=${XDG_SESSION_ID:-}
    [ -n "$s" ] || s=$(loginctl show-user "$(id -un)" -p Display --value 2>/dev/null)
    printf '%s' "$s"
}

way_back() {
    local sid vt
    sid=$(graphical_session)
    vt=$(loginctl show-session "$sid" -p VTNr --value 2>/dev/null)
    cat <<EOF

If it ever will not let you in:
  1. press Ctrl+Alt+F3 and log in there
  2. loginctl unlock-session ${sid:-<session>}      (or: loginctl unlock-sessions)
  3. $ALIAS lockscreen disable
  4. Ctrl+Alt+F${vt:-1} goes back to the desktop
EOF
}

# What the lock screen's look is made of, and where each setting is kept.
#
# Two stores, because the greeter reads two things. Plasma's own settings
# reach it as its `config` object, out of kscreenlockerrc -- and only Plasma's:
# measured on 6.7.5, that object is built from the *desktop* package's
# lockscreen/config.xml, not from the package being drawn, so a key of ours
# added there would never arrive. This shell's own settings therefore live in
# a file of their own, which the lock screen reads directly (Options.qml).
#
# id | key | kind | choices | default | store | inverted
LOOK_KEYS=(
    "style|style|enum|glass editorial console ambient board poster seats minimal dayahead secure accessible kiosk|glass|ours|"
    "clock|clockPosition|enum|left center|left|ours|"
    "blur|wallpaperBlur|int|0 40|26|ours|"
    "session|showSessionButtons|bool||true|ours|"
    "accent|accent|enum|indigo terracotta green violet|indigo|ours|"
    "dim|dimSeconds|int|0 600|20|ours|"
    "unlockAnimation|unlockAnimation|bool||true|ours|"
    "hibernateAt|hibernateAt|int|0 10|3|ours|"
    "kioskName|kioskName|text|||ours|"
    "kioskNote|kioskNote|text|||ours|"
    "media|showMediaControls|bool||true|plasma|"
    "idleClock|hideClockWhenIdle|bool||true|plasma|invert"
)
# KConfigLoader nests the kcfg's own group inside the greeter's, so the keys
# Plasma reads are under [Greeter][LnF][General] -- found by giving the real
# greeter a config and asking it what it got, not by guessing.
PLASMA_LOOK_GROUP=(--group Greeter --group LnF --group General)
PLASMA_LOOK_LEDGER_GROUP="Greeter/LnF/General"
OURS_FILE="$CONFIG_DIR/lockscreen.conf"

look_spec() {
    local want=$1 spec
    for spec in "${LOOK_KEYS[@]}"; do
        [ "${spec%%|*}" = "$want" ] && { printf '%s' "$spec"; return 0; }
    done
    return 1
}

# The stored value, as a person set it: an inverted key (Plasma asks whether
# to *hide* the clock; this asks whether to show it) is turned back here.
look_read() {
    local spec=$1 id key kind choices fallback store invert raw stored
    IFS='|' read -r id key kind choices fallback store invert <<< "$spec"
    raw=$fallback
    [ "$invert" = invert ] && raw=$([ "$fallback" = true ] && echo false || echo true)
    if [ "$store" = plasma ]; then
        stored=$(kreadconfig6 --file kscreenlockerrc "${PLASMA_LOOK_GROUP[@]}" --key "$key" --default "$raw")
    else
        stored=$(kreadconfig6 --file "$OURS_FILE" --group Lock --key "$key" --default "$raw")
    fi
    if [ "$invert" = invert ]; then
        [ "$stored" = true ] && printf 'false' || printf 'true'
    else
        printf '%s' "$stored"
    fi
}

look_write() {
    local spec=$1 value=$2 id key kind choices fallback store invert written
    IFS='|' read -r id key kind choices fallback store invert <<< "$spec"
    written=$value
    [ "$invert" = invert ] && written=$([ "$value" = true ] && echo false || echo true)
    if [ "$store" = plasma ]; then
        # Plasma's own key, so through the ledger like every other KDE key.
        kconfig_set lockscreen kscreenlockerrc "$PLASMA_LOOK_LEDGER_GROUP" "$key" "$written"
    else
        mkdir -p "$(dirname "$OURS_FILE")"
        kwriteconfig6 --file "$OURS_FILE" --group Lock --key "$key" "$written"
    fi
}

look_json() {
    local spec id key kind choices fallback store invert out=""
    for spec in "${LOOK_KEYS[@]}"; do
        IFS='|' read -r id key kind choices fallback store invert <<< "$spec"
        out+=$(jq -n -c --arg id "$id" --arg key "$key" --arg kind "$kind" --arg store "$store" \
                        --arg value "$(look_read "$spec")" --arg default "$fallback" \
                        --arg choices "$choices" \
            '{id: $id, key: $key, kind: $kind, store: $store, value: $value, default: $default,
              choices: ($choices | split(" ") | map(select(length > 0)))}')
    done
    printf '%s' "$out" | jq -s -c .
}

status_json() {
    local greeter="" gid="" pkgs="" p dest h live
    greeter=$(lockscreen_greeter) && gid=$(lockscreen_greeter_id "$greeter")
    for p in "${LOCKSCREEN_PACKAGES[@]}"; do
        dest=$(lockscreen_installed_dir "$p")
        h=""
        [ -f "$dest/$LOCKSCREEN_MARKER" ] && h=$(cat "$dest/$LOCKSCREEN_MARKER")
        pkgs+=$(jq -n -c --arg id "$p" --arg hash "$h" \
                    --argjson present "$([ -d "$PLASMA_SHELLS_DIR/$p" ] && echo true || echo false)" \
                    --argjson foreign "$([ -e "$dest" ] && [ ! -f "$dest/$LOCKSCREEN_MARKER" ] && echo true || echo false)" \
                    '{id: $id, present: $present, installed: ($hash != ""), hash: $hash, foreign: $foreign}')$'\n'
    done
    live=$(live_shell_package)
    jq -n -c \
        --arg source "$(lockscreen_hash "$LOCKSCREEN_SRC" 2>/dev/null)" \
        --argjson tried "$( [ -f "$LOCKSCREEN_MARK" ] && jq -c . "$LOCKSCREEN_MARK" 2>/dev/null || echo null)" \
        --arg greeter "$greeter" --arg greeterId "$gid" \
        --argjson enabled "$(lockscreen_enabled && echo true || echo false)" \
        --argjson packages "$(printf '%s' "$pkgs" | jq -s -c .)" \
        --arg live "$live" \
        --argjson liveIsOurs "$(is_ours "$live" && echo true || echo false)" \
        --argjson look "$(look_json)" \
        '{source: $source, look: $look, tried: $tried, greeter: $greeter, greeterId: $greeterId, enabled: $enabled,
          packages: $packages, live: $live, liveIsOurs: $liveIsOurs,
          triedIsSource: ($tried != null and $tried.hash == $source),
          triedWithThisGreeter: ($tried != null and $tried.greeter == $greeterId),
          drawn: (if ($liveIsOurs and ([$packages[] | select(.id == $live and .installed)] | length > 0))
                  then "ours" else "plasma" end)}'
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
        s=$(status_json)
        printf 'drawn at the next lock: %s\n' \
            "$(jq -r 'if .drawn == "ours" then "ours" else "Plasma'"'"'s" end' <<< "$s")"
        printf 'enabled:                %s\n' "$(jq -r 'if .enabled then "yes" else "no" end' <<< "$s")"
        printf 'plasmashell is on:      %s%s\n' "$(jq -r .live <<< "$s")" \
            "$(jq -r 'if .liveIsOurs then " (ours)" else " (not ours: its own lock screen is drawn)" end' <<< "$s")"
        jq -r '.packages[] | "  \(.id): " + (if .installed then "installed (\(.hash))"
                                              elif .foreign then "a lock screen that is not ours"
                                              elif .present then "not installed" else "package not installed" end)' <<< "$s"
        if jq -e '.tried' <<< "$s" >/dev/null; then
            printf 'tried:                  %s, build %s%s\n' "$(jq -r .tried.at <<< "$s")" "$(jq -r .tried.hash <<< "$s")" \
                "$(jq -r 'if .tried.release != "" then " (kscreenlocker \(.tried.release))" else "" end' <<< "$s")"
            jq -e '.triedWithThisGreeter' <<< "$s" >/dev/null \
                || echo "                        with a different greeter from this one: try it again before enabling"
            jq -e '.triedIsSource' <<< "$s" >/dev/null \
                || echo "                        the source has changed since: try it again to use the change"
        else
            echo "tried:                  never ($ALIAS lockscreen try)"
        fi
        ;;

    check)
        # --all loads every style in turn, not only the one picked: a style
        # nobody has chosen yet is still one somebody can choose.
        if [ "${1:-}" = "--all" ]; then
            src=${2:-$LOCKSCREEN_SRC}
            spec=$(look_spec style)
            IFS='|' read -r _ _ _ styles _ <<< "$spec"
            failed=0
            for st in $styles; do
                if out=$(lockscreen_check "$src" 15 "$st"); then
                    log_step "$st: loads"
                else
                    log_warn "$st: does not load cleanly"
                    printf '%s\n' "$out" | sed 's/^/    /' >&2
                    failed=1
                fi
            done
            [ "$failed" = 0 ] || die "not every style loads cleanly"
            exit 0
        fi
        src=${1:-$LOCKSCREEN_SRC}
        if out=$(lockscreen_check "$src"); then
            log_step "it loads in Plasma's greeter and found everything it needs"
        else
            printf '%s\n' "$out" >&2
            die "it does not load cleanly"
        fi
        ;;

    try)
        session_available || die "try shows the lock screen on the desktop, which this run may not touch ($NO_SESSION_VAR is set)"
        [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] || die "try needs the desktop: run it from a terminal inside the session"
        greeter=$(lockscreen_greeter) || die "Plasma's greeter (kscreenlocker_greet) was not found"

        log_step "loading it offscreen first"
        out=$(lockscreen_check "$LOCKSCREEN_SRC") || { printf '%s\n' "$out" >&2; die "it does not load cleanly; not showing it"; }

        mkdir -p "$LOCKSCREEN_STATE"
        candidate="$LOCKSCREEN_STATE/candidate"
        rm -rf "$candidate"
        lockscreen_package "$candidate" "$LOCKSCREEN_SRC" || die "could not build the package to show"

        cat <<EOF

The lock screen will cover every screen and take the keyboard, as it does when
the session is locked -- but nothing is locked: this is the greeter's testing
mode, and it ends when it is unlocked.

    Unlock it with your password. That is the test.

A wrong password counts against the account as it would at the real lock
screen. If it will not unlock, it closes by itself after ${TRY_SECONDS} seconds and
nothing is recorded.

EOF
        if [ -t 0 ]; then
            read -r -p "Press Enter to show it, or Ctrl+C to leave it: " _ || exit 1
        fi

        timeout "$TRY_SECONDS" "$greeter" --testing --shell "$candidate" > "$LOCKSCREEN_STATE/try.log" 2>&1
        rc=$?
        case "$rc" in
            0)
                rm -rf "$LOCKSCREEN_TRIED"
                cp -a "$candidate/contents/lockscreen" "$LOCKSCREEN_TRIED" || die "could not keep the tried copy"
                jq -n --arg hash "$(lockscreen_hash "$LOCKSCREEN_TRIED")" \
                      --arg greeter "$(lockscreen_greeter_id "$greeter")" \
                      --arg release "$(lockscreen_greeter_release)" \
                      --arg at "$(date -Iseconds)" \
                      '{hash: $hash, greeter: $greeter, release: $release, at: $at}' > "$LOCKSCREEN_MARK" \
                    || die "could not record the test"
                log_step "unlocked with your password: build $(mark_field hash) is tried"
                if lockscreen_enabled && [ "$(cat "$LOCKSCREEN_ENABLED")" != "$(mark_field hash)" ]; then
                    log_info "the enabled lock screen is an older build; '$ALIAS lockscreen enable' replaces it"
                else
                    log_info "turn it on with: $ALIAS lockscreen enable"
                fi
                ;;
            124)
                die "it was not unlocked within ${TRY_SECONDS} seconds; nothing was recorded (greeter output: $LOCKSCREEN_STATE/try.log)"
                ;;
            *)
                die "the greeter ended with status $rc without unlocking; nothing was recorded (its output: $LOCKSCREEN_STATE/try.log)"
                ;;
        esac
        ;;

    enable)
        [ -f "$LOCKSCREEN_MARK" ] && [ -d "$LOCKSCREEN_TRIED" ] \
            || die "it has not been tried: run '$ALIAS lockscreen try' first, and unlock it with your password"
        hash=$(mark_field hash)
        [ "$(lockscreen_hash "$LOCKSCREEN_TRIED")" = "$hash" ] \
            || die "the tried copy has changed since it was tried; run '$ALIAS lockscreen try' again"
        greeter=$(lockscreen_greeter) || die "Plasma's greeter (kscreenlocker_greet) was not found"
        [ "$(lockscreen_greeter_id "$greeter")" = "$(mark_field greeter)" ] \
            || die "Plasma's greeter has changed since it was tried (an update to kscreenlocker?); run '$ALIAS lockscreen try' again"
        out=$(lockscreen_check "$LOCKSCREEN_TRIED") || { printf '%s\n' "$out" >&2; die "the tried copy does not load cleanly in this greeter"; }

        installed=0
        for p in "${LOCKSCREEN_PACKAGES[@]}"; do
            lockscreen_install_into "$p"
            case $? in
                0) installed=$((installed + 1)); log_step "installed in $p" ;;
                2) log_info "$p is not installed; it gets the lock screen when it is" ;;
                *) die "could not install it in $p" ;;
            esac
        done
        [ "$installed" -gt 0 ] || die "none of this shell's packages is installed, so there is nothing to put it in ($ALIAS renderer status)"
        printf '%s\n' "$hash" > "$LOCKSCREEN_ENABLED"

        [ "$(lockscreen_hash "$LOCKSCREEN_SRC" 2>/dev/null)" = "$hash" ] \
            || log_warn "the source has changed since it was tried; the copy that was tried is what is on"
        live=$(live_shell_package)
        if is_ours "$live"; then
            log_step "on: the greeter draws it from the next lock"
        else
            log_info "installed, but plasmashell is on $live, and that package's lock screen is the one drawn"
        fi
        way_back
        ;;

    set)
        id=${1:-}; value=${2:-}
        spec=$(look_spec "$id") || die "unknown setting: '$id' (expected: $(printf '%s ' "${LOOK_KEYS[@]%%|*}"))"
        IFS='|' read -r _id key kind choices fallback store invert <<< "$spec"
        case "$kind" in
            bool) [ "$value" = true ] || [ "$value" = false ] || die "$id takes true or false" ;;
            int)  [[ "$value" =~ ^[0-9]+$ ]] || die "$id takes a number"
                  lo=${choices%% *}; hi=${choices##* }
                  [ "$value" -ge "$lo" ] && [ "$value" -le "$hi" ] || die "$id takes $lo..$hi" ;;
            enum) printf '%s\n' $choices | grep -qxF "$value" || die "$id takes one of: $choices" ;;
            # One line, drawn as it is written: a newline would be a second
            # key to KConfig, and a lock screen is no place for an essay.
            text) [[ "$value" != *$'\n'* ]] || die "$id takes one line"
                  [ "${#value}" -le 120 ] || die "$id takes at most 120 characters" ;;
        esac

        if [ "$(look_read "$spec")" = "$value" ]; then
            log_info "$id is already $value"
            exit 0
        fi
        look_write "$spec" "$value"
        log_step "$id: $value"
        lockscreen_enabled || log_info "  it applies when this lock screen is turned on"
        ;;

    disable)
        removed=0
        for p in "${LOCKSCREEN_PACKAGES[@]}"; do
            lockscreen_remove_from "$p"
            case $? in
                0) removed=$((removed + 1)); log_step "removed from $p" ;;
                2) log_warn "$(lockscreen_installed_dir "$p") is not ours; left alone" ;;
            esac
        done
        rm -f "$LOCKSCREEN_ENABLED"
        log_step "off: Plasma's lock screen from the next lock"
        ;;

    *) die "unknown command: $cmd (expected status, check, try, enable or disable)" ;;
esac
