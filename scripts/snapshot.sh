#!/usr/bin/env bash
# Restore points.
#
#   create [label]     take one now
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
source "$REPO_ROOT/scripts/lib/snapshot.sh"

cmd=${1:-list}
[ $# -gt 0 ] && shift

case "$cmd" in
    create)
        snapshot_create "${1:-manual}" >/dev/null
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
        snapshot_list | grep -q "^$(basename "$name") " || true
        log_warn "about to permanently delete snapshot '$name'"
        if [ "${2:-}" != "--yes" ]; then
            printf 'continue? [y/N] ' >&2
            read -r reply < /dev/tty || reply=""
            case "$reply" in [yY]*) ;; *) die "aborted" ;; esac
        fi
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
        if [ "${ASSUME_YES:-0}" != 1 ]; then
            printf 'continue? [y/N] ' >&2
            read -r reply < /dev/tty || reply=""
            case "$reply" in [yY]*) ;; *) die "aborted" ;; esac
        fi
        snapshot_prune "$keep"
        ;;

    *) die "unknown command: $cmd (expected create, list, remove, prune, lock or unlock)" ;;
esac
