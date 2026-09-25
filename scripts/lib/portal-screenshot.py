#!/usr/bin/env python3
"""Ask the desktop portal for a screenshot, and print the file it made.

    portal-screenshot.py [--interactive] [--timeout SECONDS]
    portal-screenshot.py --check

The capture itself is the portal's: `org.freedesktop.portal.Screenshot` on
the session bus, answered by whichever backend this desktop installs. Nothing
here names a program, draws a selector or writes a picture. With
--interactive the portal shows its own chooser and the person decides what is
captured; without it the portal takes the whole desktop at once.

Why Python and not one `gdbus call`. A portal request belongs to the D-Bus
connection that made it: the answer is a `Response` signal sent to that
connection some time after the call returns, and a one-shot `gdbus call` has
disconnected by then -- the portal drops a request whose caller has gone, and
the answer is never seen. So one connection subscribes, calls and waits. It
subscribes *before* calling, on the path the request will have, because a
portal that answers at once (a capture with no chooser) can send the signal
before the call's own reply has been read.

Prints the local path of the file the portal wrote, and exits:

    0  saved; the path is on stdout
    1  cancelled -- the person closed the portal's chooser
    2  the portal answered but made no file: it failed, refused, or gave
       something that is not a local file
    3  no portal: no session bus, or nothing on it answers Screenshot
    4  no answer within the timeout; the request is closed on the way out
   64  a command line this does not understand

--check asks only whether a portal answers, prints the interface's version,
and exits 0 or 3. It captures nothing.
"""

import os
import sys

EXIT_OK, EXIT_CANCELLED, EXIT_FAILED, EXIT_NO_PORTAL, EXIT_TIMEOUT = 0, 1, 2, 3, 4
EXIT_USAGE = 64

PORTAL_NAME = "org.freedesktop.portal.Desktop"
PORTAL_PATH = "/org/freedesktop/portal/desktop"
SCREENSHOT = "org.freedesktop.portal.Screenshot"
REQUEST = "org.freedesktop.portal.Request"

# What a bus says when there is nobody to ask: no such name and nothing that
# could be started for it, or a portal without this interface.
NOT_THERE = (
    "org.freedesktop.DBus.Error.ServiceUnknown",
    "org.freedesktop.DBus.Error.NameHasNoOwner",
    "org.freedesktop.DBus.Error.UnknownInterface",
    "org.freedesktop.DBus.Error.UnknownMethod",
    "org.freedesktop.DBus.Error.UnknownObject",
    "org.freedesktop.DBus.Error.UnknownProperty",
)


def fail(code, message):
    print(f"portal-screenshot: {message}", file=sys.stderr)
    sys.exit(code)


def parse(argv):
    """(interactive, timeout, check) from the command line."""
    interactive, timeout, check = False, 60.0, False
    args = list(argv)
    while args:
        arg = args.pop(0)
        if arg == "--interactive":
            interactive = True
        elif arg == "--check":
            check = True
        elif arg == "--timeout" and args:
            try:
                timeout = float(args.pop(0))
            except ValueError:
                timeout = 0
            if timeout <= 0:
                fail(EXIT_USAGE, "--timeout takes a number of seconds")
        else:
            fail(EXIT_USAGE, f"unknown argument: {arg}")
    return interactive, timeout, check


def main(argv):
    interactive, timeout, check = parse(argv)

    try:
        import gi
        gi.require_version("Gio", "2.0")
        from gi.repository import Gio, GLib
    except (ImportError, ValueError):
        fail(EXIT_NO_PORTAL, "python-gobject is not installed, so no portal can be asked")

    def missing(error):
        """Whether an error from the bus means there is no portal to ask."""
        return (Gio.DBusError.get_remote_error(error) or "") in NOT_THERE

    try:
        bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    except GLib.Error as exc:
        fail(EXIT_NO_PORTAL, f"no session bus: {exc.message}")

    if check:
        try:
            reply = bus.call_sync(PORTAL_NAME, PORTAL_PATH, "org.freedesktop.DBus.Properties",
                                  "Get", GLib.Variant("(ss)", (SCREENSHOT, "version")),
                                  GLib.VariantType("(v)"), Gio.DBusCallFlags.NONE, 10000, None)
        except GLib.Error as exc:
            fail(EXIT_NO_PORTAL, f"no desktop portal answers Screenshot: {exc.message}")
        print(reply.unpack()[0])
        return EXIT_OK

    # The request's path is known before the call: the caller's unique name
    # without its colon and with its dots made underscores, then a token of
    # our choosing. A portal older than that rule returns another path, which
    # is followed below.
    token = f"screenshot_{os.getpid()}_{os.urandom(4).hex()}"
    sender = bus.get_unique_name().lstrip(":").replace(".", "_")
    expected = f"{PORTAL_PATH}/request/{sender}/{token}"

    loop = GLib.MainLoop()
    answer = {}

    def on_response(_conn, _sender, _path, _iface, _signal, params, _data):
        answer["code"], answer["results"] = params.unpack()
        loop.quit()

    def subscribe(path):
        return bus.signal_subscribe(PORTAL_NAME, REQUEST, "Response", path, None,
                                    Gio.DBusSignalFlags.NONE, on_response, None)

    def timed_out():
        loop.quit()
        return False

    subscription = subscribe(expected)
    options = {
        "handle_token": GLib.Variant("s", token),
        "interactive": GLib.Variant("b", interactive),
    }
    try:
        reply = bus.call_sync(PORTAL_NAME, PORTAL_PATH, SCREENSHOT, "Screenshot",
                              GLib.Variant("(sa{sv})", ("", options)),
                              GLib.VariantType("(o)"), Gio.DBusCallFlags.NONE,
                              int(timeout * 1000), None)
    except GLib.Error as exc:
        if missing(exc):
            fail(EXIT_NO_PORTAL, f"no desktop portal answers Screenshot: {exc.message}")
        fail(EXIT_FAILED, f"the portal refused the request: {exc.message}")

    handle = reply.unpack()[0]
    if handle != expected:
        bus.signal_unsubscribe(subscription)
        subscription = subscribe(handle)

    # The signal may already be queued behind the reply; the loop delivers it.
    timer = GLib.timeout_add(int(timeout * 1000), timed_out)
    loop.run()
    if "code" in answer:
        GLib.source_remove(timer)
    bus.signal_unsubscribe(subscription)

    if "code" not in answer:
        # Closed, so the portal's chooser leaves the screen rather than
        # staying up for a caller that has stopped waiting.
        try:
            bus.call_sync(PORTAL_NAME, handle, REQUEST, "Close", None, None,
                          Gio.DBusCallFlags.NONE, 2000, None)
        except GLib.Error:
            pass
        fail(EXIT_TIMEOUT, f"no answer from the portal in {timeout:g}s")

    code, results = answer["code"], answer["results"]
    if code == 1:
        fail(EXIT_CANCELLED, "cancelled")
    if code != 0:
        fail(EXIT_FAILED, f"the portal could not take the screenshot (response {code})")

    uri = str(results.get("uri", ""))
    path = Gio.File.new_for_uri(uri).get_path() if uri.startswith("file://") else None
    if not path:
        fail(EXIT_FAILED, f"the portal answered with no local file: {uri or 'nothing'}")
    print(path)
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
