#!/usr/bin/env bash
# Tests the window daemon on the session bus, inside a throwaway HOME.
#
# The daemon is the piece that exists only because a KWin script can call DBus
# but cannot be called. What matters about it is not that it holds a list --
# that is four lines -- but that a bad payload cannot blank a panel, and that
# two copies cannot answer with two different lists.
#
# It owns a real name on the real session bus, so it runs under a name of its
# own here rather than the one an installed shell would be using.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/tests/lib/harness.sh"
harness_init
source "$REPO_ROOT/tests/lib/windowsd.sh"
DAEMON_PID=""
harness_on_exit '[ -n "$DAEMON_PID" ] && kill "$DAEMON_PID" 2>/dev/null'

refused() { printf '  FAIL  %s\n' "$1" >&2; fail=$((fail + 1)); harness_done; }

command -v busctl >/dev/null 2>&1 || { echo "  SKIP  busctl not available"; exit 0; }
[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] || { echo "  SKIP  no session bus"; exit 0; }
windowsd_require

# A name of its own: the installed daemon may be running on this bus, and two
# daemons answering one name is the thing the daemon itself refuses to do.
#
# That name is also what stops this copy touching the user's global shortcuts.
# It runs against the *real* session bus -- there is no other -- so a daemon
# that claimed the shell's kglobalaccel component here would unbind the keys on
# the machine running the tests, which is exactly what happened once. Belt and
# braces: the no-session variable as well, set by the harness for every suite
# and honoured by the daemon too.
TEST_NAME="com.remappr.ShellTest$$"

# The script and its package, where an install in this HOME would put them:
# the daemon started below is one that finds its modules the way the
# installed one does.
windowsd_install || refused "the daemon could not be rendered as an install renders it"
DAEMON=$WINDOWSD_DAEMON

# BUS_NAME and INTERFACE by name, and nothing else. SHORTCUT_OWNER keeps the
# shell's own name, because BUS_NAME differing from it is the guard: a sed
# over every quoted "$DBUS_NAME" renamed both, and left this copy believing
# it owned the keys, with only the no-session variable standing in the way.
# Each is found exactly once, or nothing starts: a rename that matched
# nothing would start this copy under the shell's own name.
python3 - "$WINDOWSD_PACKAGE" "$TEST_NAME" <<'PY' || refused "the daemon could not be given a name of its own"
import re, sys
package, name = sys.argv[1], sys.argv[2]
for module, pattern, line in (("brand.py", r'^BUS_NAME = .*$', f'BUS_NAME = "{name}"'),
                              ("windowlist.py", r'^INTERFACE = .*$', f'INTERFACE = "{name}.Windows"')):
    path = f"{package}/{module}"
    src, found = re.subn(pattern, line, open(path).read(), flags=re.M)
    if found != 1:
        sys.exit(f"{module}: {pattern} matched {found} times")
    open(path, 'w').write(src)
PY

# Without a display: this copy has no business sweeping the X11 windows of
# whoever is running the tests, and the icons are checked on their own, in
# test-windowsd-icons.sh.
env -u DISPLAY python3 "$DAEMON" & DAEMON_PID=$!
for _ in $(seq 1 40); do
    busctl --user --json=short call "$TEST_NAME" /Windows "$TEST_NAME.Windows" List >/dev/null 2>&1 && break
    sleep 0.25
done

call() { busctl --user --json=short call "$TEST_NAME" /Windows "$TEST_NAME.Windows" "$@" 2>/dev/null; }
list()  { call List | jq -r '.data[0]'; }

check "starts empty"          "$(list)" "[]"

# The guard that keeps this test off the user's keyboard. Checked here rather
# than only in test-windowsd-shortcuts.sh, because this is the copy that would
# do the damage: if it ever registers a component, the live session loses its
# keys.
check "it claims no shortcuts" \
    "$(busctl --user --json=short call org.kde.kglobalaccel /kglobalaccel \
        org.kde.KGlobalAccel allComponents 2>/dev/null \
        | grep -c "ShellTest" || true)" "0"

WINDOW='[{"uuid":"a","title":"Work","appId":"org.kde.dolphin","minimized":false,"active":true}]'
call Update s "$WINDOW" >/dev/null
check "holds what it is given" "$(list | jq -r '.[0].title')" "Work"
check "one window"             "$(list | jq -r 'length')" "1"

# The rule the whole thing rests on: a payload that cannot be read must leave
# the last good list in place. A blank panel is the failure being designed
# against, and it is worse than a stale one.
call Update s 'not json at all' >/dev/null
check "junk leaves the list alone"  "$(list | jq -r '.[0].title')" "Work"
call Update s '{"not":"a list"}' >/dev/null
check "a non-list is refused"       "$(list | jq -r 'length')" "1"
call Update s '' >/dev/null
check "an empty payload is refused" "$(list | jq -r 'length')" "1"

# But an empty list is a legitimate answer: every window really can be closed.
call Update s '[]' >/dev/null
check "no windows is accepted"      "$(list)" "[]"

# The same, end to end through the daemon, for a process of this test's own:
# what the shell is sent for a window matches what /proc says, and the
# environment's other variables are not in it.
MOUNTED="$SANDBOX/mounted-app"
mkdir -p "$MOUNTED"
printf '[Desktop Entry]\nType=Application\nName=Mounted Example\nIcon=mounted\n' > "$MOUNTED/example.desktop"
env -i PATH="$PATH" APPDIR="$MOUNTED" PRIVATE_THING=do-not-send sleep 300 &
SLEEPER=$!
harness_on_exit 'kill "$SLEEPER" 2>/dev/null'
call Update s "[{\"uuid\":\"p\",\"title\":\"Proc\",\"appId\":\"example.nothing\",\"pid\":$SLEEPER}]" >/dev/null
check "the window carries its command line"   "$(list | jq -r '.[0].cmdline')" "sleep 300"
check "and its process's name"                "$(list | jq -r '.[0].processName')" "sleep"
check "and which of its words are programs"   "$(list | jq -c '.[0].executables')" '["sleep"]'
check "and the desktop file its environment names" "$(list | jq -r '.[0].desktopHint.name')" "Mounted Example"
check "and nothing else of the environment"   "$(list | grep -c do-not-send)" "0"
call Update s '[]' >/dev/null

# The signal is what the shell actually follows.
#
# One monitor watches both cases, and is waited for rather than slept for.
# It is listening once a signal sent after it started has reached it, so it is
# sent probes until one does. That was two monitors and six seconds of sleep,
# the second monitor started while the first was still writing to the same
# file.
monitor_out="$SANDBOX/monitor.json"
timeout 20 busctl --user --json=short monitor --match "type='signal',interface='$TEST_NAME.Windows'" > "$monitor_out" 2>&1 &
monitor_pid=$!
seen() {   # seen <text> <count>: up to five seconds for that many lines with it
    local i
    for i in $(seq 1 100); do
        [ "$(grep -c -- "$1" "$monitor_out")" -ge "$2" ] && return 0
        sleep 0.05
    done
    return 1
}
for _ in $(seq 1 100); do
    busctl --user emit /Windows "$TEST_NAME.Windows" Listening 2>/dev/null
    sleep 0.05
    grep -q '"member":"Listening"' "$monitor_out" && break
done

call Update s "$WINDOW" >/dev/null
seen '"member":"Changed"' 1
check "announces a change"     "$(grep -c '"member":"Changed"' "$monitor_out")" "1"

# KWin repeats itself -- the same list arrives again on events that changed
# nothing -- and a signal per repeat would wake the shell for no reason.
#
# A real change after the repeat marks the end: one sender's signals arrive in
# the order they were sent, so once its signal is in, any the repeat sent is in
# too. Two in all -- the change above and the marker -- means the repeat said
# nothing.
call Update s "$WINDOW" >/dev/null
call Update s '[{"uuid":"b","title":"end-of-test","appId":"x","minimized":false,"active":false}]' >/dev/null
seen 'end-of-test' 1
check "says nothing when nothing changed" "$(( $(grep -c '"member":"Changed"' "$monitor_out") - 2 ))" "0"
kill "$monitor_pid" 2>/dev/null

harness_done
