#!/usr/bin/env bash
# The uninstall, run for real against an install into a throwaway HOME.
#
# Against a copy of the repo, as test-update.sh is: an install regenerates
# Branding.qml in the tree it runs from, and in the checkout that is the live
# shell's own file.
#
# Checked: nothing happens without an answer, what was installed is removed
# and what the user wrote is kept, --purge removes that too, and the PATH
# entry an install added goes with it. The reverts themselves are each their
# own script's, with suites of their own; here they only have to not stop the
# rest when there is nothing to revert, which is what a machine that never
# ran them looks like.
set -uo pipefail

SOURCE_REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$SOURCE_REPO/tests/lib/harness.sh"
harness_init

COPY="$SANDBOX/repo"
mkdir -p "$COPY"
tar -C "$SOURCE_REPO" --exclude=.git --exclude=./build --exclude='./dev/preview/root.*' -cf - . \
    | tar -C "$COPY" -xf -

install_copy() { PATH="/usr/bin:/bin" "$COPY/scripts/install.sh" --copy >/dev/null 2>&1; }
uninstall()    { "$COPY/scripts/uninstall.sh" "$@" >/dev/null 2>&1 < /dev/null; }

# The real session's units, which nothing here may touch: the first run of
# this suite stopped and disabled the developer's own shell.
real_units() {
    systemctl --user is-enabled "$SYSTEMD_UNIT" "$SLUG-theme.service" 2>/dev/null | tr '\n' ' '
    systemctl --user is-active "$SYSTEMD_UNIT" 2>/dev/null
}
real_before=$(real_units)

echo "== installed =="
install_copy
check "the shell is in place"      "$([ -d "$QS_CONFIG_DIR" ] && echo yes)" yes
check "and the command"            "$([ -e "$BIN_DIR/$ALIAS" ] && echo yes)" yes
PATH_CONF="$XDG_CONFIG_HOME/environment.d/60-$SLUG-path.conf"
check "\$BIN_DIR put on PATH"      "$(grep -c "^PATH=$BIN_DIR:" "$PATH_CONF" 2>/dev/null)" 1
mkdir -p "$CONFIG_DIR/profiles/mine" && echo '{}' > "$CONFIG_DIR/profiles/mine/shell.json"

echo "== nobody to ask =="
uninstall
check "no answer, nothing removed" "$([ -d "$QS_CONFIG_DIR" ] && echo kept)" kept

echo "== uninstalled =="
uninstall --yes
check "the shell is gone"          "$([ -e "$QS_CONFIG_DIR" ] || echo gone)" gone
check "and the command"            "$([ -e "$BIN_DIR/$ALIAS" ] || [ -L "$BIN_DIR/$ALIAS" ] || echo gone)" gone
check "and its unit"               "$([ -e "$SYSTEMD_USER_DIR/$SYSTEMD_UNIT" ] || echo gone)" gone
check "and the PATH entry"         "$([ -e "$PATH_CONF" ] || echo gone)" gone
check "the user's profile is kept" "$([ -f "$CONFIG_DIR/profiles/mine/shell.json" ] && echo kept)" kept

echo "== purged =="
install_copy
uninstall --yes --purge
check "the profile goes too"       "$([ -e "$CONFIG_DIR" ] || echo gone)" gone
check "and the state"              "$([ -e "$STATE_DIR" ] || echo gone)" gone
check "and the data"               "$([ -e "$DATA_DIR" ] || echo gone)" gone

check "the real session's units are as they were" "$(real_units)" "$real_before"

harness_done
