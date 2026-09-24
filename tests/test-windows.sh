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
source "$REPO_ROOT/tests/lib/harness.sh"
harness_init
source "$REPO_ROOT/scripts/lib/render.sh"
DAEMON_PID=""
harness_on_exit '[ -n "$DAEMON_PID" ] && kill "$DAEMON_PID" 2>/dev/null'

# KWin's own window behaviour: kwinrc keys, written through the ledger. What
# matters is that a bad value never reaches kwinrc, that a write is recorded
# with what was there before, and that revert puts it back exactly -- an
# unset key deleted again rather than left empty.
echo "== KWin's window behaviour =="
BEHAVE=("$REPO_ROOT/scripts/windows.sh" behaviour)
behave() { env "$NO_SESSION_VAR=1" PATH="$FAKES:$PATH" "${BEHAVE[@]}" "$@" 2>&1; }
kwinrc_key() { kread kwinrc Windows "$1"; }

FAKES="$SANDBOX/fakes"
mkdir -p "$FAKES"
for cmd in qdbus6 busctl systemctl kquitapp6; do
    printf '#!/usr/bin/env bash\necho "$0 $*" >> %s/reached-kde.txt\nexit 0\n' "$SANDBOX" > "$FAKES/$cmd"
    chmod +x "$FAKES/$cmd"
done

check "an unknown setting is refused"    "$(behave set nosuch true >/dev/null 2>&1; echo $?)" "1"
check "a bool takes only true or false"  "$(behave set autoRaise sometimes >/dev/null 2>&1; echo $?)" "1"
check "an enum takes only its values"    "$(behave set focus Whatever >/dev/null 2>&1; echo $?)" "1"
check "a number outside the range"       "$(behave set focusDelay 99999 >/dev/null 2>&1; echo $?)" "1"
check "nothing was written by a refusal" "$(kwinrc_key FocusPolicy)" "<unset>"

behave set focus FocusFollowsMouse >/dev/null
check "focus policy written"             "$(kwinrc_key FocusPolicy)" "FocusFollowsMouse"
behave set borderlessMaximized true >/dev/null
check "borderless maximised written"     "$(kwinrc_key BorderlessMaximizedWindows)" "true"
check "status reads them back"           "$(behave status --json | jq -r '.settings[] | select(.id=="focus") | .value')" "FocusFollowsMouse"
check "and says what the default was"    "$(behave status --json | jq -r '.settings[] | select(.id=="focus") | .default')" "ClickToFocus"
check "the ledger has both"              "$(ledger_count windows-behaviour)" "2"

behave revert >/dev/null
check "revert deletes a key that was unset" "$(kwinrc_key FocusPolicy)" "<unset>"
check "and the other one too"               "$(kwinrc_key BorderlessMaximizedWindows)" "<unset>"
check "the ledger is empty again"           "$(ledger_count windows-behaviour)" "0"
check "nothing reached KDE"                 "$([ -f "$SANDBOX/reached-kde.txt" ] && cat "$SANDBOX/reached-kde.txt" || echo none)" "none"

command -v busctl >/dev/null 2>&1 || { echo "  SKIP  busctl not available"; exit 0; }
[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] || { echo "  SKIP  no session bus"; exit 0; }
python3 -c "import gi; gi.require_version('Gio','2.0')" 2>/dev/null || { echo "  SKIP  python-gobject not installed"; exit 0; }

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

# The guard that keeps this test off the user's keyboard. Checked here rather
# than only in the unit block below, because this is the copy that would do the
# damage: if it ever registers a component, the live session loses its keys.
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

# Closing a window writes the id into a KWin script's source, so anything
# that is not exactly a uuid must be refused before it gets that far -- and
# with no session, nothing may reach KWin at all.
echo "== closing a window =="
nosession() { env "$NO_SESSION_VAR=1" "$REPO_ROOT/scripts/windows.sh" "$@" 2>&1; }
out=$(nosession close 'a"); workspace.windowList().forEach(w => w.closeWindow()); ("'); status=$?
check "a script in place of an id is refused" "$status:$(printf '%s' "$out" | grep -c 'not a window id')" "1:1"
out=$(nosession close ''); status=$?
check "no id is refused"                      "$status" "1"
out=$(nosession close 1f46c057-675a-4d51-99e5-17aafdfb5b06); status=$?
check "no session, nothing closed"            "$status:$(printf '%s' "$out" | grep -c 'no session')" "1:1"

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

# A game's window carries whatever icon its engine set, and under Proton that
# is the generic rectangle Windows gives a window with none -- which is what
# the panel drew for World of Tanks. Steam has the real one on disk, in a
# directory of artwork where the *icon* is the one file named for its hash.
echo "== a Steam game's icon comes from Steam =="
python3 - "$REPO_ROOT" "$SANDBOX" <<'PYTEST'
import sys, os
repo, sandbox = sys.argv[1], sys.argv[2]
src = open(f"{repo}/bin/windowsd.py.in").read()
for k, v in {"@DBUS_NAME@": "com.example.T", "@DISPLAY_NAME@": "T", "@SLUG@": "t"}.items():
    src = src.replace(k, v)
mod = {}
exec(compile(src, "windowsd", "exec"), mod)

steam = os.path.join(sandbox, "steam")
lib = os.path.join(steam, "appcache", "librarycache", "1407200")
os.makedirs(os.path.join(lib, "4227fb8f00f8ae8db7f3bcdd76eb2fb8593eb6db"), exist_ok=True)
icon = os.path.join(lib, "3ba3158e913a637a1fbe033db4f88fccc52f1ff4.jpg")
for name in ("library_hero.jpg", "logo.png", "header.jpg", "library_600x900.jpg"):
    open(os.path.join(lib, name), "w").close()
open(icon, "w").close()
# The artwork also sits in hash-named *directories*, which are not the icon.
open(os.path.join(lib, "4227fb8f00f8ae8db7f3bcdd76eb2fb8593eb6db", "library_header.jpg"), "w").close()

class Steamy(mod["WindowIcons"]):
    STEAM_DIRS = (steam,)
    def __init__(self):
        self._cache, self._misses, self._available = {}, {}, False
        self.looks = 0
    def _x11_window_for(self, pid):
        self.looks += 1
        return None

fails = 0
def check(name, got, want):
    global fails
    ok = got == want
    print(f"  {'PASS' if ok else 'FAIL'}  {name}" + ("" if ok else f" (expected {want!r}, got {got!r})"))
    fails += 0 if ok else 1

check("the hash-named file is the icon", Steamy._steam_icon("steam_app_1407200"), icon)
check("the artwork beside it is not",    os.path.basename(Steamy._steam_icon("steam_app_1407200")), os.path.basename(icon))
check("a game Steam has nothing for",    Steamy._steam_icon("steam_app_4"), None)
check("an ordinary application",         Steamy._steam_icon("org.kde.dolphin"), None)
check("steam itself is not an app id",   Steamy._steam_icon("steam"), None)

# It is found without a display, and without touching the window at all.
probe = Steamy()
check("found with no X11 lookup",        (probe.path_for("steam_app_1407200", 1), probe.looks), (icon, 0))
# An icon Steam writes later is still picked up: the cheap check is not budgeted.
probe = Steamy()
probe.path_for("steam_app_4", 1)
late = os.path.join(steam, "appcache", "librarycache", "4")
os.makedirs(late, exist_ok=True)
late_icon = os.path.join(late, "a" * 40 + ".png")
open(late_icon, "w").close()
check("an icon written later is found",  probe.path_for("steam_app_4", 1), late_icon)
sys.exit(1 if fails else 0)
PYTEST
if [ $? -eq 0 ]; then pass=$((pass+7)); else fail=$((fail+1)); fi

# A lookup that found nothing is a fact about the moment, not about the
# application: `_NET_WM_ICON` is set a little after the window is mapped, so a
# window asked the instant it appears often has no icon yet. Keeping that
# answer for the life of the daemon is what "some icons are missing until I
# restart the shell" was -- the restart forgot, and that was the whole fix.
echo "== a missing icon is looked at again, a few times =="
python3 - "$REPO_ROOT" "$SANDBOX" <<'PYTEST'
import sys, os
repo, sandbox = sys.argv[1], sys.argv[2]
src = open(f"{repo}/bin/windowsd.py.in").read()
for k, v in {"@DBUS_NAME@": "com.example.T", "@DISPLAY_NAME@": "T", "@SLUG@": "t"}.items():
    src = src.replace(k, v)
mod = {}
exec(compile(src, "windowsd", "exec"), mod)

class Probe(mod["WindowIcons"]):
    """The real path_for, with the display replaced by a script of answers."""
    MISS_RETRY_SECONDS = 0.0        # the waiting is not what is under test

    def __init__(self, script):
        self._cache, self._misses, self._available = {}, {}, True
        self.script, self.looks = list(script), 0

    def _x11_window_for(self, pid):
        return "0x1"

    def _extract(self, window, app_id):
        self.looks += 1
        return self.script.pop(0) if self.script else None

fails = 0
def check(name, got, want):
    global fails
    ok = got == want
    print(f"  {'PASS' if ok else 'FAIL'}  {name}" + ("" if ok else f" (expected {want!r}, got {got!r})"))
    fails += 0 if ok else 1

icon = os.path.join(sandbox, "late.png")
open(icon, "w").close()

# Late, as Electron and Proton are: nothing twice, then an icon.
p = Probe([None, None, icon])
check("nothing on the first look",  p.path_for("late", 1), None)
check("nothing on the second",      p.path_for("late", 1), None)
check("and the icon on the third",  p.path_for("late", 1), icon)
check("three looks, not one",       p.looks, 3)
check("then it stops looking",      (p.path_for("late", 1), p.looks), (icon, 3))

# A window that really has no icon must not cost a display sweep for ever.
p = Probe([])
for _ in range(20):
    p.path_for("never", 1)
check("a real miss gives up",       p.looks, Probe.MISS_ATTEMPTS)

# The path is cached, not the picture, and a path can stop being true.
p = Probe([icon])
p.path_for("gone", 1)
os.unlink(icon)
check("a path that went away is read again", (p.path_for("gone", 1), p.looks), (None, 2))
sys.exit(1 if fails else 0)
PYTEST
if [ $? -eq 0 ]; then pass=$((pass+7)); else fail=$((fail+1)); fi

# The shortcuts the daemon owns. Two things can be checked without a session:
# that a key string becomes the integer kglobalaccel wants -- the same numbers
# scripts/lib/accel.sh is checked against, from the same measurements off a
# running server -- and that the component's group is read out of the file the
# way kglobalaccel writes it.
echo "== the shortcuts the daemon owns =="
python3 - "$REPO_ROOT" "$SANDBOX" <<'PYTEST'
import sys, os
repo, sandbox = sys.argv[1], sys.argv[2]
src = open(f"{repo}/bin/windowsd.py.in").read()
for k, v in {"@DBUS_NAME@": "com.example.T", "@DISPLAY_NAME@": "T", "@SLUG@": "t",
             "@BIN_DIR@": "/nowhere", "@CTL_BIN@": "t-ctl", "@ALIAS@": "t"}.items():
    src = src.replace(k, v)
mod = {}
exec(compile(src, "windowsd", "exec"), mod)
keycode, shortcuts = mod["keycode"], mod["GlobalShortcuts"]

fails = 0
def case(name, got, want):
    global fails
    ok = got == want
    fails += not ok
    print(f"  {'PASS' if ok else 'FAIL'}  {name}" + ("" if ok else f" (expected {want!r}, got {got!r})"))

for name, spec, want in [
    ("Print", "Print", 16777225),
    ("Meta+Shift+Print", "Meta+Shift+Print", 318767113),
    ("a letter is its ASCII", "Q", 81),
    ("lower case too", "q", 81),
    ("Meta+Space", "Meta+Space", 268435488),
    ("a function key", "F5", 16777268),
    ("Alt+Tab", "Alt+Tab", 150994945),
    ("every modifier at once", "Meta+Alt+Ctrl+Shift+Delete", 520093703),
    ("Meta alone is a key", "Meta", 16777250),
    ("a modifier nobody knows", "Hyper+Q", None),
    ("a key nobody knows", "Meta+Banana", None),
    ("nothing at all", "", None),
    ("Meta+/, as the file spells it", "Meta+/", 268435503),
    ("Meta+Slash, spelled out", "Meta+Slash", 268435503),
    ("Meta+Shift+S", "Meta+Shift+S", 301989971),
]:
    case(name, keycode(spec), want)

# The file as kglobalaccel keeps it: a component's group, three fields, a tab
# between two keys written as a literal backslash-t.
config = os.path.join(sandbox, "kglobalshortcutsrc")
os.environ["XDG_CONFIG_HOME"] = sandbox
open(config, "w").write(
    "[somebodyelse]\n"
    "launcher=Meta+X,none,Not ours\n"
    "\n"
    "[t]\n"
    "launcher=Meta,none,Application menu\n"
    "search=none,none,Search\n"
    "switcher=Alt+Tab\\tMeta+F1,none,Window switcher\n"
    "nosuchaction=Meta+Z,none,Unknown\n"
)
found = shortcuts.bindings()
case("reads our group only", found.get("launcher"), ["Meta"])
case("an unbound action is empty", found.get("search"), [])
case("two keys on one action", found.get("switcher"), ["Alt+Tab", "Meta+F1"])
case("an action we do not know is ignored", "nosuchaction" in found, False)

# Ownership: only the daemon holding the shell's own bus name claims the
# shell's keys. A second copy that did would take them off the first, on the
# live session, which is what the test suite itself once did.
wanted = mod["shortcuts_wanted"]
os.environ.pop(mod["NO_SESSION_VAR"], None)
mod["BUS_NAME"] = mod["SHORTCUT_OWNER"]
case("the daemon that owns the name claims them", wanted(), True)
mod["BUS_NAME"] = mod["SHORTCUT_OWNER"] + "Test1234"
case("a copy under another name claims nothing", wanted(), False)
mod["BUS_NAME"] = mod["SHORTCUT_OWNER"]
os.environ[mod["NO_SESSION_VAR"]] = "1"
case("and neither does one with no session", wanted(), False)

sys.exit(1 if fails else 0)
PYTEST
if [ $? -eq 0 ]; then pass=$((pass+19)); else fail=$((fail+1)); fi

harness_done
