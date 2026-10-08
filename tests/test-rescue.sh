#!/usr/bin/env bash
# The rescue window: opened once systemd has given up on the shell, and only
# then, saying what the last start said.
#
# Nothing here opens a window. systemctl, journalctl and systemd-run are
# stand-ins that answer from the suite, and systemd-run writes down what it
# was asked to start instead of starting it.
set -uo pipefail

SOURCE_REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$SOURCE_REPO/tests/lib/harness.sh"
harness_init
source "$SOURCE_REPO/scripts/lib/reports.sh"

RESCUE="$SOURCE_REPO/scripts/rescue.sh"
CALLS="$SANDBOX/calls"
JOURNAL="$SANDBOX/journal"
export FAKE_JOURNAL=$JOURNAL

cat > "$FAKEBIN/journalctl" <<'STUB'
#!/bin/sh
cat "$FAKE_JOURNAL"
STUB
cat > "$FAKEBIN/systemctl" <<'STUB'
#!/bin/sh
case "$*" in
    *"show -p ActiveState"*) printf '%s\n' "${FAKE_STATE:-active}" ;;
    *is-active*)             [ -n "${FAKE_RESCUE_OPEN:-}" ] ;;
esac
STUB
cat > "$FAKEBIN/systemd-run" <<STUB
#!/bin/sh
printf '%s\n' "systemd-run \$*" >> "$CALLS"
STUB
chmod +x "$FAKEBIN/journalctl" "$FAKEBIN/systemctl" "$FAKEBIN/systemd-run"

# Two tries that failed, as the journal has them: quickshell's errors, one of
# them coloured, with systemd's own lines between.
esc=$(printf '\033')
cat > "$JOURNAL" <<EOF
Started the shell.
  INFO: Launching config
 ERROR: Failed to load configuration
 ERROR:   caused by @shell.qml[1:1]: Type Old unavailable
Main process exited, code=exited, status=255/EXCEPTION
Started the shell.
${esc}[31m ERROR${esc}[0m: Failed to load configuration
 ERROR:   caused by @core/Branding.qml[-1:-1]: File not found
Main process exited, code=exited, status=255/EXCEPTION
Failed with result 'start-limit-hit'.
EOF

mkdir -p "$REPORT_DIR/20261008-091749" "$REPORT_DIR/20261008-091755"

# Every call but --print is made as the session would make it: the stand-ins
# are first on the PATH, so nothing real is reached.
in_session() { env -u "$NO_SESSION_VAR" "$@"; }

echo "== what it says =="
said=$("$RESCUE" --print 2>&1)
contains "the last try's errors"            "$said" "caused by @core/Branding.qml[-1:-1]: File not found"
check    "and not an earlier try's"         "$(grep -c 'Type Old' <<< "$said")" 0
check    "without the colour or the prefix" "$(grep -c "ERROR\|$esc" <<< "$said")" 0
contains "the newest report"                "$said" "$REPORT_DIR/20261008-091755"

echo "== when it opens =="
: > "$CALLS"
FAKE_STATE=activating in_session "$RESCUE" --if-given-up
check "not while a restart is to come" "$(wc -l < "$CALLS")" 0

: > "$CALLS"
FAKE_STATE=failed "$RESCUE" --if-given-up
check "not without a session" "$(wc -l < "$CALLS")" 0

: > "$CALLS"
FAKE_STATE=failed in_session "$RESCUE" --if-given-up
opened=$(cat "$CALLS")
contains "once systemd has given up"     "$opened" "--unit=$SLUG-rescue"
contains "about the shell's unit"        "$opened" "--setenv=RESCUE_UNIT=$SYSTEMD_UNIT"
contains "with the last try's errors"    "$opened" "File not found"
contains "and the report"                "$opened" "--setenv=RESCUE_REPORT=$REPORT_DIR/20261008-091755"
contains "drawn by its own config"       "$opened" "quickshell -n -p $SOURCE_REPO/share/rescue/shell.qml"

: > "$CALLS"
FAKE_STATE=failed FAKE_RESCUE_OPEN=1 in_session "$RESCUE" --if-given-up 2>/dev/null
check "one at a time" "$(wc -l < "$CALLS")" 0

echo "== a start that died some other way =="
printf 'Started the shell.\nSegmentation fault\nMain process exited, code=dumped\n' > "$JOURNAL"
said=$("$RESCUE" --print 2>&1)
contains "its last lines stand in" "$said" "Segmentation fault"

echo "== asked wrongly =="
"$RESCUE" --bogus >/dev/null 2>&1
check "an unknown option is refused" "$?" 1

harness_done
