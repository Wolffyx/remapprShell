#!/usr/bin/env bash
# Restore points.
#
#   create [--label] <label>  take one now
#   list [--json]      show what exists, with sizes
#   remove <name>      delete one
#   prune [--keep N]   delete all but the newest N
#   lock <name>        never prune this one
#   unlock <name>      let pruning consider it again
#
# Nothing in this project deletes a snapshot on its own -- not on restore, not
# on uninstall, not to reclaim space. Removal happens only through the two
# commands above, because a restore point the software may delete by itself is
# not a restore point.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/protected.sh"
source "$REPO_ROOT/scripts/lib/config.sh"
source "$REPO_ROOT/scripts/lib/snapshot.sh"

cmd=${1:-list}
[ $# -gt 0 ] && shift

case "$cmd" in
    create)
        # `--label X` too: that is how every other command here names things,
        # and taking the flag as the label is how a restore point came to be
        # called `--label`.
        label=""
        while [ $# -gt 0 ]; do
            case "$1" in
                --label)   label=${2:?usage: $ALIAS snapshot create [--label] <label>}; shift ;;
                --label=*) label=${1#--label=} ;;
                -*)        die "unknown option: $1 (usage: $ALIAS snapshot create [--label] <label>)" ;;
                *)         [ -z "$label" ] || die "one label only (quote it if it has spaces)"; label=$1 ;;
            esac
            shift
        done
        snapshot_create "${label:-manual}" >/dev/null
        # Only if `snapshots.keep` says so; off until then.
        snapshot_autoprune
        ;;

    lock)   snapshot_lock "${1:?usage: $ALIAS snapshot lock <name>}" on ;;
    unlock) snapshot_lock "${1:?usage: $ALIAS snapshot unlock <name>}" off ;;
    list)
        if [ "${1:-}" = "--json" ]; then snapshot_list_json; else snapshot_list; fi
        ;;

    remove)
        name=${1:?usage: $ALIAS snapshot remove <name>}
        log_warn "about to permanently delete snapshot '$name'"
        [ "${2:-}" = "--yes" ] || confirm_or_die
        snapshot_remove "$name"
        ;;

    prune)
        keep=5
        while [ $# -gt 0 ]; do
            case "$1" in
                --keep) keep=${2:?--keep needs a number}; shift ;;
                --yes)  ASSUME_YES=1 ;;
                *) die "unknown option: $1" ;;
            esac
            shift
        done
        log_warn "about to permanently delete all but the newest $keep snapshot(s)"
        [ "${ASSUME_YES:-0}" = 1 ] || confirm_or_die
        snapshot_prune "$keep"
        ;;

    *) die "unknown command: $cmd (expected create, list, remove, prune, lock or unlock)" ;;
esac
