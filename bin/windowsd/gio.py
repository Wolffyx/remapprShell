"""Gio and GLib, at the version the daemon is written against.

Named once, here, rather than in every module that talks to the bus:
PyGObject warns about a namespace imported before its version was named, and
a module loaded on its own -- as the test suites load them -- would otherwise
be the one to import it first.
"""

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402,F401
