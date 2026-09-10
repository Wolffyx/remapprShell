#!/usr/bin/env bash
# Tests the window daemon inside a throwaway HOME.
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

SANDBOX=$(mktemp -d)
DAEMON_PID=""
cleanup() {
    [ -n "$DAEMON_PID" ] && kill "$DAEMON_PID" 2>/dev/null
    rm -rf "$SANDBOX"
}
trap cleanup EXIT

export HOME="$SANDBOX/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME"

source "$REPO_ROOT/scripts/lib/log.sh"
source "$REPO_ROOT/scripts/lib/brand.sh"
source "$REPO_ROOT/scripts/lib/render.sh"

pass=0; fail=0
check() { if [ "$2" = "$3" ]; then printf '  PASS  %s\n' "$1"; pass=$((pass+1));
          else printf '  FAIL  %s (expected %q, got %q)\n' "$1" "$3" "$2" >&2; fail=$((fail+1)); fi; }

command -v busctl >/dev/null 2>&1 || { echo "  SKIP  busctl not available"; exit 0; }
[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] || { echo "  SKIP  no session bus"; exit 0; }
python3 -c "import gi; gi.require_version('Gio','2.0')" 2>/dev/null || { echo "  SKIP  python-gobject not installed"; exit 0; }

# A name of its own: the installed daemon may be running on this bus, and two
# daemons answering one name is the thing the daemon itself refuses to do.
TEST_NAME="com.remappr.ShellTest$$"
DAEMON="$SANDBOX/windowsd"
render_template "$REPO_ROOT/bin/windowsd.py.in" "$DAEMON"
sed -i "s|\"$DBUS_NAME\"|\"$TEST_NAME\"|g; s|f\"{INTERFACE}\"|f\"{INTERFACE}\"|" "$DAEMON"
python3 - "$DAEMON" "$TEST_NAME" <<'PY'
import re, sys
path, name = sys.argv[1], sys.argv[2]
src = open(path).read()
src = re.sub(r'^BUS_NAME = .*$', f'BUS_NAME = "{name}"', src, flags=re.M)
src = re.sub(r'^INTERFACE = .*$', f'INTERFACE = "{name}.Windows"', src, flags=re.M)
open(path, 'w').write(src)
PY

python3 "$DAEMON" & DAEMON_PID=$!
for _ in $(seq 1 40); do
    busctl --user --json=short call "$TEST_NAME" /Windows "$TEST_NAME.Windows" List >/dev/null 2>&1 && break
    sleep 0.25
done

call() { busctl --user --json=short call "$TEST_NAME" /Windows "$TEST_NAME.Windows" "$@" 2>/dev/null; }
list()  { call List | jq -r '.data[0]'; }

check "starts empty"          "$(list)" "[]"

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

# The signal is what the shell actually follows.
monitor_out="$SANDBOX/monitor.json"
timeout 4 busctl --user --json=short monitor --match "type='signal',interface='$TEST_NAME.Windows'" > "$monitor_out" 2>&1 &
sleep 1
call Update s "$WINDOW" >/dev/null
sleep 2
check "announces a change"     "$(grep -c '"member":"Changed"' "$monitor_out")" "1"

# KWin repeats itself -- the same list arrives again on events that changed
# nothing -- and a signal per repeat would wake the shell for no reason.
: > "$monitor_out"
timeout 4 busctl --user --json=short monitor --match "type='signal',interface='$TEST_NAME.Windows'" > "$monitor_out" 2>&1 &
sleep 1
call Update s "$WINDOW" >/dev/null
sleep 2
check "says nothing when nothing changed" "$(grep -c '"member":"Changed"' "$monitor_out")" "0"

# Icon extraction. The parsing is what matters here: `_NET_WM_ICON` arrives
# from another application, holds several sizes one after another, and a
# malformed one must yield nothing rather than an exception in the daemon
# everything else depends on.
echo "== icons taken from the windows themselves =="
python3 - "$REPO_ROOT" <<'PYTEST'
import sys, importlib.util, re, os
repo = sys.argv[1]
src = open(f"{repo}/bin/windowsd.py.in").read()
for k, v in {"@DBUS_NAME@": "com.example.T", "@DISPLAY_NAME@": "T", "@SLUG@": "t"}.items():
    src = src.replace(k, v)
mod = {}
exec(compile(src, "windowsd", "exec"), mod)
largest = mod["WindowIcons"]._largest

def case(name, values, expect):
    got = largest(values)
    ok = (got is None and expect is None) or (got is not None and (got[0], got[1]) == expect)
    print(f"  {'PASS' if ok else 'FAIL'}  {name}")
    return ok

fails = 0
# One 2x2 icon.
fails += not case("reads a single size", [2, 2] + [0] * 4, (2, 2))
# Two sizes: the bigger one wins, because it is the one worth drawing.
fails += not case("prefers the larger size", [2, 2] + [0] * 4 + [4, 4] + [0] * 16, (4, 4))
# Absurd dimensions and truncated data are what a malformed property looks like.
fails += not case("refuses absurd dimensions", [99999, 99999, 1], None)
fails += not case("refuses truncated data", [4, 4, 1, 2, 3], None)
fails += not case("refuses nothing at all", [], None)
fails += not case("refuses a zero size", [0, 0], None)
# A size beyond what a panel would draw is skipped, but a usable one after it
# is still found.
fails += not case("skips a size too large to draw", [512, 1] + [0] * 512 + [8, 1] + [0] * 8, (8, 1))
sys.exit(1 if fails else 0)
PYTEST
if [ $? -eq 0 ]; then pass=$((pass+7)); else fail=$((fail+1)); fi

echo
if [ "$fail" -gt 0 ]; then printf 'FAILED: %d passed, %d failed\n' "$pass" "$fail" >&2; exit 1; fi
printf 'OK: %d passed\n' "$pass"
