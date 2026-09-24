# shellcheck shell=bash
# The shell's systemd unit: whether it runs, and how often it has restarted.
#
# A section of doctor.sh, which sources it and supplies ok, warn, bad, fix and
# section. Requires brand.sh.

doctor_service() {
    local state restarts
    section "service"

    if systemctl --user cat "$SYSTEMD_UNIT" >/dev/null 2>&1; then
        state=$(systemctl --user is-active "$SYSTEMD_UNIT" 2>/dev/null || true)
        case "$state" in
            active) ok "service is running" ;;
            failed) bad "service has failed"
                    fix "see why: $ALIAS log -n 50" ;;
            *)      warn "service is $state"
                    fix "start it: $ALIAS start" ;;
        esac

        restarts=$(systemctl --user show "$SYSTEMD_UNIT" -p NRestarts --value 2>/dev/null || echo 0)
        if [ "${restarts:-0}" -gt 3 ]; then
            warn "the service has restarted $restarts times"
            fix "a widget may be crashing it: $ALIAS log -n 100"
        fi
    else
        warn "no systemd unit installed"
        fix "run: make link"
    fi
}
