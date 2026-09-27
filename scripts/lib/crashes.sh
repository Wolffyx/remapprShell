# shellcheck shell=bash
# Quickshell's own crash dumps. Sourced, never executed.
#
# A crash inside quickshell never reaches systemd: its crash handler catches
# the signal, writes a dump, and restarts the shell in process. The unit stays
# active, `NRestarts` stays at 0 and the `OnFailure=` reporter never runs -- so
# without this, the shell can die repeatedly and the only trace is a directory
# nobody thought to look in. That is exactly what happened.
#
# Requires brand.sh.

CRASH_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/crashes"

# The dump directory holds every quickshell on this machine, ours and anyone
# else's -- a second shell running side by side writes here too. A dump is
# ours only if it says so, so nobody else's crash is ever reported as ours.
# crash_list asks the same of every dump at once, in its awk: the two must
# agree.
crash_is_ours() {
    local dir=$1
    [ -f "$dir/report.txt" ] || return 1
    grep -qxF "Config Path: $QS_CONFIG_DIR/shell.qml" "$dir/report.txt"
}

# crash_list [--all]   -- oldest first: id, time, signal, epoch.
#
# One awk reads every report, asking crash_is_ours' question of each dump and
# taking its first `Signal:` as it goes, and the time is bash's own. It was
# six processes a dump -- grep, stat, basename, date, sed and head -- and every
# shell start lists the dumps, with nothing ever clearing them away.
crash_list() {
    local all=${1:-}
    [ -d "$CRASH_ROOT" ] || return 0
    local line when rest
    while IFS= read -r line; do
        when=${line%%$'\t'*}
        rest=${line#*$'\t'}
        printf '%s\t%(%Y-%m-%d %H:%M:%S)T\t%s\t%s\n' "${rest%%$'\t'*}" "$when" "${rest#*$'\t'}" "$when"
    done < <(find "$CRASH_ROOT" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' 2>/dev/null \
             | sort -n \
             | CRASH_OURS="Config Path: $QS_CONFIG_DIR/shell.qml" awk -v all="$all" '
                 # "<epoch> <dir>" in, "<epoch>\t<id>\t<signal>" out: the
                 # signal last, where a tab in it cannot move the id.
                 {
                     when = substr($0, 1, index($0, " ") - 1)
                     sub(/\..*/, "", when)
                     dir = substr($0, index($0, " ") + 1)
                     id = dir
                     sub(/.*\//, "", id)
                     report = dir "/report.txt"
                     ours = 0; signal = ""; found = 0
                     while ((getline text < report) > 0) {
                         if (text == ENVIRON["CRASH_OURS"]) ours = 1
                         if (found || index(text, "Signal:") != 1) continue
                         found = 1
                         signal = substr(text, 8)
                         sub(/^ */, "", signal)
                     }
                     close(report)
                     if (all == "--all" || ours) print when "\t" id "\t" signal
                 }')
}

crash_newest() { crash_list | tail -1 | cut -f1; }

# crash_since <epoch>   -- "<epoch> <id>" for the newest dump written after
# that moment, or nothing.
#
# By time rather than by identity, because identity does not survive a dump
# being deleted: with the last-seen id gone, "the newest is not the one I
# recorded" is true of a dump that is older than it, and an old crash gets
# reported as a new one. That is not hypothetical -- it happened the first time
# this was wired up, and it is why the decision lives here where a test can
# reach it rather than in QML where one cannot.
#
# Every shell start asks this, so the dumps are listed once: the newest line
# has both the id and the time. A caller that has listed them already -- `crash
# check` -- hands that line in, and they are not listed again.
crash_since() {   # <epoch> [newest line of crash_list]
    local since=${1:-0} newest when
    if [ $# -gt 1 ]; then
        newest=$2
    else
        newest=$(crash_list | tail -1)
    fi
    [ -n "$newest" ] || return 0
    when=${newest##*$'\t'}
    [ "$when" -gt "$since" ] 2>/dev/null || return 0
    printf '%s %s\n' "$when" "${newest%%$'\t'*}"
}

# crash_dir [id]   -- the newest of ours when no id is given.
#
# Ownership is checked even when an id was named. The dump directory is shared
# by every quickshell on the machine, so naming an id is not permission to read
# it: a second shell's crash is that shell's business, and a report of ours
# must never carry it.
crash_dir() {
    local id=$1
    [ -n "$id" ] || id=$(crash_newest)
    [ -n "$id" ] || return 1
    local dir="$CRASH_ROOT/$(basename "$id")"
    [ -d "$dir" ] || return 1
    crash_is_ours "$dir" || return 1
    printf '%s' "$dir"
}

# crash_text <dir>   -- the parts worth reading, on stdout. NOT redacted; every
# caller pipes it through redact_text, and none of them may forget: the dump
# carries the environment and absolute paths.
#
# The build and system sections are dropped. They are long, they are the same
# on every dump from one machine, and the report bundle already records the
# versions that matter.
crash_text() {
    local dir=$1 lines=${2:-40}

    sed -n '/^===== Version Information/,/^===== Build Information/p' "$dir/report.txt" \
        | grep -v '^===== Build Information'
    sed -n '/^===== Instance Information/,/^===== Log Tail/p' "$dir/report.txt" \
        | grep -v '^===== Log Tail'

    # The dump's own log tail is the shell's stdout, which is where our
    # `Log.info` lines end up -- the last thing the shell said before it died.
    # It is a binary format, so it needs quickshell to read it back, and a
    # dump from a version that cannot be read is not worth failing over.
    if [ -f "$dir/log.qslog.log" ] && command -v quickshell >/dev/null 2>&1; then
        printf '\n===== Shell log before the crash =====\n'
        quickshell log -t "$lines" "$dir/log.qslog.log" 2>/dev/null \
            | sed 's/\x1b\[[0-9;]*m//g' \
            | grep -v 'quickshell.desktopentry' \
            | tail -n "$lines"
    fi
}
