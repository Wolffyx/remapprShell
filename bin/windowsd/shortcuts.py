"""The shell's global shortcuts, registered by a process that is running.

Why a daemon has to own them at all is at the top of bin/windowsd.py.in.
"""

import os
import subprocess
import sys

from . import brand
from .gio import Gio, GLib
from .keys import keycode

# Only the daemon holding the shell's own bus name claims the shell's keys.
#
# kglobalaccel hands a component's shortcuts to whoever registered them last
# and takes them from the one before, so two copies of this daemon running at
# once do not compete -- the second silently unbinds the first. A copy under
# another bus name is exactly what the test suite runs, against the real
# session bus, and it wiped the user's live shortcuts the first time this
# class existed. The bus name is the one thing only one process can hold, so
# it is what decides.
SHORTCUT_OWNER = brand.DBUS_NAME
NO_SESSION_VAR = brand.ENV_PREFIX + "_NO_SESSION"


def shortcuts_wanted():
    """Whether this copy of the daemon should claim the shell's global keys."""
    if os.environ.get(NO_SESSION_VAR):
        return False
    return brand.BUS_NAME == SHORTCUT_OWNER


SHORTCUT_COMPONENT = brand.SLUG
SHORTCUT_COMPONENT_PATH = "/component/" + brand.SLUG.replace("-", "_").replace(".", "_")
SHORTCUT_INTERFACE = brand.DBUS_NAME + ".Shortcuts"
SHORTCUT_OBJECT_PATH = "/Shortcuts"

# Reload: what `rmpr shortcuts set` calls once it has written the file, so a
# new binding is grabbed now rather than at the next login.
SHORTCUT_INTROSPECTION = f"""
<node>
  <interface name="{SHORTCUT_INTERFACE}">
    <method name="Reload"/>
  </interface>
</node>
"""

CTL = brand.CTL

# Every key this project can bind: action id -> (friendly name, what it runs).
# The friendly name is what System Settings shows in its shortcut list, so it
# is a sentence a person recognises rather than the id. The command is the one
# the action's desktop file used to carry, unchanged.
#
# The list itself is scripts/lib/shortcut-actions.tsv, rendered into brand.py
# at install: the CLI that binds the keys and the edges that run the same
# actions read that file too, and one list is one answer to what exists.
SHORTCUT_ACTIONS = {
    action: (label, [CTL, *args])
    for action, (label, args) in brand.SHORTCUT_ACTIONS.items()
}

# What letting go of a key runs, for the shortcuts that are *held* rather than
# tapped. Only the switcher is: Alt+Tab chooses when Alt comes up.
#
# The switcher used to take that release itself, as a key event on its own
# surface -- which works only while the surface is up and holding the keyboard.
# A quick Alt+Tab releases the key before it is, because the press travels
# kglobalaccel -> here -> the CLI -> the shell's IPC first, so the release
# reached nobody and the switcher stayed on screen with nothing to close it.
# The actions the *shell* takes off the bus itself, and which this must
# therefore not also run.
#
# kglobalaccel announces every press on the session bus, and the shell now
# listens -- shell/domain/shortcuts/ShortcutWatch.qml, which names this set in
# turn. That deletes two spawned processes and about 200 ms per press, and with
# them the class of bug where a press and its release raced each other as
# separate detached commands.
#
# What stays here is what the shell cannot do or should not: `clipboard` and
# `sidebar` open where the pointer is, which on Wayland only a KWin script can
# answer; `ask` builds a redacted report before any window opens; the
# screenshot keys are the only ones worth anything when the shell is not
# running at all.
#
# Registration is unaffected. A shortcut is grabbed only while its component
# has a running owner, and that is still this process -- see the class
# docstring below.
SHELL_ACTIONS = frozenset({
    "launcher", "search", "settings", "keys",
    "switcher", "switcher-reverse", "overview", "overview-reverse",
})

SHORTCUT_RELEASES = {
    "switcher": [CTL, "switcher", "commit"],
    "switcher-reverse": [CTL, "switcher", "commit"],
    "overview": [CTL, "switcher", "commit"],
    "overview-reverse": [CTL, "switcher", "commit"],
}

# kglobalaccel's setShortcutKeys flags word. SetPresent is the bit that makes
# the component active -- without it the record is filed and no key is grabbed,
# which is the bug this whole class exists to fix. NoAutoloading means "use the
# keys I am passing" rather than "read them from the file yourself", which is
# what lets one push apply immediately.
SET_PRESENT = 0x2
NO_AUTOLOADING = 0x4


class GlobalShortcuts:
    """This project's keys, registered by a process that is running.

    The bindings live in kglobalshortcutsrc under this project's own component
    group, in the three-field form kglobalaccel keeps for a component's actions
    ("keys,default,friendly") -- the same place and shape as any other shell's.
    They are read from there and pushed to kglobalaccel with SetPresent, which
    is what grabs the key; pressing it comes back as `globalShortcutPressed` on
    this component, and the command runs.

    Reload exists because `rmpr shortcuts set` writes the file. Without it a
    new binding would wait for the next login -- which is exactly the bug that
    made this class necessary.
    """

    def __init__(self):
        self._bus = None
        self._subscription = None
        self._release_subscription = None

    def start(self, connection):
        self._bus = connection
        # Subscribed before anything is registered: a key pressed between the
        # registration and the subscription would otherwise be lost.
        self._subscription = connection.signal_subscribe(
            "org.kde.kglobalaccel", "org.kde.kglobalaccel.Component",
            "globalShortcutPressed", SHORTCUT_COMPONENT_PATH, None,
            Gio.DBusSignalFlags.NONE, self._on_pressed, None,
        )
        self._release_subscription = connection.signal_subscribe(
            "org.kde.kglobalaccel", "org.kde.kglobalaccel.Component",
            "globalShortcutReleased", SHORTCUT_COMPONENT_PATH, None,
            Gio.DBusSignalFlags.NONE, self._on_released, None,
        )
        self.reload()

    # ---- reading what is bound ---------------------------------------------

    @staticmethod
    def _config_path():
        return os.path.join(
            os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")),
            "kglobalshortcutsrc",
        )

    @classmethod
    def bindings(cls):
        """action id -> list of key strings, from this project's group.

        Parsed rather than read through kreadconfig6: this runs at login, once
        per action, and a subprocess each time is a poor way to spend a login.
        """
        found = {}
        try:
            with open(cls._config_path(), encoding="utf-8") as handle:
                lines = handle.read().splitlines()
        except OSError:
            return found

        in_group = False
        for line in lines:
            stripped = line.strip()
            if stripped.startswith("["):
                in_group = stripped == f"[{SHORTCUT_COMPONENT}]"
                continue
            if not in_group or "=" not in stripped or stripped.startswith("#"):
                continue
            action, value = stripped.split("=", 1)
            action = action.strip()
            if action not in SHORTCUT_ACTIONS:
                continue
            # "keys,default,friendly" -- only the first field is the binding,
            # and a key list inside it is tab-separated.
            active = value.split(",", 1)[0]
            keys = [k.strip() for k in active.replace("\\t", "\t").split("\t")]
            found[action] = [k for k in keys if k and k.lower() != "none"]
        return found

    # ---- registering it ----------------------------------------------------

    def _action_id(self, action):
        return [SHORTCUT_COMPONENT, action, brand.DISPLAY_NAME, SHORTCUT_ACTIONS[action][0]]

    def _call(self, method, params):
        return self._bus.call_sync(
            "org.kde.kglobalaccel", "/kglobalaccel", "org.kde.KGlobalAccel",
            method, params, None, Gio.DBusCallFlags.NONE, 5000, None,
        )

    def reload(self):
        """Push every action's keys to kglobalaccel, as they stand in the file.

        Every action is registered, including the unbound ones: that is what
        puts them in System Settings' shortcut list, where a person expects to
        find them, instead of only in this project's own CLI.
        """
        if self._bus is None:
            return
        bound = self.bindings()
        for action in SHORTCUT_ACTIONS:
            # One entry per alternative binding. The argument is a(ai) -- an
            # array of key *sequences* -- so each key is a one-element list
            # inside a one-member struct, not a bare integer.
            keys = []
            for spec in bound.get(action, []):
                code = keycode(spec)
                if code is None:
                    print(f"cannot bind {action}: no key code for {spec!r}", file=sys.stderr)
                    continue
                keys.append(([code],))
            try:
                # doRegister first: a component kglobalaccel has never seen
                # takes setShortcutKeys and keeps nothing.
                self._call("doRegister", GLib.Variant("(as)", (self._action_id(action),)))
                self._call("setShortcutKeys", GLib.Variant(
                    "(asa(ai)u)",
                    (self._action_id(action), keys, SET_PRESENT | NO_AUTOLOADING),
                ))
            # Broad on purpose: one action that cannot be registered must not
            # take the other seven with it, nor leave the caller of Reload
            # waiting for an answer that is never coming.
            except Exception as exc:
                print(f"could not register {action}: {exc}", file=sys.stderr)

    # ---- running it --------------------------------------------------------

    def _on_pressed(self, _conn, _sender, _path, _iface, _signal, params, _data):
        component, action = params[0], params[1]
        if component != SHORTCUT_COMPONENT or action not in SHORTCUT_ACTIONS:
            return
        # The shell hears this same signal and acts on it. Running the command
        # as well would open every surface twice.
        if action in SHELL_ACTIONS:
            return
        self._run(action, SHORTCUT_ACTIONS[action][1])

    def _on_released(self, _conn, _sender, _path, _iface, _signal, params, _data):
        component, action = params[0], params[1]
        if component != SHORTCUT_COMPONENT or action not in SHORTCUT_RELEASES:
            return
        # As above: the shell takes every held action itself, and a second
        # commit would close a switcher somebody had just reopened.
        if action in SHELL_ACTIONS:
            return
        self._run(action, SHORTCUT_RELEASES[action])

    def _run(self, action, command):
        try:
            # Detached, and never waited for: the shortcut server is inside
            # kwin_wayland, and a key that blocks until a shell window is up
            # would block the compositor with it.
            subprocess.Popen(command, start_new_session=True,
                             stdin=subprocess.DEVNULL,
                             stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL)
        except OSError as exc:
            print(f"could not run {action}: {exc}", file=sys.stderr)

    def sync_configured(self):
        """Make KDE's bindings match the shell's configuration, once, at start.

        The keys are the shell's configuration (`shortcuts.<action>`), and a
        key there is enforced: another program that grabbed it while the shell
        was not looking -- KRunner re-registering Meta+Space at login -- gives
        it back here. The CLI does the work, since it keeps the ledger that
        `shortcuts revert` undoes. Detached, not waited for: it ends by
        calling Reload on this very process, which could not answer while it
        was waiting.
        """
        self._run("sync", [CTL, "shortcuts", "sync", "--quiet"])

    def handle_call(self, _connection, _sender, _path, _interface, method, _params, invocation):
        if method == "Reload":
            self.reload()
            invocation.return_value(None)
        else:
            invocation.return_error_literal(
                Gio.dbus_error_quark(), Gio.DBusError.UNKNOWN_METHOD, method
            )
