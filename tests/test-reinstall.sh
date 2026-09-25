#!/usr/bin/env bash
# The reinstall's plan: the uninstall, then the setup, in that order.
#
# Dry runs only. A real one is the setup for real -- a plugin build, a theme
# -- which test-uninstall.sh and test-setup.sh cover in their halves; what is
# the reinstall's own is the order, the question, and what --fresh removes.
set -uo pipefail

SOURCE_REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$SOURCE_REPO/tests/lib/harness.sh"
harness_init

REINSTALL="$SOURCE_REPO/scripts/reinstall.sh"

real_units() {
    systemctl --user is-enabled "$SYSTEMD_UNIT" "$SLUG-theme.service" 2>/dev/null | tr '\n' ' '
    systemctl --user is-active "$SYSTEMD_UNIT" 2>/dev/null
}
real_before=$(real_units)

echo "== nobody to ask =="
out=$("$REINSTALL" --dry-run 2>&1 < /dev/null)
check "no answer, nothing planned" "$(printf '%s' "$out" | grep -c 'would run')" 0
contains "and it says so" "$out" "nothing was changed"

echo "== the plan =="
plan=$("$REINSTALL" --dry-run --yes 2>&1 < /dev/null)
removed_at=$(printf '%s\n' "$plan" | grep -n 'install.sh --uninstall' | cut -d: -f1)
installed_at=$(printf '%s\n' "$plan" | grep -n 'install.sh --copy' | cut -d: -f1)
check "the uninstall, then the setup" \
    "$([ "${removed_at:-0}" -gt 0 ] && [ "${removed_at}" -lt "${installed_at:-0}" ] && echo yes)" yes
check "the setup takes its defaults" "$(printf '%s' "$plan" | grep -c 'shortcuts.sh set launcher Meta$')" 1
check "no uninstall summary in the middle" "$(printf '%s' "$plan" | grep -c 'Uninstalled')" 0
check "settings kept"                "$(printf '%s' "$plan" | grep -c "rm -rf $CONFIG_DIR")" 0

echo "== fresh =="
plan=$("$REINSTALL" --dry-run --yes --fresh 2>&1 < /dev/null)
check "settings removed"             "$(printf '%s' "$plan" | grep -c "rm -rf $CONFIG_DIR $STATE_DIR$")" 1
check "restore points kept"          "$(printf '%s' "$plan" | grep -c 'snapshots')" 0

check "the real session's units are as they were" "$(real_units)" "$real_before"

harness_done
