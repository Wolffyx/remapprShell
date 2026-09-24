"""The daemon's objects on the session bus, and the loop they answer from."""

import signal
import sys

from . import brand
from .edges import EDGE_INTROSPECTION, EDGE_OBJECT_PATH, ScreenEdges
from .gio import Gio, GLib
from .pointer import POINTER_INTROSPECTION, POINTER_OBJECT_PATH, Pointer
from .shortcuts import (SHORTCUT_INTROSPECTION, SHORTCUT_OBJECT_PATH, GlobalShortcuts,
                        shortcuts_wanted)
from .windowlist import INTROSPECTION, OBJECT_PATH, WindowList


def main():
    windows = WindowList()
    shortcuts = GlobalShortcuts()
    edges = ScreenEdges(shortcuts)
    pointer = Pointer()
    node = Gio.DBusNodeInfo.new_for_xml(INTROSPECTION)
    shortcut_node = Gio.DBusNodeInfo.new_for_xml(SHORTCUT_INTROSPECTION)
    edge_node = Gio.DBusNodeInfo.new_for_xml(EDGE_INTROSPECTION)
    pointer_node = Gio.DBusNodeInfo.new_for_xml(POINTER_INTROSPECTION)
    loop = GLib.MainLoop()

    def on_bus_acquired(connection, name):
        windows._connection = connection
        connection.register_object(
            OBJECT_PATH, node.interfaces[0], windows.handle_call, None, None
        )
        connection.register_object(
            SHORTCUT_OBJECT_PATH, shortcut_node.interfaces[0],
            shortcuts.handle_call, None, None
        )
        connection.register_object(
            EDGE_OBJECT_PATH, edge_node.interfaces[0],
            edges.handle_call, None, None
        )
        connection.register_object(
            POINTER_OBJECT_PATH, pointer_node.interfaces[0],
            pointer.handle_call, None, None
        )
        # Left unstarted where this is not the owning copy: Reload then does
        # nothing, which is the whole point -- see SHORTCUT_OWNER in shortcuts.py.
        if shortcuts_wanted():
            shortcuts.start(connection)
            shortcuts.sync_configured()
        else:
            print("not the shell's own bus name; leaving the global shortcuts alone",
                  file=sys.stderr)

    def on_name_lost(connection, name):
        # Another copy is already running, or the bus went away. Either way this
        # one has nothing to do, and two daemons answering the same name would
        # give the shell two different window lists.
        print(f"lost the name {name}; exiting", file=sys.stderr)
        loop.quit()

    Gio.bus_own_name(
        Gio.BusType.SESSION,
        brand.BUS_NAME,
        Gio.BusNameOwnerFlags.NONE,
        on_bus_acquired,
        None,
        on_name_lost,
    )

    # Without this, Ctrl+C leaves the main loop running and systemd has to
    # resort to SIGKILL on every stop.
    for sig in (signal.SIGINT, signal.SIGTERM):
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, sig, lambda: (loop.quit(), True)[1])

    loop.run()
