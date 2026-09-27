pragma Singleton

// Activating a tray icon at the place it was clicked.
//
// The StatusNotifierItem spec's Activate and SecondaryActivate carry a
// position, and some applications open their window there: JetBrains Toolbox
// puts itself beside the icon. Quickshell's `activate()` takes no position
// and sends 0,0, so Toolbox opened in the top corner of the screen, far from
// the tray at the bottom -- which looked like KWin placing it badly.
// (Measured 2026-09-25: Activate(2400, 2430) put it at the bottom right, just
// above the tray.)
//
// Quickshell's item does not say where on the bus it lives, only its `Id`,
// so the watcher's list is read here and each item's Id matched to its
// address. A click on an item not in the list yet -- the first click after
// the shell starts, since a singleton is only made when first used, or an
// application that has just registered -- waits for the list to be read
// again, and only an item still not in it is activated Quickshell's way: at
// the wrong place is better than not at all.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import qs.core
import qs.platform.kde

QtObject {
    id: root

    // Id -> { service, path, iface }.
    property var addresses: ({})

    function activate(item, x, y) {
        root._call(item, "Activate", x, y, () => item.activate());
    }

    function secondaryActivate(item, x, y) {
        root._call(item, "SecondaryActivate", x, y, () => item.secondaryActivate());
    }

    function _call(item, method, x, y, fallback) {
        if (!item)
            return;
        if (root._send(root.addresses[item.id], method, x, y))
            return;
        root._waiting = root._waiting.concat([{ id: item.id, method: method, x: x, y: y, fallback: fallback }]);
        root._refresh();
    }

    function _send(a, method, x, y) {
        if (!a)
            return false;
        // busctl would read a negative number as an option. A screen left of
        // or above the origin is rare, and its edge is near enough.
        Dbus.send(a.service, a.path, a.iface, method, "ii",
                  [Math.max(0, Math.round(x)), Math.max(0, Math.round(y))]);
        return true;
    }

    // Clicks that arrived before their item's address was known, answered
    // when the list has been read.
    property var _waiting: []

    function _answerWaiting() {
        const waiting = root._waiting;
        root._waiting = [];
        for (const w of waiting) {
            if (!root._send(root.addresses[w.id], w.method, w.x, w.y))
                w.fallback();
        }
    }

    // Read again whenever an item comes or goes: an application restarted
    // registers again under a new name.
    readonly property int _count: SystemTray.items.values.length
    on_CountChanged: root._refresh()
    Component.onCompleted: root._refresh()

    // Never restarted while it runs: a run cut short would hand over half a
    // list, and a click waiting on it would be answered at 0,0. A read asked
    // for meanwhile follows it instead.
    property bool _again: false

    function _refresh() {
        if (lookup.running)
            root._again = true;
        else
            lookup.running = true;
    }

    // One line per item: service, path, interface and its Id as busctl's
    // JSON, tab-separated. The watcher lists "service/path", or a bare
    // service for an item at the spec's default path. Items name either
    // interface, KDE's or freedesktop's.
    readonly property Process _lookup: Process {
        id: lookup
        onRunningChanged: {
            if (!running && root._again) {
                root._again = false;
                running = true;
            }
        }
        command: ["sh", "-c", `
            for a in $(busctl --user get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher \\
                           org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems 2>/dev/null \\
                       | cut -d' ' -f3- | tr -d '"'); do
                case $a in
                    */*) s=\${a%%/*}; p=/\${a#*/} ;;
                    *) s=$a; p=/StatusNotifierItem ;;
                esac
                for i in org.kde.StatusNotifierItem org.freedesktop.StatusNotifierItem; do
                    if id=$(busctl --user --json=short get-property "$s" "$p" "$i" Id 2>/dev/null); then
                        printf '%s\\t%s\\t%s\\t%s\\n' "$s" "$p" "$i" "$id"
                        break
                    fi
                done
            done`]
        stdout: StdioCollector {
            onStreamFinished: {
                const next = ({});
                for (const line of text.split("\n")) {
                    const f = line.split("\t");
                    if (f.length !== 4)
                        continue;
                    const id = Dbus.unwrap(f[3], "StatusNotifierItem.Id");
                    // The first of two with one Id keeps it: two copies of
                    // one application are the rare case, and either is right
                    // for a window that opens beside the tray.
                    if (typeof id === "string" && id.length > 0 && !next[id])
                        next[id] = { service: f[0], path: f[1], iface: f[2] };
                }
                root.addresses = next;
                root._answerWaiting();
            }
        }
    }
}
