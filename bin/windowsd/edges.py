"""A screen edge, run as one of the shell's actions."""

import sys

from . import brand
from .gio import Gio, GLib
from .shortcuts import SHORTCUT_ACTIONS

# Triggered: what the screen-edge KWin script calls when the pointer reaches an
# edge it claimed. A KWin script can call DBus and never be called, so the edge
# arrives here and is run here. TriggeredAt is the same with where the pointer
# was and the screen it was on, which only KWin can know; Triggered is what a
# script rendered before that sends, and is kept for it. Reached: an edge whose
# action is not a command but something the shell does to a surface it already
# has up -- lighting the sidebar's grip where the pointer is, opening the
# sidebar on that screen -- announced for the shell to hear, with no process
# in between. An edge that did not say where is announced at -1, -1, "".
#
# Resting: the sidebar's side of every screen is not a KWin edge (KWin has one
# only on the outside of the layout, and draws a glow down all of it); the
# script says instead when the pointer comes to rest in that side's last
# column and when it leaves, passed on as it is for the shell to time. Only
# the shell's own actions are followed that way.
EDGE_INTERFACE = brand.DBUS_NAME + ".Edges"
EDGE_INTROSPECTION = f"""
<node>
  <interface name="{EDGE_INTERFACE}">
    <method name="Triggered">
      <arg type="s" name="action" direction="in"/>
    </method>
    <method name="TriggeredAt">
      <arg type="s" name="action" direction="in"/>
      <arg type="i" name="x" direction="in"/>
      <arg type="i" name="y" direction="in"/>
      <arg type="s" name="output" direction="in"/>
    </method>
    <method name="Resting">
      <arg type="s" name="action" direction="in"/>
      <arg type="i" name="x" direction="in"/>
      <arg type="i" name="y" direction="in"/>
      <arg type="s" name="output" direction="in"/>
      <arg type="b" name="resting" direction="in"/>
    </method>
    <signal name="Reached">
      <arg type="s" name="action"/>
      <arg type="i" name="x"/>
      <arg type="i" name="y"/>
      <arg type="s" name="output"/>
    </signal>
    <signal name="Resting">
      <arg type="s" name="action"/>
      <arg type="i" name="x"/>
      <arg type="i" name="y"/>
      <arg type="s" name="output"/>
      <arg type="b" name="resting"/>
    </signal>
  </interface>
</node>
"""

EDGE_OBJECT_PATH = "/Edges"

# Where an edge that did not say is announced as being.
NOWHERE = (-1, -1, "")


def _where(method, params):
    """The action and the place, from either method's arguments."""
    action = str(params[0]) if params else ""
    if method == "TriggeredAt" and len(params) >= 4:
        return action, (int(params[1]), int(params[2]), str(params[3]))
    return action, NOWHERE


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

    def handle_call(self, connection, _sender, _path, _interface, method, params, invocation):
        if method == "Resting":
            self._resting(connection, params)
            invocation.return_value(None)
            return
        if method not in ("Triggered", "TriggeredAt"):
            invocation.return_error_literal(
                Gio.dbus_error_quark(), Gio.DBusError.UNKNOWN_METHOD, method
            )
            return

        action, (x, y, output) = _where(method, params)
        entry = SHORTCUT_ACTIONS.get(action)
        if entry is not None:
            self._shortcuts._run(action, entry[1])
        elif action:
            # Not a command: the shell's own (sidebar-reveal, sidebar-open,
            # in shell/domain/sidebar/SidebarReveal.qml), announced rather
            # than run. An action the shell does not know is logged there.
            connection.emit_signal(
                None, EDGE_OBJECT_PATH, EDGE_INTERFACE, "Reached",
                GLib.Variant("(siis)", (action, x, y, output)),
            )
        else:
            # Answered rather than raised: the caller is a KWin script, and an
            # error raised into the compositor's script engine is a warning
            # nobody reads. Printed here instead, where the journal has it.
            print("an edge with no action", file=sys.stderr)
        invocation.return_value(None)

    def _resting(self, connection, params):
        action = str(params[0]) if params else ""
        if len(params) < 5 or not action or action in SHORTCUT_ACTIONS:
            # A key's action is run on a push, never on a rest; and a call
            # that does not say where is nothing the shell could place.
            print(f"a resting pointer for {action!r} was not passed on", file=sys.stderr)
            return
        connection.emit_signal(
            None, EDGE_OBJECT_PATH, EDGE_INTERFACE, "Resting",
            GLib.Variant("(siisb)", (action, int(params[1]), int(params[2]), str(params[3]), bool(params[4]))),
        )
