# shellcheck shell=bash
# Plasma's tray-only services -- notifications, Klipper, the device notifier
# -- handed between the shell and a Plasma tray around a switch.
#
# Sourced by renderer.sh, never executed. Requires brand.sh and log.sh.

# Under the quickshell renderer the shell hosts Plasma's notifications and
# clipboard applets with plasmawindowed, because nothing else would provide
# them (shell/domain/backend/PlasmaServices.qml). Any other renderer has a
# Plasma tray that is about to provide the same services, and a hosted copy
# still holding org.freedesktop.Notifications -- or running a second Klipper
# beside Plasma's -- would win against it. So the host goes first.
#
# Only when it really is hosting one of them: plasmawindowed is also what a
# widget's "..." button opens Plasma's applets in, and a window the user
# opened is not ours to close.
stop_hosted_services() {
    session_available || return 0
    local pid name owner
    pid=$(bus_status_field org.kde.plasmawindowed PID)
    [ -n "$pid" ] || return 0
    local hosting=0 it id
    for name in org.freedesktop.Notifications org.kde.klipper; do
        owner=$(bus_status_field "$name" PID)
        [ "$owner" = "$pid" ] && hosting=1
    done
    # The device notifier holds no bus name; its tray item, which only
    # --statusnotifier creates, says it is there.
    if [ "$hosting" = 0 ]; then
        while read -r it; do
            [ -n "$it" ] || continue
            id=$(busctl --user get-property "${it%%/*}" "/${it#*/}" org.kde.StatusNotifierItem Id 2>/dev/null \
                 | sed -e 's/^s "//' -e 's/"$//')
            [ "$id" = plasmawindowed_org.kde.plasma.devicenotifier ] && hosting=1
        done < <(busctl --user get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher \
                   org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems 2>/dev/null \
                 | grep -o '"[^"]*"' | tr -d '"')
    fi
    [ "$hosting" = 1 ] || return 0
    log_info "closing Plasma's applets hosted for the quickshell renderer (plasmawindowed, pid $pid);"
    log_info "  the new panel's tray provides notifications, the clipboard and the device notifier"
    kill "$pid" 2>/dev/null || true
}

# The same for this shell's own notification server (notifications.server
# "shell"): it holds the name the new panel's tray is about to want, and it
# lets go only when the shell reads the new renderer -- which is written after
# the switch. So it is asked to let go first, and given a moment to.
release_shell_notifications() {
    session_available || return 0
    ours() { shell_holds_bus_name org.freedesktop.Notifications; }
    ours || return 0
    quickshell ipc --path "$(shell_ipc_path)" call notifications release >/dev/null 2>&1 || true
    local i
    for i in 1 2 3 4 5 6 7 8 9 10; do
        ours || return 0
        sleep 0.2
    done
    log_warn "the shell did not let go of org.freedesktop.Notifications; the new tray may not get it"
}

# Whether plasmashell itself holds the notification or Klipper name -- which,
# once it is on our package, can only be a leftover from the previous one.
plasmashell_holds_tray_services() {
    session_available || return 1
    local shell name owner
    shell=$(bus_status_field org.kde.plasmashell PID)
    [ -n "$shell" ] || return 1
    for name in org.freedesktop.Notifications org.kde.klipper; do
        owner=$(bus_status_field "$name" PID)
        [ "$owner" = "$shell" ] && return 0
    done
    return 1
}

# The other direction: a switch to quickshell asks the running shell to look
# again at once, rather than wait for a bus name to change hands.
rehost_services() {
    session_available || return 0
    quickshell ipc --path "$(shell_ipc_path)" call services rehost >/dev/null 2>&1 || true
}
