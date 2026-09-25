"""A screen edge, run as one of the shell's actions."""

import sys

from . import brand
from .gio import Gio
from .shortcuts import SHORTCUT_ACTIONS

# Triggered: what the screen-edge KWin script calls when the pointer reaches an
# edge it claimed. A KWin script can call DBus and never be called, so the edge
# arrives here and is run here.
EDGE_INTROSPECTION = f"""
<node>
  <interface name="{brand.DBUS_NAME}.Edges">
    <method name="Triggered">
      <arg type="s" name="action" direction="in"/>
    </method>
  </interface>
</node>
"""

EDGE_OBJECT_PATH = "/Edges"


class ScreenEdges:
    """An edge of the screen, run as one of this shell's actions.

    The action names are the shortcuts' own: an edge can do anything a key can,
    and there is no second list to keep in step. The KWin script names the
    action rather than the edge, so which edge means what is settled where it
    is configured -- `rmpr edges shell` -- and nothing here has to know
    about borders at all.

    Detached, like a key press, and for the same reason: `registerScreenEdge`
    runs its callback inside kwin_wayland, so anything that waited for a shell
    window to appear would hold the compositor while it did.
    """

    def __init__(self, shortcuts):
        self._shortcuts = shortcuts

    def handle_call(self, _connection, _sender, _path, _interface, method, params, invocation):
        if method != "Triggered":
            invocation.return_error_literal(
                Gio.dbus_error_quark(), Gio.DBusError.UNKNOWN_METHOD, method
            )
            return

        action = params[0] if params else ""
        entry = SHORTCUT_ACTIONS.get(action)
        if entry is None:
            # Answered rather than raised: the caller is a KWin script, and an
            # error raised into the compositor's script engine is a warning
            # nobody reads. The name is printed here instead, where the
            # journal has it.
            print(f"unknown edge action: {action!r}", file=sys.stderr)
        else:
            self._shortcuts._run(action, entry[1])
        invocation.return_value(None)
