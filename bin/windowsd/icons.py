"""The icon a window carries itself, made into a file the shell can draw."""

import hashlib
import os
import re
import subprocess
import sys
import tempfile
import time
from array import array

from . import brand

# An array typecode four bytes wide, which is what one pixel is.
_U32 = "I" if array("I").itemsize == 4 else "L"


# Where the icons taken from windows are written: this login's runtime
# directory, which the system empties at logout.
#
# They used to go under the state directory, which outlives the session -- a
# folder that kept a picture of every program ever opened, long after the
# windows were gone. Nothing is lost by keeping them only for the session:
# each file is a copy of what a window still holds, and the daemon makes it
# again the first time it sees that window after the next login.
#
# Without XDG_RUNTIME_DIR, which a systemd login always sets, a directory of
# the daemon's own under the system's temporary directory stands in: made
# fresh for this process and readable by nobody else, so no other user can
# have put anything there first. That one lasts until the temporary directory
# is next cleared rather than until logout.
_icon_fallback = None


def icon_dir():
    """The directory window icons are written to, made on first use."""
    global _icon_fallback
    runtime = os.environ.get("XDG_RUNTIME_DIR", "")
    if runtime:
        path = runtime
        try:
            # One level at a time: makedirs gives its mode to the last
            # directory only, and ours should be private all the way down.
            for part in (brand.SLUG, "window-icons"):
                path = os.path.join(path, part)
                os.makedirs(path, mode=0o700, exist_ok=True)
            return path
        except OSError as exc:
            print(f"cannot write window icons under {runtime}: {exc}", file=sys.stderr)
    if _icon_fallback is None or not os.path.isdir(_icon_fallback):
        _icon_fallback = tempfile.mkdtemp(prefix=brand.SLUG + "-window-icons-")
        print(f"no usable XDG_RUNTIME_DIR; window icons go to {_icon_fallback}",
              file=sys.stderr)
    return _icon_fallback


class WindowIcons:
    """Icons taken from the windows themselves.

    Plasma's task manager draws a window with its application's icon, and where
    the application has no icon it can use -- or no application matched at all
    -- with the icon the window carries, as KWin reports it. On X11 that is
    `_NET_WM_ICON`, a property of the window itself, and the window is the only
    place that icon exists. The shell decides which of the two to draw; this
    makes the window's own one something it can draw.

    Why it has to become a file. The shell draws every icon from a URL: a name
    the icon theme turns into a file, or a file itself. `_NET_WM_ICON` is
    neither. It is raw pixels stored on the window, with no name to look up
    and nothing on disk, and QML has no way to read a property off another
    program's X11 window. So the daemon reads the pixels with `xprop`, writes
    them out as a PNG in the session's runtime directory (see `icon_dir`), and
    hands the shell the path. Sending the pixels instead would put up to
    65,536 of them, written out as numbers, into every window list the shell
    is sent.

    One window, and that window's icon. KWin gives a script no way to name an
    X11 window -- nothing in KWin 6's scripting API carries its id -- so the
    window is found among the display's managed windows by what KWin does
    say: the process, the class and the title. The process alone is not
    enough. One process can own several windows, and taking the first of them
    took whichever the display happened to list first -- and the copy was then
    kept for every window of the application, for as long as the daemon ran.
    So a window of the same process is taken only with the same class, the
    title decides between several, and what is written is kept per window and
    dropped when the window goes.

    It is read again when KWin says the window's icon changed -- `iconSerial`,
    which the KWin script counts. A program often sets its own icon a moment
    after its window appears, over the one its toolkit put there first, and a
    copy taken in between was otherwise kept for the life of the window. That
    is the signal Plasma's own task list redraws on.

    Reading needs `xprop` and writing needs Pillow; where either is missing
    this does nothing at all and the shell falls back to the icon theme. A
    Wayland-native window has no `_NET_WM_ICON` and no X11 window to find, and
    falls back the same way.
    """

    # How often a lookup that found nothing is tried again, and how many times.
    #
    # A miss is a fact about the moment, not about the window: KWin can report
    # a window a moment before the display lists it, and a toolkit sets
    # `_NET_WM_ICON` a little after the window is mapped. Keeping that answer
    # for the life of the daemon is the whole of "some icons are missing until
    # I restart the shell": the restart was doing nothing but forgetting.
    #
    # Tried again on a clock of its own, soon and then less often: a tenth of
    # a second, a quarter, a half, one, two, four. The retry used to wait
    # three seconds *and* for KWin's next event, so a game whose window was
    # listed a moment after KWin announced it showed the wrong icon for
    # seconds -- reported 2026-09-24 as "the icon takes at least a second".
    # A look costs a few milliseconds here (one `xprop` sweep of the
    # display's managed windows, 5 ms for three), so six of them over eight
    # seconds is nothing, and then it stops -- which is also all a
    # Wayland-native window costs, there being no X11 window to find for it.
    # An icon change KWin announces starts the count again.
    MISS_DELAYS = (0.1, 0.25, 0.5, 1.0, 2.0, 4.0)

    def __init__(self):
        self._x11 = {}            # uuid -> the X11 window it is, once found
        self._icons = {}          # uuid -> (iconSerial, path or None)
        self._misses = {}         # uuid -> (attempts, monotonic of the last)
        self._written = set()     # files this process wrote: the only ones it removes
        self._clients = None      # the display's managed windows, for one update
        self._available = self._check()

    @staticmethod
    def _check():
        try:
            subprocess.run(["xprop", "-version"], capture_output=True, timeout=5, check=True)
        except (OSError, subprocess.SubprocessError):
            return False
        try:
            import PIL.Image  # noqa: F401
        except ImportError:
            return False
        return bool(os.environ.get("DISPLAY"))

    def path_for(self, window):
        """The icon this window carries, written out as a PNG, or None."""
        uuid = str(window.get("uuid") or "")
        pid = window.get("pid")
        if not self._available or not uuid or not isinstance(pid, int) or pid <= 0:
            return None

        serial = window.get("iconSerial", 0)
        known = self._icons.get(uuid)
        if known is not None and known[0] == serial:
            # What is cached is a path, not a picture, and a path can stop
            # being true: whatever empties the directory takes the file out
            # from under it. The shell was then handed a path to a file that
            # is gone, drew nothing, and said so only in the journal. So a hit
            # is trusted only while the file behind it is still there.
            if known[1] is not None and os.path.exists(known[1]):
                return known[1]
            # A miss is kept too, or every update would sweep the display for
            # the windows that genuinely have no icon -- for a while and a few
            # tries, not for ever: see the constants above.
            if known[1] is None and not self._worth_another_look(uuid):
                return None
        else:
            # The first look, or KWin says the icon changed: whatever was
            # missed before is worth looking at now.
            self._misses.pop(uuid, None)

        path = None
        try:
            x11 = self._x11_window_for(uuid, window)
            if x11:
                path = self._extract(x11)
        except Exception as exc:                  # never take the daemon down
            print(f"could not read an icon for window {uuid}: {exc}", file=sys.stderr)

        if known is not None and known[1] and known[1] != path:
            self._remove(known[1])
        self._icons[uuid] = (serial, path)
        if path is None:
            attempts, _ = self._misses.get(uuid, (0, 0.0))
            self._misses[uuid] = (attempts + 1, time.monotonic())
        else:
            self._misses.pop(uuid, None)
        return path

    def _worth_another_look(self, uuid):
        """Whether a lookup that found nothing should be made again yet."""
        attempts, last = self._misses.get(uuid, (0, 0.0))
        if attempts >= len(self.MISS_DELAYS):
            return False
        return time.monotonic() - last >= self.MISS_DELAYS[max(0, attempts - 1)]

    def next_look(self):
        """Seconds until a window still without its icon is worth a look, or None.

        What WindowList sets its clock by: the soonest of every window's next
        try, so a window that is listed a moment late is found without waiting
        for anything else to happen on screen.
        """
        now = time.monotonic()
        waits = [max(0.0, last + self.MISS_DELAYS[max(0, attempts - 1)] - now)
                 for attempts, last in self._misses.values()
                 if attempts < len(self.MISS_DELAYS)]
        return min(waits) if waits else None

    def new_update(self):
        """Forget what windows the display has.

        That was true of the last update. Finding it out is an `xprop` for
        every window on the display, and this runs on the thread that answers
        D-Bus -- so it is done at most once an update, however many windows
        in it are still to be found, rather than once for each of them.
        """
        self._clients = None

    def forget_all_but(self, uuids):
        """Drop what is kept for the windows that have gone, their files too.

        A copy of a window's icon is worth keeping only while the window is
        there to have it; the next window of the same program is another
        window, and is asked for its own.
        """
        for uuid in [u for u in self._icons if u not in uuids]:
            _, path = self._icons.pop(uuid)
            if path:
                self._remove(path)
        for table in (self._x11, self._misses):
            for uuid in [u for u in table if u not in uuids]:
                del table[uuid]

    def _remove(self, path):
        # Only a file this process wrote. The directory is shared with any
        # other copy of the daemon on this login -- the test suite runs one --
        # and a file that copy wrote is not this one's to take away.
        if path not in self._written:
            return
        self._written.discard(path)
        try:
            os.unlink(path)
        except OSError:
            pass

    def _x11_window_for(self, uuid, window):
        found = self._x11.get(uuid)
        if found:
            return found
        if self._clients is None:
            # Set before the sweep, so one that fails is not tried again for
            # every other window in the same update.
            self._clients = []
            self._clients = self._x11_clients()
        found = self.pick_client(window, self._clients, set(self._x11.values()))
        if found:
            self._x11[uuid] = found
        return found

    @staticmethod
    def pick_client(window, clients, taken):
        """Which of the display's windows this one is, or None.

        The same process and the same class -- both halves of it, where KWin
        sent both -- and not a window another one has already been found to
        be. Among several, the one with this window's title: KWin adds " <2>"
        to a title two windows share, so a title that begins with the
        window's own name will do. Nothing rather than a guess: a window of
        the same process with another class is another window, and its icon
        is not this one's.
        """
        pid = window.get("pid")
        klass = str(window.get("appId") or "").lower()
        instance = str(window.get("resourceName") or "").lower()
        title = str(window.get("title") or "")
        mine = [c for c in clients
                if c["pid"] == pid and c["id"] not in taken
                and c["class"].lower() == klass
                and (not instance or c["instance"].lower() == instance)]
        for client in mine:
            if client["name"] and (client["name"] == title or title.startswith(client["name"])):
                return client["id"]
        return mine[0]["id"] if mine else None

    @staticmethod
    def _x11_clients():
        """The display's managed windows: the id, process, class and title of each."""
        out = subprocess.run(["xprop", "-root", "_NET_CLIENT_LIST"],
                             capture_output=True, encoding="utf-8", errors="replace",
                             timeout=5).stdout
        found = []
        for window in re.findall(r"0x[0-9a-fA-F]+", out):
            props = subprocess.run(["xprop", "-id", window, "_NET_WM_PID", "WM_CLASS", "_NET_WM_NAME"],
                                   capture_output=True, encoding="utf-8", errors="replace",
                                   timeout=5).stdout
            found.append(WindowIcons.client(window, props))
        return found

    @staticmethod
    def client(window, props):
        """One window's `xprop` answer, as the fields `pick_client` compares."""
        quoted = r'"((?:[^"\\]|\\.)*)"'
        pid = re.search(r"^_NET_WM_PID\([^)]*\) = (\d+)", props, re.M)
        klass = re.search(r"^WM_CLASS\([^)]*\) = " + quoted + ", " + quoted, props, re.M)
        name = re.search(r"^_NET_WM_NAME\([^)]*\) = " + quoted, props, re.M)

        def text(match, group):
            return re.sub(r"\\(.)", r"\1", match.group(group)) if match else ""

        return {
            "id": window,
            "pid": int(pid.group(1)) if pid else 0,
            "instance": text(klass, 1),
            "class": text(klass, 2),
            "name": text(name, 1),
        }

    def _extract(self, window):
        out = subprocess.run(["xprop", "-id", window, "-notype", "32c", "_NET_WM_ICON"],
                             capture_output=True, encoding="utf-8", errors="replace",
                             timeout=10).stdout
        values = [int(v) for v in re.findall(r"-?\d+", out.split("=", 1)[-1])]
        image = self._largest(values)
        if image is None:
            return None

        width, height, pixels = image
        from PIL import Image

        # _NET_WM_ICON is ARGB packed into 32-bit cardinals. Laid out as
        # native unsigned ints those are the bytes B, G, R, A on a
        # little-endian machine and A, R, G, B on a big-endian one, both raw
        # modes Pillow reads as they are. Reordering them here one pixel at a
        # time was a Python loop over up to 65536 of them, on the thread that
        # answers D-Bus.
        data = array(_U32, (value & 0xFFFFFFFF for value in pixels)).tobytes()
        rawmode = "BGRA" if sys.byteorder == "little" else "ARGB"

        # Named for the window and for the picture. The shell keeps an image
        # it has loaded for as long as its URL stays the same, so a new icon
        # on the same window has to be a new file for it to be drawn at all;
        # the same icon read again is the same file, and is not written twice.
        digest = hashlib.sha1(f"{width}x{height}:".encode() + data).hexdigest()[:12]
        safe = re.sub(r"[^A-Za-z0-9]", "_", window)[:32]
        path = os.path.join(icon_dir(), f"{safe}-{digest}.png")
        if not os.path.exists(path):
            Image.frombytes("RGBA", (width, height), data, "raw", rawmode).save(path)
        self._written.add(path)
        return path

    @staticmethod
    def _largest(values):
        """The biggest icon in the property, up to a size worth drawing.

        The property holds several sizes one after another, each preceded by
        its width and height. A malformed one must yield nothing rather than an
        exception: it arrives from another application.
        """
        best = None
        i = 0
        while i + 2 <= len(values):
            width, height = values[i], values[i + 1]
            if width <= 0 or height <= 0 or width > 1024 or height > 1024:
                break
            start, end = i + 2, i + 2 + width * height
            if end > len(values):
                break
            if width <= 256 and (best is None or width > best[0]):
                best = (width, height, values[start:end])
            i = end
        return best
