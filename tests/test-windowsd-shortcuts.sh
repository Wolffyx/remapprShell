#!/usr/bin/env bash
# Tests the global shortcuts the session daemon owns, inside a throwaway HOME.
#
# The CLI that binds them is tested in test-shortcuts.sh, which also checks
# that the daemon and the CLI agree on every key.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/tests/lib/harness.sh"
harness_init
source "$REPO_ROOT/tests/lib/windowsd.sh"
windowsd_require
windowsd_example

# The shortcuts the daemon owns. Two things can be checked without a session:
# that a key string becomes the integer kglobalaccel wants -- the same numbers
# scripts/lib/accel.sh is checked against, from the same measurements off a
# running server -- and that the component's group is read out of the file the
# way kglobalaccel writes it.
echo "== the shortcuts the daemon owns =="
windowsd_python "$SANDBOX" <<'PYTEST'
import sys, os
from windowsd import brand, shortcuts
from windowsd.keys import keycode
sandbox = sys.argv[1]

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
    check(name, keycode(spec), want)

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
found = shortcuts.GlobalShortcuts.bindings()
check("reads our group only", found.get("launcher"), ["Meta"])
check("an unbound action is empty", found.get("search"), [])
check("two keys on one action", found.get("switcher"), ["Alt+Tab", "Meta+F1"])
check("an action we do not know is ignored", "nosuchaction" in found, False)

# Ownership: only the daemon holding the shell's own bus name claims the
# shell's keys. A second copy that did would take them off the first, on the
# live session, which is what the test suite itself once did.
wanted = shortcuts.shortcuts_wanted
os.environ.pop(shortcuts.NO_SESSION_VAR, None)
brand.BUS_NAME = shortcuts.SHORTCUT_OWNER
check("the daemon that owns the name claims them", wanted(), True)
brand.BUS_NAME = shortcuts.SHORTCUT_OWNER + "Test1234"
check("a copy under another name claims nothing", wanted(), False)
brand.BUS_NAME = shortcuts.SHORTCUT_OWNER
os.environ[shortcuts.NO_SESSION_VAR] = "1"
check("and neither does one with no session", wanted(), False)
PYTEST

# kglobalaccel lives inside kwin_wayland, so a KWin that crashes and is started
# again -- a GPU reset -- brings back a server that has the keys on file and no
# owner for them. The daemon outlives KWin and has to register again by itself.
# A bus of its own here, recording, so nothing reaches the session.
echo "== registered again when kglobalaccel comes back =="
windowsd_python "$SANDBOX" <<'PYTEST'
import sys, os
from windowsd import shortcuts
sandbox = sys.argv[1]
os.environ["XDG_CONFIG_HOME"] = sandbox
open(os.path.join(sandbox, "kglobalshortcutsrc"), "w").write(
    "[t]\nlauncher=Meta,none,Application menu\nsearch=Meta+Space,none,Search\n"
)

class Bus:
    def __init__(self):
        self.subscriptions = []
        self.calls = []
    def signal_subscribe(self, sender, iface, member, path, arg0, flags, callback, data):
        self.subscriptions.append((sender, member, arg0, callback))
        return len(self.subscriptions)
    def call_sync(self, name, path, iface, method, params, *rest):
        self.calls.append(method)

bus = Bus()
keys = shortcuts.GlobalShortcuts()
ran = []
keys._run = lambda action, command: ran.append(action)
keys.start(bus)

watch = [s for s in bus.subscriptions if s[1] == "NameOwnerChanged"]
check("it watches the server's name", [(s[0], s[2]) for s in watch],
      [("org.freedesktop.DBus", "org.kde.kglobalaccel")])
registered = bus.calls.count("setShortcutKeys")
check("every action is registered at start", registered, len(shortcuts.SHORTCUT_ACTIONS))
on_owner = watch[0][3]

bus.calls.clear()
on_owner(None, None, None, None, None, ("org.kde.kglobalaccel", ":1.40", ""), None)
check("the server going away registers nothing", bus.calls, [])
check("and enforces nothing", ran, [])

on_owner(None, None, None, None, None, ("org.kde.kglobalaccel", "", ":1.896"), None)
check("the server coming back registers every action again",
      bus.calls.count("setShortcutKeys"), registered)
check("and enforces the configuration again", ran, ["sync"])

bus.calls.clear()
on_owner(None, None, None, None, None, ("org.kde.somebodyelse", "", ":1.9"), None)
check("another name coming and going is not ours", bus.calls, [])
PYTEST

# An edge names an action. One a key could run is run, as a key would run it;
# one that is the shell's own -- lighting the sidebar's grab strip -- is
# announced for the shell to hear rather than run.
echo "== an edge, run or announced =="
windowsd_python "$SANDBOX" <<'PYTEST'
from windowsd import edges

class Bus:
    def __init__(self):
        self.signals = []
    def emit_signal(self, dest, path, iface, name, params):
        self.signals.append((path, iface, name, params.unpack()))

class Call:
    def __init__(self):
        self.answered = False
    def return_value(self, value):
        self.answered = True

class Keys:
    def __init__(self):
        self.ran = []
    def _run(self, action, command):
        self.ran.append(action)

keys = Keys()
screen = edges.ScreenEdges(keys)
bus = Bus()

call = Call()
screen.handle_call(bus, None, None, None, "Triggered", ("launcher",), call)
check("a key's action is run", keys.ran, ["launcher"])
check("and not announced", bus.signals, [])
check("and answered", call.answered, True)

call = Call()
screen.handle_call(bus, None, None, None, "Triggered", ("sidebar-reveal",), call)
check("the shell's own is announced, from nowhere in particular",
      bus.signals, [("/Edges", "com.example.T.Edges", "Reached", ("sidebar-reveal", -1, -1, ""))])
check("and not run", keys.ran, ["launcher"])
check("and answered too", call.answered, True)

# Where the pointer was pushed in, from a script that says: the grip goes
# there, and the sidebar onto that screen.
bus.signals.clear()
call = Call()
screen.handle_call(bus, None, None, None, "TriggeredAt", ("sidebar-open", 3999, 812, "DP-3"), call)
check("an edge that says where is announced with it",
      bus.signals, [("/Edges", "com.example.T.Edges", "Reached", ("sidebar-open", 3999, 812, "DP-3"))])
check("and answered", call.answered, True)

call = Call()
screen.handle_call(bus, None, None, None, "TriggeredAt", ("keys", 0, 0, "DP-2"), call)
check("a key's action from TriggeredAt is still run", keys.ran, ["launcher", "keys"])
check("and not announced", len(bus.signals), 1)

# A shared edge: the pointer at rest in the last column, and gone again --
# passed on as it is, for the shell to time.
bus.signals.clear()
call = Call()
screen.handle_call(bus, None, None, None, "Resting", ("sidebar-reveal", 2559, 1500, "DP-2", True), call)
screen.handle_call(bus, None, None, None, "Resting", ("sidebar-reveal", 2559, 1500, "DP-2", False), call)
check("a resting pointer is passed on, and its leaving",
      bus.signals, [("/Edges", "com.example.T.Edges", "Resting", ("sidebar-reveal", 2559, 1500, "DP-2", True)),
                    ("/Edges", "com.example.T.Edges", "Resting", ("sidebar-reveal", 2559, 1500, "DP-2", False))])
check("and answered", call.answered, True)
screen.handle_call(bus, None, None, None, "Resting", ("launcher", 2559, 1500, "DP-2", True), call)
check("a key's action is never run on a rest", (keys.ran, len(bus.signals)), (["launcher", "keys"], 2))
PYTEST

harness_done
