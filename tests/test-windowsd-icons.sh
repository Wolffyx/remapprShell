#!/usr/bin/env bash
# Tests the icon a window carries itself, as the session daemon reads and
# writes it, inside a throwaway HOME: the property parsed, where the file
# goes, and what that work costs on the thread that answers D-Bus.
set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_ROOT/tests/lib/harness.sh"
harness_init
source "$REPO_ROOT/tests/lib/windowsd.sh"
windowsd_require
windowsd_example

# Icon extraction. The parsing is what matters here: `_NET_WM_ICON` arrives
# from another application, holds several sizes one after another, and a
# malformed one must yield nothing rather than an exception in the daemon
# everything else depends on.
echo "== icons taken from the windows themselves =="
windowsd_python <<'PYTEST'
from windowsd.icons import WindowIcons
largest = WindowIcons._largest

def case(name, values, expect):
    got = largest(values)
    check(name, None if got is None else (got[0], got[1]), expect)

# One 2x2 icon.
case("reads a single size", [2, 2] + [0] * 4, (2, 2))
# Two sizes: the bigger one wins, because it is the one worth drawing.
case("prefers the larger size", [2, 2] + [0] * 4 + [4, 4] + [0] * 16, (4, 4))
# Absurd dimensions and truncated data are what a malformed property looks like.
case("refuses absurd dimensions", [99999, 99999, 1], None)
case("refuses truncated data", [4, 4, 1, 2, 3], None)
case("refuses nothing at all", [], None)
case("refuses a zero size", [0, 0], None)
# A size beyond what a panel would draw is skipped, but a usable one after it
# is still found.
case("skips a size too large to draw", [512, 1] + [0] * 512 + [8, 1] + [0] * 8, (8, 1))
PYTEST

# Where the icons are written. A copy of what a window holds is worth keeping
# only while the window can be, so they go to the session's runtime
# directory, which logout empties -- not the state directory, where they
# outlived every session. The directories are the user's alone.
echo "== window icons live in the session's runtime directory =="
windowsd_python "$SANDBOX" <<'PYTEST'
import sys, os, io, stat, tempfile, contextlib
from windowsd.icons import icon_dir
sandbox = sys.argv[1]

def mode(path):
    return oct(stat.S_IMODE(os.stat(path).st_mode))

run = os.path.join(sandbox, "run")
os.makedirs(run, mode=0o700)
os.environ["XDG_RUNTIME_DIR"] = run
found = icon_dir()
check("under the runtime directory",       found, os.path.join(run, "t", "window-icons"))
check("private all the way down",          [mode(os.path.join(run, "t")), mode(found)], ["0o700", "0o700"])
check("the same one when asked again",     icon_dir(), found)
check("nothing in the state directory",    os.path.exists(os.path.join(os.environ["XDG_STATE_HOME"], "t")), False)

# No runtime directory, or one that cannot be written: a directory of the
# daemon's own in the temporary one, made once rather than once an icon.
tmp = os.path.join(sandbox, "tmp")
os.makedirs(tmp)
tempfile.tempdir = tmp
del os.environ["XDG_RUNTIME_DIR"]
said = io.StringIO()
with contextlib.redirect_stderr(said):
    fallback = icon_dir()
    again = icon_dir()
check("without one, a private directory",  (os.path.dirname(fallback), mode(fallback)), (tmp, "0o700"))
check("made once, not once an icon",       again, fallback)
check("and it says where",                 fallback in said.getvalue(), True)
os.environ["XDG_RUNTIME_DIR"] = os.path.join(sandbox, "not-a-directory")
open(os.environ["XDG_RUNTIME_DIR"], "w").close()
with contextlib.redirect_stderr(io.StringIO()):
    check("an unusable one falls back too", icon_dir(), fallback)
PYTEST

# Both run on the thread that answers D-Bus, so both are about time. Finding
# the display's windows is an xprop per window on it, and it was done again
# for every window in an update that had no icon yet; and the icon's pixels
# were reordered one at a time in Python.
echo "== the daemon's icon work, once an update and not pixel by pixel =="
windowsd_python "$SANDBOX" <<'PYTEST'
import sys, os
import windowsd.icons
from windowsd.icons import WindowIcons
sandbox = sys.argv[1]

class Counting(WindowIcons):
    def __init__(self):
        self._x11, self._icons, self._misses, self._written = {}, {}, {}, set()
        self._clients, self._available = None, True
        self.sweeps, self.asked = 0, []
    def _x11_clients(self):
        self.sweeps += 1
        return [{"id": "0x1", "pid": 1, "instance": "", "class": "a", "name": ""},
                {"id": "0x2", "pid": 2, "instance": "", "class": "b", "name": ""}]
    def _extract(self, window):
        self.asked.append(window)
        return None

icons = Counting()
icons.new_update()
for uuid, app, pid in (("u1", "a", 1), ("u2", "b", 2), ("u3", "c", 3)):
    icons.path_for({"uuid": uuid, "appId": app, "pid": pid})
check("one sweep for a whole update", icons.sweeps, 1)
check("and every window found in it", icons.asked, ["0x1", "0x2"])
icons.new_update()
icons.path_for({"uuid": "u4", "appId": "c", "pid": 3})
check("the next update sweeps again", icons.sweeps, 2)
icons.new_update()
icons.path_for({"uuid": "u1", "appId": "a", "pid": 1, "iconSerial": 1})
check("a window found once is not looked for again", (icons.sweeps, icons.asked[-1]), (2, "0x1"))

try:
    from PIL import Image
except ImportError:
    print("  SKIP  Pillow is not installed; the pixels were not checked")
    sys.exit(0)

# Two pixels, as xprop prints the property: opaque blue, and black at 0x81.
class Run:
    stdout = "_NET_WM_ICON(CARDINAL) = 2, 1, 4278190335, 2164260864"
class FakeSubprocess:
    @staticmethod
    def run(*_args, **_kwargs):
        return Run()
windowsd.icons.subprocess = FakeSubprocess
run = os.path.join(sandbox, "run-pixels")
os.makedirs(run, mode=0o700)
os.environ["XDG_RUNTIME_DIR"] = run
extract = WindowIcons._extract
path = extract(icons, "0x1")
image = Image.open(path)
check("written to the runtime directory", os.path.dirname(path), os.path.join(run, "t", "window-icons"))
check("named for the window",     os.path.basename(path).startswith("0x1-"), True)
check("the icon is its size",     image.size, (2, 1))
check("ARGB read as RGBA",        [image.getpixel((0, 0)), image.getpixel((1, 0))],
                                  [(0, 0, 255, 255), (0, 0, 0, 0x81)])
# The shell keeps a picture for as long as its URL is the same: a new icon on
# the same window must be a new file, and the same one read again need not be.
check("the same icon is the same file", extract(icons, "0x1"), path)
Run.stdout = "_NET_WM_ICON(CARDINAL) = 1, 1, 4278190335"
check("a new icon is a new file",       extract(icons, "0x1") != path, True)
PYTEST

harness_done
