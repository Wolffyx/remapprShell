#!/usr/bin/env bash
# The window list: KWin's script, and the daemon it reports to.
#
#   enable    install and load the KWin script
#   disable   unload and remove it
#   status    what is installed, loaded and reporting
#   show      the windows as the daemon currently has them
#   close ID  close one window, by the uuid the list reports -- what the task
#             list's "Close window" runs
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

    show)
        busctl --user --json=short call "$DBUS_NAME" /Windows "$DBUS_NAME.Windows" List 2>/dev/null \
            | jq -r '.data[0] | fromjson | .[] | "\(if .active then "*" else " " end) \(if .minimized then "_" else " " end) \(.appId)  \(.title)"' \
            || log_info "nothing yet"
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

    *) die "unknown command: $cmd (expected enable, disable, status, show or close)" ;;
esac
