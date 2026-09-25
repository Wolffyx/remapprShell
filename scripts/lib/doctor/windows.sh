# shellcheck shell=bash
# The window list -- the KWin script and the session daemon behind the open-
# windows widget -- and whether the daemon running is the one installed.
#
# A section of doctor.sh, which sources it and supplies ok, warn, bad, fix and
# section. Requires brand.sh, kwin.sh and config.sh.

doctor_windows() {
    local profile_entries defaults_file script_loaded daemon_answers count
    section "open windows"

    defaults_file="$DATA_DIR/config/defaults/shell.json"

    profile_entries=$(jq -r '[.bar.entries[]? | select(.enabled != false) | .id] | join(" ")' \
        "$(profile_file)" 2>/dev/null || echo "")
    [ -n "$profile_entries" ] || profile_entries=$(jq -r '[.bar.entries[]? | select(.enabled != false) | .id] | join(" ")' \
        "$defaults_file" 2>/dev/null || echo "")

    script_loaded=$(kwin_scripting isScriptLoaded "$KWIN_SCRIPT_ID" || echo unknown)
    daemon_answers=no
    busctl --user --json=short call "$DBUS_NAME" /Windows "$DBUS_NAME.Windows" List >/dev/null 2>&1 && daemon_answers=yes

    case " $profile_entries " in
        *" tasks "*)
            if [ "$script_loaded" = "true" ] && [ "$daemon_answers" = yes ]; then
                count=$(busctl --user --json=short call "$DBUS_NAME" /Windows "$DBUS_NAME.Windows" List 2>/dev/null \
                        | jq -r '.data[0] | fromjson | length' 2>/dev/null || echo '?')
                ok "the window list is running ($count window(s))"
            else
                bad "the panel has the open-windows widget, but the window list is off"
                fix "it will show nothing at all until the KWin script is loaded"
                fix "turn it on: $ALIAS windows enable"
            fi ;;
        *)
            if [ "$script_loaded" = "true" ]; then
                warn "the window list is running, but no panel widget shows it"
                fix "add the 'tasks' widget from the settings window, or: $ALIAS windows disable"
            else
                ok "the window list is off, and nothing asks for it"
            fi ;;
    esac
}

# The daemon on the bus, against the file it was installed from.
#
# It is started by the bus rather than by the shell's unit, so it outlives
# every way of restarting the shell -- which is right, because the KWin script
# must be able to reach it before the shell exists, and a trap after an update:
# the fix is on disk and the process is the one that started with the session.
# On 2026-09-23 that made an icon fix appear to do nothing three times over.
doctor_window_daemon() {
    local daemon_bin daemon_pid
    daemon_bin="$BIN_DIR/$WINDOWSD_BIN"
    daemon_pid=$(pgrep -f "$daemon_bin" 2>/dev/null | head -1)
    if [ -n "$daemon_pid" ] && [ -f "$daemon_bin" ]; then
        if [ "$daemon_bin" -nt "/proc/$daemon_pid" ]; then
            warn "the window daemon running is older than the one installed"
            fix "it is started by the bus, not by the shell's unit, so restarting the"
            fix "  shell leaves it exactly where it was"
            fix "start the one on disk: $ALIAS windows restart"
        else
            ok "the window daemon running is the one installed"
        fi
    fi
}
