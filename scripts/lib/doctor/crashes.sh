# shellcheck shell=bash
# Quickshell's crash dumps from this shell, and whether the newest has a
# report.
#
# A section of doctor.sh, which sources it and supplies ok, warn, bad, fix and
# section. Requires brand.sh, crashes.sh and reports.sh.

doctor_crashes() {
    local crash_count newest newest_when reported
    section "crashes"

    crash_count=$(crash_list | wc -l)
    if [ "$crash_count" -eq 0 ]; then
        ok "no crash dumps from this shell"
    else
        newest=$(crash_newest)
        newest_when=$(crash_list | tail -1 | cut -f2)
        # Not a failure on its own: a dump from before an update is history, and
        # the shell has been restarting itself through all of them.
        warn "$crash_count crash dump(s); the newest is $newest ($newest_when)"
        fix "quickshell catches these itself and restarts, so systemd never reports a failure"
        fix "read it:       $ALIAS crash show"
        fix "ask about it:  $ALIAS ask --crash"
        reported=$(report_for_crash "$newest")
        if [ -n "$reported" ]; then
            ok "the newest crash has a report: $(basename "$reported")"
        else
            warn "no report written for the newest crash"
            fix "the shell writes one when it comes back; this dump predates that, or the shell has not restarted since"
            fix "write one now: $ALIAS report create --crash $newest"
        fi
        fix "clear them:    $ALIAS crash remove --all"
    fi
}
