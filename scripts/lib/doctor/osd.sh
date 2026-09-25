# shellcheck shell=bash
# The on-screen display: ours, Plasma's, or both at once.
#
# A section of doctor.sh, which sources it and supplies ok, warn, bad, fix and
# section. Requires brand.sh and config.sh.

doctor_osd() {
    local osd_enabled lnf_active osd_file osd_silenced
    section "on-screen display"

    osd_enabled=$(config_get '.osd.enabled' false)
    lnf_active=$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage --default '')
    # Either of our two packages is ours: Plasma's day and night switch moves
    # between them, and the dark one is the active one every evening. Both
    # must be silenced, or Plasma's OSD comes back with the next switch.
    osd_silenced=yes
    for osd_file in "$PLASMA_LNF_DIR/$LNF_PACKAGE_ID/contents/osd/Osd.qml" \
                    "$PLASMA_LNF_DIR/$LNF_DARK_PACKAGE_ID/contents/osd/Osd.qml"; do
        [ -f "$osd_file" ] || continue
        grep -q 'drawn as nothing' "$osd_file" 2>/dev/null || osd_silenced=no
    done

    if [ "$osd_enabled" != "true" ]; then
        ok "Plasma draws the OSD"
        if [ "$osd_silenced" = yes ]; then
            bad "but our package silences Plasma's OSD, and ours is switched off"
            fix "nothing will draw an OSD at all"
            fix "put it back: $ALIAS theme osd plasma"
        fi
    elif [ "$lnf_active" != "$LNF_PACKAGE_ID" ] && [ "$lnf_active" != "$LNF_DARK_PACKAGE_ID" ]; then
        warn "our OSD is on, but our look-and-feel package is not active"
        fix "Plasma is drawing its own as well, so you will see two"
        fix "either apply the package ($ALIAS theme apply) or turn ours off"
    elif [ "$osd_silenced" = yes ]; then
        ok "our OSD draws, Plasma's is silenced"
    else
        warn "our OSD is on and Plasma's is not silenced; you will see two"
        fix "silence Plasma's: $ALIAS theme osd ours"
    fi
}
