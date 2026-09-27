# shellcheck shell=bash
# Diagnostic reports, and the unit that writes one when the shell dies.
#
# A section of doctor.sh, which sources it and supplies ok, warn, bad, fix and
# section. Requires brand.sh and reports.sh.

doctor_reports() {
    local report_count
    section "diagnostic reports"

    report_count=$(ls -1 "$REPORT_DIR" 2>/dev/null | wc -l)
    if [ "$report_count" -gt 0 ]; then
        ok "$report_count report(s) in $REPORT_DIR"
        fix "read the newest: $ALIAS report show"
        fix "nothing in them has been sent anywhere; they are local files"
    else
        ok "no reports written"
    fi

    if systemctl --user cat "$SLUG-report@.service" >/dev/null 2>&1; then
        ok "the crash reporter is installed"
    else
        warn "no crash reporter unit"
        fix "the shell cannot report its own death without it: make link"
    fi
}
