# shellcheck shell=bash
# Restore points: how many there are, and what they weigh.
#
# A section of doctor.sh, which sources it and supplies ok, warn, bad, fix and
# section. Requires brand.sh and snapshot.sh.

doctor_restore_points() {
    local root count
    section "restore points"

    root=$(snapshot_root)
    count=$(ls -1 "$root" 2>/dev/null | wc -l)
    if [ "$count" -gt 0 ]; then
        ok "$count restore point(s), $(du -sh "$root" 2>/dev/null | cut -f1) total"
        fix "oldest is the pre-install state; nothing is ever removed automatically"
    else
        warn "no restore points"
        fix "take one before changing KDE settings: $ALIAS snapshot create"
    fi
}
