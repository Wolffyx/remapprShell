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
import qs.platform.kde
import qs.platform.system
import qs.domain.windows.events

QtObject {
    id: root

    property var windows: []

    readonly property bool available: root.windows.length > 0 || root._answered

    // Told apart from "no windows": before the daemon has answered at all we
    // do not know whether the list is empty or absent.
    property bool _answered: false

    // uuid -> when that window began asking for attention. See
    // WindowEvents.attentionSince.
    property var attentionSince: ({})

    // Output name -> uuid of the window last active on it. See
    // WindowEvents.lastActiveByOutput.
    property var lastActiveByOutput: ({})

    // The window a panel on `screenName` should name: the active one when it
    // is on that screen, otherwise the one last active there -- which is what
    // makes a widget naming it worth having on a second monitor.
    function windowFor(screenName) {
        const uuid = root.lastActiveByOutput[screenName];
        return uuid ? (root.windows.find(w => w.uuid === uuid) ?? null) : null;
    }

    function _apply(list) {
        if (list === null)
            return;   // unreadable: keep what we had rather than blanking
        root._answered = true;
        root.attentionSince = WindowEvents.attentionSince(root.attentionSince, list, Date.now());
        root.lastActiveByOutput = WindowEvents.lastActiveByOutput(root.lastActiveByOutput, list);
        root.windows = list;
    }

    // Asked once at startup. The daemon may have been holding a list for hours
    // before this shell started, and waiting for the next window change to
    // draw anything would leave the panel empty until the user opened
    // something.
    readonly property Process _initial: Process {
        running: true
        command: Dbus.callArgs(Branding.dbusName, "/Windows", `${Branding.dbusName}.Windows`, "List")
        stdout: StdioCollector {
            onStreamFinished: {
                const reply = Dbus.unwrap(text, "Windows.List");
                if (reply === undefined) {
                    Log.debug("windows", "the window daemon is not answering yet");
                    return;
                }
                root._apply(WindowEvents.parseList(reply?.[0]));
                Log.info("windows", `${root.windows.length} window(s) from the daemon`);
            }
        }
    }

    // And then followed. A match rule rather than a whole-bus monitor: this
    // wants two signals, not every message on the session bus.
    readonly property BusMonitor _monitor: BusMonitor {
        match: `type='signal',interface='${Branding.dbusName}.Windows'`

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

        // A dropped line means the window list on screen is now out of date
        // and nothing will say so, since the daemon sends state rather than
        // changes. Worth a warning, unlike the ordinary case of a line that is
        // simply not ours.
        onDropped: Log.warn("windows", "a window update was too large to read; the list may be stale")

        onListeningChanged: if (!listening) Log.warn("windows", "the window list stopped following changes")
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
        return path.length > 0 ? Paths.fileUrl(path) : "";
    }

    // "Dolphin", not "org.kde.dolphin".
    function appNameFor(window) {
        const entry = root.entryFor(window);
        if (entry && String(entry.name ?? "").length > 0)
            return entry.name;
        return window?.appId ?? "";
    }

    // ---- windows grouped by the application that owns them ---------------
    //
    // What KDE's task manager does, and the one part of its behaviour that
    // needs no privilege at all: grouping is arithmetic over a list we already
    // have. The thumbnails in its tooltips are not -- those come from a
    // Wayland protocol KWin hands only to clients it trusts.
    //
    // Keyed by the matched application where there is one, so two windows of
    // the same program group even when their titles and classes differ, and by
    // the class otherwise.
    readonly property var groups: root.groupsOf(root.windows)

    // Any list of windows grouped the same way -- one monitor's, for a task
    // list that shows only the windows on its own screen.
    function groupsOf(windows) {
        const order = [];
        const byKey = ({});

        for (const window of windows ?? []) {
            const entry = root.entryFor(window);
            const key = entry ? String(entry.id) : `class:${window.appId}`;

            if (!byKey[key]) {
                byKey[key] = {
                    key: key,
                    appName: root.appNameFor(window),
                    windows: [],
                    active: false,
                    // Whether any of its windows is asking for attention,
                    // and since when -- the earliest, so a second request
                    // does not restart the flash.
                    attention: false,
                    attentionSince: 0,
                    // The first window's icon stands for the group: they are
                    // the same application, so it is the same icon.
                    iconName: root.iconFor(window),
                    iconFile: root.iconFileFor(window)
                };
                order.push(key);
            }

            const group = byKey[key];
            group.windows.push(window);
            if (window.active)
                group.active = true;
            const since = root.attentionSince[window.uuid] ?? 0;
            if (since > 0) {
                group.attention = true;
                group.attentionSince = group.attentionSince > 0 ? Math.min(group.attentionSince, since) : since;
            }
        }

        return order.map(key => byKey[key]);
    }

    // Clicking a group with more than one window moves through them rather
    // than always returning to the same one -- which is what makes a grouped
    // button useful instead of merely tidy.
    function activateGroup(group) {
        if (!group || group.windows.length === 0)
            return;
        if (group.windows.length === 1) {
            root.activate(group.windows[0].uuid);
            return;
        }

        const current = group.windows.findIndex(w => w.active);
        const next = group.windows[(current + 1) % group.windows.length];
        root.activate(next.uuid);
    }

    // ---- pinned applications, and acting on windows --------------------

    function entryById(id) {
        const key = String(id ?? "").toLowerCase();
        return key.length > 0 ? (root._index[key] ?? null) : null;
    }

    // A pinned application with no windows: a button that starts it. Null
    // for one that is no longer installed.
    function launcherFor(id) {
        const entry = root.entryById(id);
        if (!entry)
            return null;
        return {
            key: String(entry.id),
            appKey: String(entry.id),
            appName: entry.name || String(entry.id),
            windows: [],
            active: false,
            attention: false,
            attentionSince: 0,
            iconName: entry.icon || "",
            iconFile: ""
        };
    }

    // An application by its desktop-entry id: raised when it already has a
    // window, started when it does not. What clicking a notification means --
    // "take me to the thing that told me" -- and what Plasma does with one.
    //
    // The window is found through the same index the task list matches on, so
    // an entry id ("org.kde.spectacle"), a desktop file name and a window
    // class all reach the same application.
    function open(entryId) {
        const key = String(entryId ?? "").replace(/\.desktop$/, "").toLowerCase();
        if (key.length === 0)
            return;
        const entry = root.entryById(key);
        const mine = root.windows.filter(w => {
            const matched = root.entryFor(w);
            if (matched && entry && String(matched.id).toLowerCase() === String(entry.id).toLowerCase())
                return true;
            return String(w.appId ?? "").toLowerCase().replace(/\.desktop$/, "") === key;
        });
        if (mine.length > 0) {
            root.activateGroup({ windows: mine });
            return;
        }
        Launch.entry(entry);
    }

    // Starts the application -- or one of its own actions, "New Incognito
    // Window" and the like -- the way a launcher would: in a scope of its own,
    // so the shell restarting does not end it (see Launch).
    function launch(id, action) {
        if (action) {
            Launch.action(action, root.entryById(id));
            return;
        }
        Launch.entry(root.entryById(id));
    }

    // The active window, minimised, by KWin's own "Window Minimize" action --
    // what its key does. Only ever asked for when the window clicked is the
    // active one, which is the one that action works on.
    function minimizeActive() {
        Dbus.invokeShortcut("Window Minimize");
    }

    // Any window, closed. KWin has no call for it, so the CLI loads a
    // one-shot script (`windows close`). It is the close button's request,
    // so an application with unsaved work can still ask.
    function close(uuid) {
        if (!/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/.test(String(uuid ?? "")))
            return;
        Quickshell.execDetached([Branding.ctlBin, "windows", "close", uuid]);
    }

    // KWin's own runner. The id it expects is the uuid in braces behind a
    // "0_" prefix, which is what its Match() hands out.
    function activate(uuid) {
        if (!uuid)
            return;
        Dbus.send("org.kde.KWin", "/WindowsRunner", "org.kde.krunner1", "Run", "ss", [`0_{${uuid}}`, ""]);
    }
}
