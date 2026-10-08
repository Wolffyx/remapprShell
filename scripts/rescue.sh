#!/usr/bin/env bash
# The window that says the shell could not start.
#
#   rescue [--if-given-up]   open it; with --if-given-up, only once systemd
#                            has stopped trying to start the shell
#   rescue --print           what it would say, and open nothing
#
# A shell that cannot start cannot say so, and while it is down nothing serves
# notifications either. On 2026-10-08 it failed at login, systemd gave up after
# five tries, and the only sign was a desktop with no panel: kdeconnect, zapzap
# and Discover each tried to notify in those minutes and found nobody there.
#
# So this is a window. The report unit systemd starts when the shell's unit
# fails runs it after writing the report, and it is drawn by share/rescue/
# shell.qml, which imports nothing from the shell's tree -- that tree is what
# failed. It shows the last start's errors and the report, and offers to try
# again.
#
# The report unit runs at every failure, and systemd starts the shell again
# after all but the last. --if-given-up is for that unit: the window opens only
# when the shell's unit is failed, not while it waits to restart.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/reports.sh"

RESCUE_UNIT="$SLUG-rescue"
RESCUE_QML="$REPO_ROOT/share/rescue/shell.qml"

# The last start's errors, without quickshell's "ERROR:" in front of each: the
# last unbroken run of them, since every try writes the same block again and
# systemd's own lines fall between. A start that died some other way wrote no
# such block, and its last lines stand in.
last_errors() {
    local log errors
    log=$(journalctl --user -u "$SYSTEMD_UNIT" -b -n 80 -o cat --no-pager 2>/dev/null \
          | sed -E 's/\x1b\[[0-9;]*m//g')
    errors=$(printf '%s\n' "$log" | awk '
        /^ *ERROR:/ { if (!run) block = ""; run = 1
                      sub(/^ *ERROR: ?/, ""); block = block $0 "\n"; next }
        { run = 0 }
        END { printf "%s", block }')
    [ -n "$errors" ] || errors=$(printf '%s\n' "$log" | tail -8)
    printf '%s' "${errors:-the journal has nothing for this start}"
}

given_up() {
    [ "$(systemctl --user show -p ActiveState --value "$SYSTEMD_UNIT" 2>/dev/null)" = failed ]
}

# Its own unit, so it outlives the oneshot that opens it and is gone, collected,
# when it is closed. One at a time: a second failure while it is open finds it
# there and leaves it.
open_window() {
    local errors=$1 report=$2
    if systemctl --user is-active --quiet "$RESCUE_UNIT" 2>/dev/null; then
        log_info "the rescue window is already open"
        return 0
    fi
    systemd-run --user --quiet --collect --unit="$RESCUE_UNIT" \
        --setenv=RESCUE_NAME="$DISPLAY_NAME" \
        --setenv=RESCUE_UNIT="$SYSTEMD_UNIT" \
        --setenv=RESCUE_ERRORS="$errors" \
        --setenv=RESCUE_REPORT="$report" \
        --setenv=RESCUE_HINT="$ALIAS doctor, $ALIAS report show" \
        quickshell -n -p "$RESCUE_QML"
}

mode=open
case "${1:-}" in
    "")             ;;
    --if-given-up)  mode=if-given-up ;;
    --print)        mode=print ;;
    *)              die "unknown option: $1 (rescue [--if-given-up | --print])" ;;
esac

errors=$(last_errors)
newest=$(report_newest)
report=${newest:+$REPORT_DIR/$newest}

if [ "$mode" = print ]; then
    printf 'errors:\n%s\nreport: %s\n' "$errors" "${report:-none}"
    exit 0
fi

# A HOME is not a session: under the test suites this would open a real
# window on the developer's desktop.
session_available || { log_debug "rescue: no session, nothing opened"; exit 0; }

if [ "$mode" = if-given-up ] && ! given_up; then
    log_debug "rescue: $SYSTEMD_UNIT is still being restarted"
    exit 0
fi

[ -f "$RESCUE_QML" ] || die "the rescue window is missing: $RESCUE_QML"
open_window "$errors" "$report"
