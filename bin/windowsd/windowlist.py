"""The window list: what the KWin script pushes in, and what the shell reads."""

import json
import sys

from . import brand
from .desktop_files import app_id_file
from .gio import Gio, GLib
from .icons import WindowIcons
from .processes import Processes

OBJECT_PATH = "/Windows"
INTERFACE = brand.DBUS_NAME + ".Windows"

# Update: what the KWin script pushes in. List: what a shell that started later
# asks for, so it does not have to wait for the next window change to draw
# anything. Changed: what the shell listens to.
INTROSPECTION = f"""
<node>
  <interface name="{INTERFACE}">
    <method name="Update">
      <arg type="s" name="windows" direction="in"/>
    </method>
    <method name="List">
      <arg type="s" name="windows" direction="out"/>
    </method>
    <signal name="Changed">
      <arg type="s" name="windows"/>
    </signal>
  </interface>
</node>
"""


class WindowList:
    """The current windows, as the KWin script last reported them."""

    def __init__(self):
        self._json = "[]"
        self._connection = None
        self._icons = WindowIcons()
        self._processes = Processes()
        self._windows = []        # the last update, as it was sent on
        self._relook_id = 0       # the clock for icons still being looked for

    def update(self, payload):
        # Validated rather than trusted: this crosses a process boundary, and a
        # malformed payload must leave the last good list in place rather than
        # blanking a panel. The shell parses it again at its end for the same
        # reason.
        try:
            windows = json.loads(payload)
        except (ValueError, TypeError) as exc:
            print(f"ignoring an unparseable update: {exc}", file=sys.stderr)
            return False

        if not isinstance(windows, list):
            print("ignoring an update that is not a list", file=sys.stderr)
            return False

        # The icon every X11 window carries itself, whether or not it has an
        # application to match: which of the two to draw is the shell's
        # decision, made the way Plasma makes it -- and an application whose
        # entry names no icon the theme has is drawn with the window's own.
        self._icons.new_update()
        present, pids = set(), set()
        for window in windows:
            if not isinstance(window, dict):
                continue
            present.add(str(window.get("uuid") or ""))

            # What Plasma reads about the process and the files a window
            # names, for the shell to match it by when the window itself
            # matches no installed application.
            pid = window.get("pid")
            if isinstance(pid, int) and pid > 0:
                pids.add(pid)
                window.update(self._processes.facts_for(pid))
            named = app_id_file(window)
            if named:
                window["appIdFile"] = named

            path = self._icons.path_for(window)
            if path:
                window["iconPath"] = path
        self._icons.forget_all_but(present)
        self._processes.forget_all_but(pids)
        self._windows = [w for w in windows if isinstance(w, dict)]
        self._schedule_relook()

        # Re-serialised from the parsed value, so whatever reaches the shell is
        # known to be valid JSON of the shape it expects.
        normalised = json.dumps(windows, separators=(",", ":"))
        if normalised == self._json:
            return False   # KWin repeats itself; a signal per repeat is noise

        self._json = normalised
        self._emit()
        return True

    # A window whose icon was not there to read -- listed by the display a
    # moment after KWin announced it, or its icon set a moment after it
    # appeared -- is looked at again on a clock of its own (MISS_DELAYS), and
    # the list goes out again as soon as the icon is found. Waiting for KWin's
    # next event instead left a game on the wrong icon for as long as nothing
    # else happened on screen.
    def _schedule_relook(self):
        if self._relook_id:
            GLib.source_remove(self._relook_id)
            self._relook_id = 0
        wait = self._icons.next_look()
        if wait is not None:
            self._relook_id = GLib.timeout_add(max(1, int(wait * 1000)), self._relook)

    def _relook(self):
        self._relook_id = 0
        self._icons.new_update()
        for window in self._windows:
            if window.get("iconPath"):
                continue
            path = self._icons.path_for(window)
            if path:
                window["iconPath"] = path
        normalised = json.dumps(self._windows, separators=(",", ":"))
        if normalised != self._json:
            self._json = normalised
            self._emit()
        self._schedule_relook()
        return False    # this timeout is spent; _schedule_relook set the next

    def _emit(self):
        if self._connection is None:
            return
        self._connection.emit_signal(
            None, OBJECT_PATH, INTERFACE, "Changed", GLib.Variant("(s)", (self._json,))
        )

    def handle_call(self, _connection, _sender, _path, _interface, method, params, invocation):
        if method == "Update":
            self.update(params[0])
            invocation.return_value(None)
        elif method == "List":
            invocation.return_value(GLib.Variant("(s)", (self._json,)))
        else:
            invocation.return_error_literal(
                Gio.dbus_error_quark(), Gio.DBusError.UNKNOWN_METHOD, method
            )
