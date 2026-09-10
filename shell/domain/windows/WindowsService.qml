pragma Singleton

// The open windows, as KWin sees them.
//
// The route is long and worth stating once: KWin knows what windows exist; a
// KWin script is the only supported way to read that without a C++ effect; a
// script can call DBus but cannot be called, so it pushes to a small daemon;
// the daemon holds the list and emits a signal; this listens to that signal.
//
// Activation goes back the other way entirely, straight to KWin's own
// /WindowsRunner. That is a supported interface and needs nothing of ours in
// the middle, which is what keeps the daemon one-directional.
//
// All of it is opt-in: `rmpr windows enable` installs and loads the script.
// Until then the list is empty, and the panel simply has nothing to draw.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.domain.windows.events

QtObject {
    id: root

    property var windows: []

    readonly property bool available: root.windows.length > 0 || root._answered

    // Told apart from "no windows": before the daemon has answered at all we
    // do not know whether the list is empty or absent.
    property bool _answered: false

    readonly property var activeWindow: root.windows.find(w => w.active) ?? null

    function _apply(list) {
        if (list === null)
            return;   // unreadable: keep what we had rather than blanking
        root._answered = true;
        root.windows = list;
    }

    // Asked once at startup. The daemon may have been holding a list for hours
    // before this shell started, and waiting for the next window change to
    // draw anything would leave the panel empty until the user opened
    // something.
    readonly property Process _initial: Process {
        running: true
        command: ["busctl", "--user", "--json=short", "call",
                  Branding.dbusName, "/Windows", `${Branding.dbusName}.Windows`, "List"]
        stdout: StdioCollector {
            onStreamFinished: {
                let payload;
                try {
                    payload = JSON.parse(text).data?.[0];
                } catch (e) {
                    Log.debug("windows", "the window daemon is not answering yet");
                    return;
                }
                root._apply(WindowEvents.parseList(payload));
                Log.info("windows", `${root.windows.length} window(s) from the daemon`);
            }
        }
    }

    // And then followed. A match rule rather than a whole-bus monitor: this
    // wants two signals, not every message on the session bus.
    readonly property Process _monitor: Process {
        running: true
        command: ["busctl", "--user", "--json=short", "monitor",
                  "--match", `type='signal',interface='${Branding.dbusName}.Windows'`]
        stdout: SplitParser {
            onRead: line => {
                const list = WindowEvents.parseSignal(line);
                if (list === null)
                    return;
                // A window opening or closing is worth a journal line; a title
                // changing is not, and there are a great many of those.
                const changed = list.length !== root.windows.length;
                root._apply(list);
                if (changed)
                    Log.info("windows", `${list.length} window(s)`);
                else
                    Log.debug("windows", `${list.length} window(s), details changed`);
            }
        }

        onRunningChanged: if (!running) Log.warn("windows", "the window list stopped following changes")
    }

    // ---- matching a window to the application that owns it ---------------
    //
    // KWin gives us two hints and neither is reliably an icon name: the
    // desktop file it associated with the window (often empty), and the X11
    // resource class (often the wrong case, sometimes a binary name). Guessing
    // an icon from those is what produces a panel of identical grey
    // placeholders.
    //
    // So the hints are resolved against the desktop entries the system
    // actually has, by the three keys a launcher would use, and only then
    // falls back to guessing.
    readonly property var _entries: DesktopEntries.applications.values

    // Built once per change of the installed applications rather than per
    // window per repaint.
    readonly property var _index: {
        const byKey = ({});
        for (const entry of root._entries ?? []) {
            const add = (key, value) => {
                const k = String(key ?? "").toLowerCase();
                if (k.length > 0 && !byKey[k])
                    byKey[k] = value;
            };
            add(entry.id, entry);
            // The .desktop id without its suffix, which is the form KWin
            // usually reports.
            add(String(entry.id ?? "").replace(/\.desktop$/, ""), entry);
            // What the application tells the compositor to call itself. This
            // is the one that matches windows whose class bears no relation to
            // their desktop file.
            add(entry.startupClass, entry);
        }
        return byKey;
    }

    function entryFor(window) {
        if (!window)
            return null;
        const index = root._index;
        for (const hint of [window.desktopFile, window.appId]) {
            const key = String(hint ?? "").toLowerCase();
            if (key.length === 0)
                continue;
            if (index[key])
                return index[key];
            const stripped = key.replace(/\.desktop$/, "");
            if (index[stripped])
                return index[stripped];
        }
        return null;
    }

    // The icon to draw, as a theme name. The entry's own icon first, because
    // that is the one the application chose.
    function iconFor(window) {
        const entry = root.entryFor(window);
        if (entry && String(entry.icon ?? "").length > 0)
            return entry.icon;
        return WindowEvents.iconName(window);
    }

    // Some windows match no installed application at all -- a Steam game's
    // class is a numeric app id -- and the only copy of their icon is the one
    // the window carries. The daemon writes that out; this is the file.
    function iconFileFor(window) {
        const path = String(window?.iconPath ?? "");
        return path.length > 0 ? `file://${path}` : "";
    }

    // "Dolphin", not "org.kde.dolphin".
    function appNameFor(window) {
        const entry = root.entryFor(window);
        if (entry && String(entry.name ?? "").length > 0)
            return entry.name;
        return window?.appId ?? "";
    }

    // KWin's own runner. The id it expects is the uuid in braces behind a
    // "0_" prefix, which is what its Match() hands out.
    readonly property Process _activate: Process {}

    function activate(uuid) {
        if (!uuid)
            return;
        root._activate.running = false;
        root._activate.command = ["busctl", "--user", "call", "org.kde.KWin", "/WindowsRunner",
                                  "org.kde.krunner1", "Run", "ss", `0_{${uuid}}`, ""];
        root._activate.running = true;
    }
}
