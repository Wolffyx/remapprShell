#!/usr/bin/env bash
# The window list: KWin's script, and the daemon it reports to.
#
#   enable    install and load the KWin script
#   disable   unload and remove it
#   status    what is installed, loaded and reporting
#   restart   start the daemon again, so it is the copy on disk
#   show      the windows as the daemon currently has them
#   close ID  close one window, by the uuid the list reports -- what the task
#             list's "Close window" runs
#   pointer ACTION
#             open one of this shell's surfaces where the pointer is --
#             clipboard, or sidebar, which then comes out of the screen the
#             pointer is on rather than the first one. Wayland tells a client
#             the pointer's position only over its own windows, so KWin is
#             asked: a one-shot script reads workspace.cursorPos and hands it
#             to the session daemon, which passes it to the shell
#
#   behaviour status [--json]     what KWin does with windows: how focus is
#                                 given, whether hovering raises, whether a
#                                 maximised window keeps its border
#   behaviour set <key> <value>   one of those, written to kwinrc through the
#                                 ledger, and KWin asked to read it again
#   behaviour revert              put every one of them back
#
# The behaviour half configures KWin and reimplements nothing: these are the
# keys System Settings' "Window Behaviour" page writes, and the ones a shell
# can honestly offer. What KWin does not have -- window gaps, rounded window
# corners, a tiling layout -- is not offered here, however much a mockup of
# another desktop's shell may show it.
#
# Why any of this exists is written at the top of bin/windowsd.py.in. The short
# version: KWin is the only thing that knows what windows exist, a KWin script
# is the only supported way to read that without a C++ effect, and a script can
# only *call* DBus -- so it calls a small daemon, which the shell listens to.
#
# Opt-in, like every other thing here that touches KDE. Nothing is loaded until
# this is run, and `disable` puts it all back.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/render.sh"
source "$REPO_ROOT/scripts/lib/kconfig.sh"
source "$REPO_ROOT/scripts/lib/kwin.sh"

SCRIPT_SRC="$REPO_ROOT/kwin/windows"
SCRIPT_DEST="$KWIN_SCRIPTS_DIR/$KWIN_SCRIPT_ID"

kwin_script() {
    session_available || return 1
    qdbus6 org.kde.KWin /Scripting "org.kde.kwin.Scripting.$1" "${@:2}" 2>/dev/null
}

install_script() {
    mkdir -p "$SCRIPT_DEST/contents/code"
    render_template "$SCRIPT_SRC/metadata.json.in" "$SCRIPT_DEST/metadata.json" \
        || { log_error "could not render the script metadata"; return 1; }
    render_template "$SCRIPT_SRC/contents/code/main.js.in" "$SCRIPT_DEST/contents/code/main.js" \
        || { log_error "could not render the script"; return 1; }
    chmod 644 "$SCRIPT_DEST/metadata.json" "$SCRIPT_DEST/contents/code/main.js"
    log_step "installed $SCRIPT_DEST"
}

cmd=${1:-status}
[ $# -gt 0 ] && shift

case "$cmd" in
    enable)
        install_script || die "nothing was loaded"

        # KWin reads its plugin list from kwinrc, which is what makes the
        # script come back after a login. Through the ledger, so `disable`
        # restores whatever was there -- including "the key was never set".
        kconfig_set windows kwinrc Plugins "${KWIN_SCRIPT_ID}Enabled" true

        if ! session_available; then
            log_info "not loading it now: no session"
            exit 0
        fi

        # Unloaded first, because KWin ignores loading a script it already has
        # -- so without this, re-running `enable` after changing the script
        # silently keeps running the old one, which is a confusing thing to
        # debug.
        kwin_script unloadScript "$KWIN_SCRIPT_ID" >/dev/null
        kwin_script loadScript "$SCRIPT_DEST/contents/code/main.js" "$KWIN_SCRIPT_ID" >/dev/null
        kwin_script start >/dev/null

        if [ "$(kwin_script isScriptLoaded "$KWIN_SCRIPT_ID")" = "true" ]; then
            log_step "the window list is running"
        else
            log_warn "KWin did not report the script as loaded"
            log_info "  it is enabled in kwinrc and will load at the next login"
            log_info "  see why: journalctl --user -u plasma-kwin_wayland.service -n 30"
        fi
        ;;

    disable)
        kwin_script unloadScript "$KWIN_SCRIPT_ID" >/dev/null
        kconfig_revert windows
        if [ -d "$SCRIPT_DEST" ]; then
            rm -rf "$SCRIPT_DEST"
            log_step "removed $SCRIPT_DEST"
        fi
        # The daemon is started on demand by the bus and has nothing to do
        # once nothing pushes to it, so it is left to exit on its own with the
        # session rather than being killed here.
        log_step "the window list is off"
        ;;

    status)
        printf 'script:    %s\n' "$([ -d "$SCRIPT_DEST" ] && echo "installed ($SCRIPT_DEST)" || echo "not installed")"
        printf 'in kwinrc: %s\n' "$(kreadconfig6 --file kwinrc --group Plugins --key "${KWIN_SCRIPT_ID}Enabled" --default '<unset>')"
        printf 'loaded:    %s\n' "$(kwin_script isScriptLoaded "$KWIN_SCRIPT_ID" 2>/dev/null || echo 'unknown')"
        printf 'daemon:    %s\n' "$(busctl --user --json=short list 2>/dev/null | grep -c "$DBUS_NAME" >/dev/null && echo 'on the bus' || echo 'not running (it starts when something calls it)')"
        printf 'windows:   %s\n' "$("$0" show 2>/dev/null | wc -l)"
        ;;

    # The daemon is started by the bus, not by the shell's unit, so it outlives
    # `systemctl --user restart` and every other way of restarting the shell.
    # That is right -- the KWin script must be able to reach it before the
    # shell exists -- and it is a trap after an update: the file on disk is new
    # and the process is the one that started with the session. Found on
    # 2026-09-23, when an icon fix appeared to do nothing three times over.
    #
    # Killed rather than stopped: there is no unit to stop. The next call on
    # the bus starts it again, which is what the List below is for -- without
    # it the daemon comes back only at the next window change, and the task
    # list is empty until then.
    restart)
        pkill -f "$BIN_DIR/$WINDOWSD_BIN" 2>/dev/null || true
        sleep 1
        busctl --user --json=short call "$DBUS_NAME" /Windows "$DBUS_NAME.Windows" List >/dev/null 2>&1 || true
        log_step "the window daemon is the one on disk now"
        log_info "its window list fills in at the next window change; open and close something to hurry it"
        ;;

    show)
        busctl --user --json=short call "$DBUS_NAME" /Windows "$DBUS_NAME.Windows" List 2>/dev/null \
            | jq -r '.data[0] | fromjson | .[] | "\(if .active then "*" else " " end) \(if .minimized then "_" else " " end) \(.appId)  \(.title)"' \
            || log_info "nothing yet"
        ;;

    # The pointer, from the only process that knows where it is. The action
    # name goes into the script's source, so it is checked against the list
    # the daemon accepts rather than passed through.
    pointer)
        action=${1:-}
        case "$action" in
            clipboard|sidebar) ;;
            *) die "not an action that opens under the pointer: '${action:-}' (one of: clipboard sidebar)" ;;
        esac
        session_available || die "no session to read the pointer in"

        name="${KWIN_SCRIPT_ID}-pointer"
        file=$(mktemp --suffix=.js "${XDG_RUNTIME_DIR:-/tmp}/${KWIN_SCRIPT_ID}-pointer.XXXXXX") \
            || die "could not write the script"
        trap 'rm -f "$file"' EXIT
        cat > "$file" <<JS
const pos = workspace.cursorPos;
let output = "";
for (const screen of workspace.screens) {
    const g = screen.geometry;
    if (pos.x >= g.x && pos.x < g.x + g.width && pos.y >= g.y && pos.y < g.y + g.height) {
        output = String(screen.name);
        break;
    }
}
callDBus("$DBUS_NAME", "/Pointer", "$DBUS_NAME.Pointer", "At",
         "$action", Math.round(pos.x), Math.round(pos.y), output);
JS
        kwin_script unloadScript "$name" >/dev/null
        kwin_script loadScript "$file" "$name" >/dev/null || die "KWin did not load the script"
        kwin_script start >/dev/null
        # Long enough for the call to leave KWin, short enough not to be felt
        # on a key press. The script is taken away again either way: a loaded
        # script that has already run is a name in KWin's list and nothing more.
        sleep 0.2
        kwin_script unloadScript "$name" >/dev/null
        ;;

    close)
        # KWin offers no call that closes a window by id, so this loads a
        # one-shot script that finds the window and asks it to close -- the
        # request its close button makes, so an application with unsaved work
        # can still ask. The id goes into the script's source, which is why it
        # must be exactly a uuid and nothing else.
        uuid=${1:-}
        [[ "$uuid" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]] \
            || die "not a window id: '$uuid'"
        session_available || die "no session to close a window in"

        name="${KWIN_SCRIPT_ID}-close-$uuid"
        file=$(mktemp --suffix=.js "${XDG_RUNTIME_DIR:-/tmp}/${KWIN_SCRIPT_ID}-close.XXXXXX") \
            || die "could not write the script"
        trap 'rm -f "$file"' EXIT
        cat > "$file" <<JS
const id = "$uuid";
for (const w of workspace.windowList()) {
    if (String(w.internalId).replace(/[{}]/g, "") === id) {
        w.closeWindow();
        break;
    }
}
JS
        kwin_script unloadScript "$name" >/dev/null
        kwin_script loadScript "$file" "$name" >/dev/null || die "KWin did not load the script"
        kwin_script start >/dev/null
        # Let it run before it is taken away again.
        sleep 0.3
        kwin_script unloadScript "$name" >/dev/null
        ;;


    # KWin's own window behaviour: the keys System Settings writes, through
    # the ledger so every one of them can be put back.
    #
    # id | group | key | kind | choices (for an enum) | default when unset
    behaviour)
        BEHAVIOUR_KEYS=(
            "focus|Windows|FocusPolicy|enum|ClickToFocus FocusFollowsMouse FocusUnderMouse FocusStrictlyUnderMouse|ClickToFocus"
            "focusDelay|Windows|DelayFocusInterval|int|0 3000|300"
            "autoRaise|Windows|AutoRaise|bool||false"
            "autoRaiseDelay|Windows|AutoRaiseInterval|int|0 3000|750"
            "borderlessMaximized|Windows|BorderlessMaximizedWindows|bool||false"
            "placement|Windows|Placement|enum|Smart Centered Maximizing Random ZeroCornered UnderMouse|Smart"
        )

        behaviour_spec() {
            local want=$1 spec
            for spec in "${BEHAVIOUR_KEYS[@]}"; do
                [ "${spec%%|*}" = "$want" ] && { printf '%s' "$spec"; return 0; }
            done
            return 1
        }

        behaviour_read() {
            local spec=$1
            IFS='|' read -r _id group key _kind _choices fallback <<< "$spec"
            kreadconfig6 --file kwinrc --group "$group" --key "$key" --default "$fallback"
        }

        sub=${1:-status}
        [ $# -gt 0 ] && shift

        case "$sub" in
            status)
                if [ "${1:-}" = "--json" ]; then
                    entries=""
                    for spec in "${BEHAVIOUR_KEYS[@]}"; do
                        IFS='|' read -r id group key kind choices fallback <<< "$spec"
                        entries+=$(jq -n --arg id "$id" --arg key "$key" --arg kind "$kind" \
                                         --arg value "$(behaviour_read "$spec")" --arg default "$fallback" \
                                         --arg choices "$choices" \
                            '{id: $id, key: $key, kind: $kind, value: $value, default: $default,
                              choices: ($choices | split(" ") | map(select(length > 0)))}')
                    done
                    printf '%s' "$entries" | jq -s --arg scripts "$(kwin_tiling_scripts)" \
                        '{settings: ., tilingScripts: ($scripts | split("\n") | map(select(length > 0)))}'
                else
                    for spec in "${BEHAVIOUR_KEYS[@]}"; do
                        printf '%-20s %s\n' "${spec%%|*}" "$(behaviour_read "$spec")"
                    done
                    scripts=$(kwin_tiling_scripts | tr '\n' ' ')
                    if [ -n "$scripts" ]; then
                        printf '%-20s %s\n' "tiling script" "$scripts"
                    fi
                fi
                ;;

            set)
                id=${1:-}; value=${2:-}
                spec=$(behaviour_spec "$id") || die "unknown setting: '$id' (expected: $(printf '%s ' "${BEHAVIOUR_KEYS[@]%%|*}"))"
                IFS='|' read -r _id group key kind choices fallback <<< "$spec"
                case "$kind" in
                    bool) [ "$value" = true ] || [ "$value" = false ] || die "$id takes true or false" ;;
                    int)  [[ "$value" =~ ^[0-9]+$ ]] || die "$id takes a number of milliseconds"
                          lo=${choices%% *}; hi=${choices##* }
                          [ "$value" -ge "$lo" ] && [ "$value" -le "$hi" ] || die "$id takes $lo..$hi" ;;
                    enum) printf '%s\n' $choices | grep -qxF "$value" || die "$id takes one of: $choices" ;;
                esac
                [ "$(kreadconfig6 --file kwinrc --group "$group" --key "$key" --default "$fallback")" = "$value" ] && {
                    log_info "$id is already $value"
                    exit 0
                }
                kconfig_set windows-behaviour kwinrc "$group" "$key" "$value"
                kwin_reconfigure
                log_step "$id: $value"
                ;;

            revert)
                kconfig_revert windows-behaviour
                kwin_reconfigure
                log_step "KWin's window behaviour is back as it was"
                ;;

            *) die "unknown command: behaviour $sub (expected status, set or revert)" ;;
        esac
        ;;

    *) die "unknown command: $cmd (expected enable, disable, status, show, close or behaviour)" ;;
esac
