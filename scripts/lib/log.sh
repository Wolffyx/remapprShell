# shellcheck shell=bash
# Logging helpers. Sourced, never executed.

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
