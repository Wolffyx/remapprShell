#!/usr/bin/env bash
# Tests how the session daemon finds a window's own icon, inside a throwaway
# HOME: which of the display's windows it is, and when a lookup is made
# again.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/tests/lib/harness.sh"
harness_init
source "$REPO_ROOT/tests/lib/windowsd.sh"
windowsd_require
windowsd_example

# Which X11 window a window is. KWin names no X11 window to a script, so the
# daemon finds it among the display's managed windows -- and "the first window
# of this process" was the wrong answer for a process with several: a helper
# window's stock icon stood for the application's own. The class must agree,
# and the title decides between windows that share it.
echo "== a window's icon comes from that window =="
windowsd_python <<'PYTEST'
from windowsd.icons import WindowIcons
pick, parse = WindowIcons.pick_client, WindowIcons.client

# One process with a helper window listed first and two windows of its own,
# and another process.
clients = [
    {"id": "0xa1", "pid": 7, "instance": "helper",  "class": "Example.Viewer", "name": "Default"},
    {"id": "0xa2", "pid": 7, "instance": "viewer",  "class": "Example.Viewer", "name": "Main"},
    {"id": "0xa3", "pid": 7, "instance": "viewer",  "class": "Example.Viewer", "name": "Second"},
    {"id": "0xa4", "pid": 7, "instance": "tool",    "class": "Example.Tool",   "name": "Tool"},
    {"id": "0xb1", "pid": 8, "instance": "other",   "class": "Other",          "name": "Other"},
]
def window(**over):
    w = {"pid": 7, "appId": "example.viewer", "resourceName": "viewer", "title": "Somewhere"}
    w.update(over)
    return w

check("not the process's first window",           pick(window(), clients, set()), "0xa2")
check("the one with this title",                  pick(window(title="Second"), clients, set()), "0xa3")
check("a title KWin numbered finds its window",   pick(window(title="Second <2>"), clients, set()), "0xa3")
check("not one another window already is",        pick(window(title="Second"), clients, {"0xa3"}), "0xa2")
check("the class decides, not the process",       pick(window(appId="example.tool", resourceName="tool"), clients, set()), "0xa4")
check("no window of that class, no icon",         pick(window(appId="example.missing"), clients, set()), None)
check("another process's window is not this one", pick(window(pid=9, appId="other", resourceName="other"), clients, set()), None)
check("without an instance name the class will do",
      pick({"pid": 8, "appId": "other", "title": ""}, clients, set()), "0xb1")

# What xprop says about a window, read back.
props = ('_NET_WM_PID(CARDINAL) = 4242\n'
         'WM_CLASS(STRING) = "inst", "Klass"\n'
         '_NET_WM_NAME(UTF8_STRING) = "A \\"quoted\\" title"\n')
check("xprop's answer read",   parse("0x1", props),
      {"id": "0x1", "pid": 4242, "instance": "inst", "class": "Klass", "name": 'A "quoted" title'})
check("a window with none of it", parse("0x2", "_NET_WM_PID:  not found.\n"),
      {"id": "0x2", "pid": 0, "instance": "", "class": "", "name": ""})
PYTEST

# A lookup that found nothing is a fact about the moment, not about the
# window: `_NET_WM_ICON` is set a little after the window is mapped, so a
# window asked the instant it appears often has no icon yet. Keeping that
# answer for the life of the daemon is what "some icons are missing until I
# restart the shell" was -- the restart forgot, and that was the whole fix.
# A hit is kept only until KWin says the icon changed: a program that set its
# own icon over its toolkit's first one was otherwise drawn with the first.
echo "== a window's icon is looked at again when it may have changed =="
windowsd_python "$SANDBOX" <<'PYTEST'
import sys, os, json
from windowsd.gio import GLib
from windowsd.icons import WindowIcons
from windowsd.windowlist import WindowList
sandbox = sys.argv[1]

class Probe(WindowIcons):
    """The real path_for, with the display replaced by a script of answers."""
    MISS_DELAYS = (0.0,) * 6        # the waiting is not what is under test

    def __init__(self, script):
        self._x11, self._icons, self._misses, self._written = {}, {}, {}, set()
        self._clients, self._available = None, True
        self.script, self.looks = list(script), 0

    def _x11_window_for(self, uuid, window):
        return "0x1"

    def _extract(self, window):
        self.looks += 1
        return self.script.pop(0) if self.script else None

def icon(name):
    path = os.path.join(sandbox, name)
    open(path, "w").close()
    return path

def window(uuid="w", serial=0):
    return {"uuid": uuid, "pid": 1, "iconSerial": serial}

# Late, as a toolkit often is: nothing twice, then an icon.
late = icon("late.png")
p = Probe([None, None, late])
check("nothing on the first look",  p.path_for(window()), None)
check("nothing on the second",      p.path_for(window()), None)
check("and the icon on the third",  p.path_for(window()), late)
check("three looks, not one",       p.looks, 3)
check("then it stops looking",      (p.path_for(window()), p.looks), (late, 3))

# The program set its own icon over the first: KWin says so, and it is read
# again however good the copy already kept looked.
first, own = icon("first.png"), icon("own.png")
p = Probe([first, own])
p.path_for(window(serial=0))
check("an icon KWin says changed is read again", (p.path_for(window(serial=1)), p.looks), (own, 2))
check("and kept until it changes again",         (p.path_for(window(serial=1)), p.looks), (own, 2))

# A window that really has no icon must not cost a display sweep for ever --
# until KWin says it has one after all.
p = Probe([])
for _ in range(20):
    p.path_for(window("never"))
check("a real miss gives up",           p.looks, len(Probe.MISS_DELAYS))
p.path_for(window("never", serial=1))
check("until KWin announces a change",  p.looks, len(Probe.MISS_DELAYS) + 1)

# A miss is looked at again on a clock, soon: the first retry is a tenth of a
# second away, not three seconds and KWin's next event (2026-09-24).
class Timed(Probe):
    MISS_DELAYS = WindowIcons.MISS_DELAYS
p = Timed([])
check("nothing to wait for before a miss", p.next_look(), None)
p.path_for(window("late"))
wait = p.next_look()
check("a miss is tried again within a tenth of a second", wait is not None and 0 < wait <= 0.1, True)
p = Timed([late])
p.path_for(window("found"))
check("and a window with its icon asks for nothing", p.next_look(), None)

# The window list sends itself again when a late icon turns up, with nothing
# else having happened on screen.
wl = WindowList()
wl._icons = Probe([None, late])
wl.update(json.dumps([{"uuid": "slow", "pid": 1, "iconSerial": 0, "title": "t"}]))
check("the first list goes without the icon", "iconPath" in json.loads(wl._json)[0], False)
wl._relook()
check("the next look sends it with the icon", json.loads(wl._json)[0].get("iconPath"), late)
if wl._relook_id:
    GLib.source_remove(wl._relook_id)

# The path is cached, not the picture, and a path can stop being true.
gone = icon("gone.png")
p = Probe([gone])
p.path_for(window("gone"))
os.unlink(gone)
check("a path that went away is read again", (p.path_for(window("gone")), p.looks), (None, 2))

# Per window, not per application: the second window of a program is asked
# for its own icon rather than handed the first one's.
one, two = icon("one.png"), icon("two.png")
p = Probe([one, two])
check("each window has its own",   [p.path_for(window("a")), p.path_for(window("b"))], [one, two])
check("a window with no process is not looked for",
      (p.path_for({"uuid": "x"}), p.path_for({"uuid": "y", "pid": 0}), p.looks), (None, None, 2))

# Kept while the window is there, and not after: a window that went takes its
# file with it -- but only a file this copy of the daemon wrote.
mine, foreign = icon("mine.png"), icon("foreign.png")
p = Probe([])
p._written.add(mine)
p._icons.update({"went": (0, mine), "stays": (0, one), "stranger": (0, foreign)})
p._x11.update({"went": "0x5", "stays": "0x6"})
p.forget_all_but({"stays"})
check("a window that went takes its icon with it",   os.path.exists(mine), False)
check("and what was found out about it",             ("went" in p._x11, "went" in p._icons), (False, False))
check("a window still there keeps its own",          (p._icons.get("stays"), p._x11.get("stays")), ((0, one), "0x6"))
check("a file this copy did not write is left alone", os.path.exists(foreign), True)
PYTEST

harness_done
