# shellcheck shell=bash
# Another Quickshell shell as the renderer: started under our unit template,
# and stopped again when the panel is handed to anything else.
#
# Sourced by renderer.sh, never executed. Requires brand.sh, log.sh and
# renderers.sh.

# Started under our unit template, enabled so the next login starts it too.
start_foreign() {
    local name=$1 unit entry
    unit=$(renderer_unit "$name")
    session_available || { log_debug "not starting $unit: no session"; return 0; }
    systemctl --user daemon-reload >/dev/null 2>&1
    if systemctl --user enable --now "$unit" >/dev/null 2>&1; then
        log_step "started the $name configuration ($unit), and it starts with the session now"
    else
        log_warn "could not start $unit"
        log_info "  is it installed? make link puts the template in place; then: systemctl --user status $unit"
        return 1
    fi
    # Its own installer may have given it an autostart entry too. -n makes the
    # second start a no-op, but switching away cannot stop what that entry
    # brings back at the next login, so it is named now rather than then.
    if entry=$(renderer_autostart_entry "$name"); then
        log_info "  $entry also starts it at login; switching away will not stop that one"
    fi
}

# Every one of them but `keep`: whatever our template runs, and any instance of
# the configuration being left that something else started.
stop_foreign() {
    local keep=${1:-} leaving=${2:-} unit inst
    session_available || return 0
    while read -r unit; do
        [ -n "$unit" ] || continue
        inst=${unit#"$RENDERER_UNIT_TEMPLATE"}; inst=$(systemd-escape --unescape -- "${inst%.service}")
        [ -n "$keep" ] && [ "$inst" = "$keep" ] && continue
        systemctl --user disable --now "$unit" >/dev/null 2>&1 \
            && log_step "stopped the $inst configuration ($unit)" \
            || log_warn "could not stop $unit"
    done < <({ systemctl --user list-units --all --plain --no-legend "${RENDERER_UNIT_TEMPLATE}*" 2>/dev/null
               systemctl --user list-unit-files --plain --no-legend --state=enabled "${RENDERER_UNIT_TEMPLATE}*" 2>/dev/null
             } | awk '$1 !~ /@\.service$/ {print $1}' | sort -u)
    if [ -n "$leaving" ] && [ "$leaving" != "$keep" ]; then
        quickshell kill -c "$leaving" >/dev/null 2>&1 && log_step "stopped the running $leaving instance"
        if renderer_autostart_entry "$leaving" >/dev/null; then
            log_warn "$(renderer_autostart_entry "$leaving") will start $leaving again at the next login"
        fi
    fi
    return 0
}
