#!/usr/bin/env bash
# Quickshell's own crash dumps.
#
#   list [--ids] [--all]   what this shell has left behind
#   show [<id>]            the stack trace and the log from just before it
#   remove <id> | --all    delete dumps
#   since <epoch>          the newest dump written after that moment, if any
#   check                  is there a crash the shell has not accounted for?
#
# These exist because a crash inside quickshell never reaches systemd: the
# engine catches the signal, writes a dump, and restarts the shell in process.
# The unit stays active and the OnFailure= reporter never runs, so without
# looking here a repeatedly crashing shell looks like a healthy one.
#
# The shell writes a diagnostic report by itself when it comes back from a
# crash (domain/diagnostics/CrashWatch.qml); these commands are for reading
# the dump directly, and for `ask --crash`.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/redact.sh"
source "$REPO_ROOT/scripts/lib/crashes.sh"

cmd=${1:-list}
[ $# -gt 0 ] && shift

IDS=no
ALL=""
args=()
while [ $# -gt 0 ]; do
    case "$1" in
        --ids) IDS=yes ;;
        --all) ALL="--all" ;;
        -*)    die "unknown option: $1" ;;
        *)     args+=("$1") ;;
    esac
    shift
done

case "$cmd" in
    list)
        if [ "$IDS" = yes ]; then
            crash_list $ALL | cut -f1
            exit 0
        fi
        found=0
        while IFS=$'\t' read -r id when signal _; do
            [ -n "$id" ] || continue
            found=1
            printf '%-12s %s  %s\n' "$id" "$when" "$signal"
        done < <(crash_list $ALL)
        if [ "$found" = 0 ]; then
            log_info "no crash dumps${ALL:+ at all}"
        else
            log_info ""
            log_info "read one:      $ALIAS crash show"
            log_info "ask about it:  $ALIAS ask --crash"
        fi
        ;;

    since)
        crash_since "${args[0]:-0}"
        ;;

    # What the shell runs when it starts. It answers one question -- has this
    # shell come back from a crash it has not already reported -- and keeps the
    # record of what it has seen, so the whole decision is here where a test
    # can reach it rather than in QML where one cannot.
    #
    # Prints "<epoch> <id>" for a crash to report, and nothing otherwise.
    check)
        seen_file="$STATE_DIR/last-crash"
        newest=$(crash_newest_epoch)

        if [ ! -f "$seen_file" ]; then
            # Never run here before, so every dump already present predates
            # this shell and none of them is news. The record is written even
            # when there are none: without that, the first crash on a fresh
            # install would arrive with the file still missing and be seeded
            # away as history instead of reported.
            mkdir -p "$STATE_DIR"
            printf '%s %s
' "${newest:-0}" "$(crash_newest)" > "$seen_file"
            exit 0
        fi

        seen=$(cut -d' ' -f1 "$seen_file" 2>/dev/null)
        case "$seen" in ''|*[!0-9]*) seen=0 ;; esac

        line=$(crash_since "$seen")
        [ -n "$line" ] || exit 0

        printf '%s
' "$line" > "$seen_file"
        printf '%s
' "$line"
        ;;

    show)
        dir=$(crash_dir "${args[0]:-}") || die "no crash dump from this shell"
        # Redacted like everything else here: a dump carries the environment
        # and absolute paths, and this output is meant to be pasteable.
        crash_text "$dir" 200 | redact_text
        ;;

    remove)
        if [ -n "$ALL" ]; then
            n=0
            while IFS=$'\t' read -r id _ _ _; do
                [ -n "$id" ] || continue
                rm -rf "${CRASH_ROOT:?}/$id"
                n=$((n + 1))
            done < <(crash_list)
            log_step "removed $n dump(s)"
            exit 0
        fi
        id=${args[0]:?usage: $ALIAS crash remove <id> | --all}
        dir=$(crash_dir "$id") || die "no such dump: $id"
        rm -rf "$dir"
        log_step "removed $dir"
        ;;

    *) die "unknown command: $cmd (expected list, show, remove, since or check)" ;;
esac
