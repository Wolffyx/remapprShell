# shellcheck shell=bash
# Widgets quarantined after failing to load again and again.
#
# A section of doctor.sh, which sources it and supplies ok, warn, bad, fix and
# section. Requires brand.sh.

doctor_widgets() {
    local health q
    section "widgets"

    health="$STATE_DIR/widget-health.json"
    if [ -f "$health" ]; then
        q=$(jq -r '.quarantined | keys | join(", ")' "$health" 2>/dev/null || true)
        if [ -n "$q" ] && [ "$q" != "" ]; then
            warn "quarantined: $q"
            fix "these were disabled after repeatedly failing to load"
            fix "re-enable one from the settings window, Widgets page"
        else
            ok "no quarantined widgets"
        fi
    else
        ok "no widget failures recorded"
    fi
}
