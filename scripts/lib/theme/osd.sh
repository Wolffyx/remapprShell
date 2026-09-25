# shellcheck shell=bash
# Which OSD draws when our package is active: ours, with Plasma's silenced, or
# Plasma's.
#
# Sourced by theme.sh, never executed. Requires brand.sh, log.sh and
# config.sh -- and install.sh, for where the packages are.

# Which OSD draws.
#
# Our Look-and-Feel package supplies the QML plasmashell draws for the OSD, so
# with the package active there is no way to have both ours and Plasma's
# without seeing two. Swapping that one file is the whole mechanism: plasmashell
# still creates the window and still emits the signals our own OSD listens to,
# it simply draws nothing.
osd_mode() {
    local mode=$1
    local dest="$LNF_DEST/contents/osd/Osd.qml"
    local pkg

    [ -d "$LNF_DEST" ] || die "the look-and-feel package is not installed ($ALIAS theme apply)"

    # Both packages: which of the two is active changes at sunset, and an OSD
    # silenced in one of them would come back with the other.
    case "$mode" in
        ours)
            for pkg in "$LNF_DEST" "$LNF_DARK_DEST"; do
                [ -d "$pkg" ] || continue
                cp -a "$LNF_SRC/contents/osd/SilentOsd.qml" "$pkg/contents/osd/Osd.qml" \
                    || die "could not silence Plasma's OSD"
                chmod 644 "$pkg/contents/osd/Osd.qml"
            done
            set_osd_enabled true
            log_step "Plasma's OSD is silenced; the shell draws its own"
            ;;
        plasma)
            for pkg in "$LNF_DEST" "$LNF_DARK_DEST"; do
                [ -d "$pkg" ] || continue
                cp -a "$LNF_SRC/contents/osd/Osd.qml" "$pkg/contents/osd/Osd.qml" \
                    || die "could not restore Plasma's OSD"
                chmod 644 "$pkg/contents/osd/Osd.qml"
            done
            set_osd_enabled false
            log_step "Plasma draws the OSD again"
            ;;
        status)
            if grep -q 'drawn as nothing' "$dest" 2>/dev/null \
               && { [ ! -d "$LNF_DARK_DEST" ] || grep -q 'drawn as nothing' "$LNF_DARK_DEST/contents/osd/Osd.qml" 2>/dev/null; }; then
                printf 'osd: ours (Plasma'"'"'s is silenced)\n'
            else
                printf 'osd: Plasma'"'"'s\n'
            fi
            return 0
            ;;
        *) die "unknown OSD mode: $mode (expected ours, plasma or status)" ;;
    esac

    log_info "restart plasmashell to see it: systemctl --user restart plasma-plasmashell.service"
}

# What a fresh copy of the packages must carry: installing one copies Plasma's
# own OSD back in, and on 2026-09-24 that left the dark package drawing
# Plasma's popup beside ours from the first sunset after an install -- the
# light one had been silenced again since, the dark one never was. So an
# install puts back whatever `osd.enabled` says, in both.
osd_keep_configured() {
    local pkg
    [ "$(config_get '.osd.enabled' false)" = "true" ] || return 0
    for pkg in "$LNF_DEST" "$LNF_DARK_DEST"; do
        [ -d "$pkg/contents/osd" ] || continue
        cp -a "$LNF_SRC/contents/osd/SilentOsd.qml" "$pkg/contents/osd/Osd.qml" || return 1
        chmod 644 "$pkg/contents/osd/Osd.qml"
    done
}

# The shell watches its configuration, so this is what makes our OSD appear or
# stop appearing. Written by the same command that swaps the QML: two settings
# that must agree are better set by one thing.
set_osd_enabled() {
    local value=$1
    config_set '.osd.enabled' "$value"
    case $? in
        0) return 0 ;;
        2) log_warn "$(profile_file) does not parse; leaving osd.enabled alone"; return 0 ;;
        *) return 1 ;;
    esac
}
