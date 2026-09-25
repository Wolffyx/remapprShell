# shellcheck shell=bash
# Plasma's tray-only services -- notifications and Klipper -- and which
# clipboard history Meta+V shows.
#
# A section of doctor.sh, which sources it and supplies ok, warn, bad, fix and
# section. Requires brand.sh, config.sh and renderers.sh.

doctor_plasma_services() {
    local merged_cfg live_pkg notif_server pair name what comm cfg clip_history
    local klipper_up
    section "Plasma services"

    merged_cfg=$(config_merged)

    # Plasma's notification server and Klipper live in its system tray, not in
    # plasmashell. Where there is no Plasma tray -- our own renderer -- they exist
    # only because the shell hosts them, and with no owner at all a notification
    # is not queued or shown anywhere: it is dropped.
    live_pkg=$(live_shell_package '')
    notif_server=$(jq -r '.notifications.server // "plasma"' <<< "$merged_cfg" 2>/dev/null)
    for pair in "org.freedesktop.Notifications:notifications" "org.kde.klipper:clipboard history"; do
        name=${pair%%:*}; what=${pair#*:}
        comm=$(bus_status_field "$name" Comm)
        # Asked to serve them itself, the shell waits for whoever holds the name
        # rather than taking it -- so the one thing worth saying is who that is.
        if [ "$name" = org.freedesktop.Notifications ] && [ "$notif_server" = shell ]; then
            if shell_holds_bus_name "$name"; then
                ok "notifications: served by this shell (notifications.server)"
                continue
            elif [ -n "$comm" ]; then
                warn "notifications.server is shell, but $comm holds the notification service"
                fix "the shell waits and takes over when it is let go of; until then $comm draws them"
                continue
            fi
        fi
        # plasmashell holding one of these while it is on our package holds a
        # leftover: the service was created by the previous package's tray and
        # outlived it, because switching packages live does not restart
        # plasmashell. The name is taken, so nothing else can serve it -- and for
        # notifications, the applet that draws popups is gone: they are accepted
        # and never shown.
        if [ "$comm" = plasmashell ] && [ "$live_pkg" = "$SHELL_PACKAGE_ID" ]; then
            if [ "$name" = org.freedesktop.Notifications ]; then
                bad "notifications: held by plasmashell with no notifications applet -- accepted, never shown"
            else
                warn "$what: held by plasmashell, left over from the previous panel"
            fi
            fix "restart plasmashell so the shell can host Plasma's own: systemctl --user restart plasma-plasmashell"
        elif [ "$comm" = quickshell ]; then
            # Ours is Quickshell too, and so is caelestia's bar: name the config.
            cfg=$(bus_status_field "$name" CommandLine \
                  | grep -o -- '-p [^ ]*' | sed 's/^-p //; s|/shell.qml$||; s|.*/||')
            ok "$what: provided by quickshell (${cfg:-unknown config})"
        elif [ -n "$comm" ]; then
            ok "$what: provided by $comm"
        elif [ "$name" = org.freedesktop.Notifications ]; then
            bad "nothing provides notifications: every notification sent now is dropped"
            fix "under the quickshell renderer the shell hosts Plasma's own: $ALIAS start (and services.hostPlasma on)"
        else
            warn "nothing provides $what"
            fix "the clipboard widget keeps a history of its own meanwhile; Plasma's comes back with the shell"
        fi
    done

    # Which clipboard history Meta+V actually shows, which is a setting and not
    # whoever happens to hold the name. Worth saying because the two differ where
    # it matters: Klipper's DBus hands out text only, so an image in its history
    # can be seen and never chosen.
    clip_history=$(jq -r '.clipboard.history // "own"' <<< "$merged_cfg" 2>/dev/null)
    klipper_up=$(busctl --user status org.kde.klipper >/dev/null 2>&1 && echo yes || echo no)
    case "$clip_history" in
        own)    ok "clipboard history shown: this shell's own (images can be chosen)" ;;
        plasma) if [ "$klipper_up" = yes ]; then
                    ok "clipboard history shown: Klipper's (clipboard.history), text only"
                else
                    warn "clipboard.history is 'plasma' and Klipper is not running: the menu is empty"
                    fix "ours has one meanwhile: $ALIAS settings services, clipboard.history 'own' or 'auto'"
                fi ;;
        auto)   if [ "$klipper_up" = yes ]; then
                    ok "clipboard history shown: Klipper's while it runs (clipboard.history auto) -- its images cannot be chosen"
                else
                    ok "clipboard history shown: this shell's own (Klipper is not running)"
                fi ;;
        *)      warn "clipboard.history is '$clip_history', which is not a value this knows"
                fix "one of: own, auto, plasma" ;;
    esac
}
