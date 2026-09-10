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
crash_is_ours() {
    local dir=$1
    [ -f "$dir/report.txt" ] || return 1
    grep -qxF "Config Path: $QS_CONFIG_DIR/shell.qml" "$dir/report.txt"
}

crash_field() {
    sed -n "s/^$2: *//p" "$1/report.txt" 2>/dev/null | head -1
}

# crash_list [--all]   -- oldest first: id, time, signal, epoch.
crash_list() {
    local all=${1:-}
    [ -d "$CRASH_ROOT" ] || return 0
    local dir when
    while IFS= read -r dir; do
        [ -d "$dir" ] || continue
        [ "$all" = "--all" ] || crash_is_ours "$dir" || continue
        when=$(stat -c %Y "$dir")
        printf '%s\t%s\t%s\t%s\n' \
            "$(basename "$dir")" \
            "$(date -d "@$when" '+%Y-%m-%d %H:%M:%S')" \
            "$(crash_field "$dir" Signal)" \
            "$when"
    done < <(find "$CRASH_ROOT" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' 2>/dev/null \
             | sort -n | cut -d' ' -f2-)
}

crash_newest() { crash_list | tail -1 | cut -f1; }
crash_newest_epoch() { crash_list | tail -1 | cut -f4; }

# crash_since <epoch>   -- "<epoch> <id>" for the newest dump written after
# that moment, or nothing.
#
# By time rather than by identity, because identity does not survive a dump
# being deleted: with the last-seen id gone, "the newest is not the one I
# recorded" is true of a dump that is older than it, and an old crash gets
# reported as a new one. That is not hypothetical -- it happened the first time
# this was wired up, and it is why the decision lives here where a test can
# reach it rather than in QML where one cannot.
crash_since() {
    local since=${1:-0} newest
    newest=$(crash_newest_epoch)
    [ -n "$newest" ] || return 0
    [ "$newest" -gt "$since" ] 2>/dev/null || return 0
    printf '%s %s\n' "$newest" "$(crash_newest)"
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
