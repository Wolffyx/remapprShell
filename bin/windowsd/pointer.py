"""Where the pointer is, passed on to the shell that cannot ask."""

import sys

from . import brand
from .gio import Gio, GLib

# Where the pointer is, which nothing but KWin knows.
#
# Wayland tells a client where the pointer is only while it is over that
# client's own surface, so a shell cannot ask "where is the cursor" at all --
# and a menu that opens where the cursor is needs exactly that. KWin knows
# (workspace.cursorPos), a KWin script can read it, and a script can call DBus
# but can never be called: so `rmpr clipboard` loads a one-shot script that
# reads the position and calls this, and this passes it on as a signal the
# shell is listening for.
#
# The action is named rather than assumed, so the same path serves anything
# else that should open under the pointer later.
POINTER_INTERFACE = brand.DBUS_NAME + ".Pointer"
POINTER_INTROSPECTION = f"""
<node>
  <interface name="{POINTER_INTERFACE}">
    <method name="At">
      <arg type="s" name="action" direction="in"/>
      <arg type="i" name="x" direction="in"/>
      <arg type="i" name="y" direction="in"/>
      <arg type="s" name="output" direction="in"/>
    </method>
    <signal name="Requested">
      <arg type="s" name="action"/>
      <arg type="i" name="x"/>
      <arg type="i" name="y"/>
      <arg type="s" name="output"/>
    </signal>
  </interface>
</node>
"""

POINTER_OBJECT_PATH = "/Pointer"

# What may be opened under the pointer. A list rather than "anything a
# shortcut can run", because these are surfaces the shell places itself: an
# action that does not read a position would silently ignore it.
POINTER_ACTIONS = ("clipboard", "sidebar")


class Pointer:
    """Where the pointer was when something asked to open under it.

    Holds nothing: the position is true for one moment, and a stored one would
    be wrong by the time anybody read it. The call arrives from a one-shot
    KWin script and leaves again as a signal, and the shell decides what to
    draw.
    """

    def handle_call(self, connection, _sender, _path, _interface, method, params, invocation):
        if method != "At":
            invocation.return_error_literal(
                Gio.dbus_error_quark(), Gio.DBusError.UNKNOWN_METHOD, method
            )
            return

        action = params[0] if params else ""
        if action not in POINTER_ACTIONS:
            # Printed rather than raised, as ScreenEdges (edges.py) explains:
            # the caller is a KWin script and an error raised into the
            # compositor's script engine is a warning nobody reads.
            print(f"unknown pointer action: {action!r}", file=sys.stderr)
            invocation.return_value(None)
            return

        connection.emit_signal(
            None, POINTER_OBJECT_PATH, POINTER_INTERFACE, "Requested",
            GLib.Variant("(siis)", (action, int(params[1]), int(params[2]), str(params[3]))),
        )
        invocation.return_value(None)
