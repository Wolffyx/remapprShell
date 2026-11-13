"""A stand-in for the window daemon, on the rig's own bus: python3 -I windowsd-stub.py <bus name> <out>

kwin/windows pushes the window list to the daemon; this takes each list and
writes it to <out> as one line of JSON, so a scenario can read what the
taskbar would have been shown -- and, as the real daemon does, says so in a
Changed signal, so a shell started in the rig follows windows as they move.
"""
import sys

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

NAME, OUT = sys.argv[1], sys.argv[2]
XML = f"""
<node>
  <interface name="{NAME}.Windows">
    <method name="Update"><arg type="s" name="windows" direction="in"/></method>
    <method name="List"><arg type="s" name="windows" direction="out"/></method>
    <signal name="Changed"><arg type="s" name="windows"/></signal>
  </interface>
</node>
"""
last = ["[]"]


def call(connection, sender, path, interface, method, params, invocation):
    if method == "Update":
        last[0] = params.unpack()[0]
        with open(OUT, "a", encoding="utf-8") as f:
            f.write(last[0] + "\n")
        invocation.return_value(None)
        connection.emit_signal(None, path, interface, "Changed", GLib.Variant("(s)", (last[0],)))
        return
    invocation.return_value(GLib.Variant("(s)", (last[0],)))


def acquired(connection, name):
    node = Gio.DBusNodeInfo.new_for_xml(XML)
    connection.register_object("/Windows", node.interfaces[0], call, None, None)


Gio.bus_own_name(Gio.BusType.SESSION, NAME, Gio.BusNameOwnerFlags.NONE, acquired, None, None)
GLib.MainLoop().run()
