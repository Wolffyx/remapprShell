# shellcheck shell=bash
# Logging helpers, and the two other things nearly every command needs: asking
# before something that cannot be undone, and a fresh name for what it writes.
# Sourced, never executed.

if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
    _c_red=$'\033[31m'; _c_yel=$'\033[33m'; _c_grn=$'\033[32m'
    _c_dim=$'\033[2m';  _c_off=$'\033[0m'
else
    _c_red=''; _c_yel=''; _c_grn=''; _c_dim=''; _c_off=''
fi

log_info()  { printf '%s\n'      "$*" >&2; }
log_step()  { printf '%s==>%s %s\n' "$_c_grn" "$_c_off" "$*" >&2; }
log_warn()  { printf '%swarning:%s %s\n' "$_c_yel" "$_c_off" "$*" >&2; }
log_error() { printf '%serror:%s %s\n'   "$_c_red" "$_c_off" "$*" >&2; }
log_debug() { [ -n "${RMPR_DEBUG:-}" ] && printf '%s%s%s\n' "$_c_dim" "$*" "$_c_off" >&2 || true; }
die()       { log_error "$@"; exit 1; }

# Asks before something that cannot be undone, and stops the command on
# anything but yes. Read from the terminal itself: an answer piped into the
# command is not a person agreeing to it.
confirm_or_die() {
    local reply
    printf 'continue? [y/N] ' >&2
    read -r reply < /dev/tty || reply=""
    case "$reply" in [yY]*) ;; *) die "aborted" ;; esac
}

# <base> itself, or <base>-2, -3 ... -- the first that does not exist yet.
# Names that begin with a timestamp are only as fine as a second, and two
# things written in the same one -- a widget failing and the unit dying right
# after it, a restore point and the change it guards -- would otherwise share
# a directory, the second writing into the first.
unique_path() {   # <base>
    local path=$1 n=2
    while [ -e "$path" ]; do path="$1-$n"; n=$((n + 1)); done
    printf '%s' "$path"
}
