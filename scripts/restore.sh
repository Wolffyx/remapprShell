#!/usr/bin/env bash
# Puts KDE back the way it was.
#
#   --preinstall            restore the oldest snapshot (the pre-install state)
#   --snapshot <dir|name>   restore a specific one
#   --list                  show what is available
#
# Only Tier 0 is replayed here, because it is the only tier that always exists
# and therefore the only one that can be tested. Commands for the btrfs and
# snapper tiers are printed rather than run.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/protected.sh"
source "$REPO_ROOT/scripts/lib/snapshot.sh"

MODE=latest
WANT=""
ASSUME_YES=0

while [ $# -gt 0 ]; do
    case "$1" in
        --preinstall) MODE=preinstall ;;
        --snapshot)   MODE=named; WANT=${2:?--snapshot needs a name}; shift ;;
        --list)       MODE=list ;;
        --yes|-y)     ASSUME_YES=1 ;;
        -h|--help)    sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'; exit 0 ;;
        *) die "unknown argument: $1" ;;
    esac
    shift
done

root=$(snapshot_root)

if [ "$MODE" = list ]; then
    [ -d "$root" ] || { log_info "no snapshots yet"; exit 0; }
    for d in "$root"/*/; do
        [ -d "$d" ] || continue
        printf '%s  %s  %s path(s)\n' \
            "$(basename "$d")" \
            "$(grep -h '^created=' "$d/meta" 2>/dev/null | cut -d= -f2-)" \
            "$(wc -l < "$d/manifest.txt" 2>/dev/null || echo '?')"
    done
    exit 0
fi

case "$MODE" in
    preinstall)
        # The oldest snapshot is the one taken before anything was changed.
        target=$(ls -1 "$root" 2>/dev/null | sort | head -1 | sed "s|^|$root/|")
        [ -n "$target" ] || die "no snapshots exist; nothing to restore"
        ;;
    named)
        target=$WANT
        [ -d "$target" ] || target="$root/$WANT"
        [ -d "$target" ] || die "no such snapshot: $WANT"
        ;;
    *)
        target=$(snapshot_latest) || die "no snapshots exist; nothing to restore"
        ;;
esac

log_step "restoring from $target"
grep -h '^created=' "$target/meta" 2>/dev/null | sed 's/^/    taken /' >&2

# Restoring overwrites live configuration, so the shell must not be running and
# holding files open -- and the user should be told before, not after.
if shell_running; then
    log_warn "$DISPLAY_NAME appears to be running; stop it first:"
    log_warn "  systemctl --user stop $SYSTEMD_UNIT"
    [ "$ASSUME_YES" = 1 ] || die "refusing to restore over a running shell (pass --yes to override)"
fi

if [ "$ASSUME_YES" != 1 ]; then
    log_warn "this will overwrite $(wc -l < "$target/manifest.txt") path(s) with their snapshotted contents."
    printf 'continue? [y/N] ' >&2
    read -r reply < /dev/tty || reply=""
    case "$reply" in [yY]*) ;; *) die "aborted" ;; esac
fi

# A snapshot of the current state first: a restore is itself a destructive
# change, and undoing one must be possible.
snapshot_create "before-restore" >/dev/null

snapshot_restore "$target"

log_step "restored"
log_info "log out and back in, or restart plasmashell, for KDE to re-read everything:"
log_info "  systemctl --user restart plasma-plasmashell.service"
