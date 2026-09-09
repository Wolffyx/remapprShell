pragma Singleton

// KWin's virtual desktops.
//
// KWin owns them; this reads and drives them over DBus rather than keeping a
// parallel model that could disagree with the compositor.
//
// Note the deliberate limit: KWin exposes desktops globally, not per output.
// Per-monitor workspaces would need a KWin script feeding state out, which is
// a different piece of work -- so nothing here pretends to offer them.

import QtQuick
import Quickshell.Io
import qs.platform.kde

QtObject {
    id: root

    readonly property string service: "org.kde.KWin"
    readonly property string path: "/VirtualDesktopManager"
    readonly property string iface: "org.kde.KWin.VirtualDesktopManager"

    // [{ position, id, name }] in KWin's order.
    property var desktops: []
    property string currentId: ""

    readonly property int count: root.desktops.length
    readonly property int currentIndex: root.desktops.findIndex(d => d.id === root.currentId)

    function switchTo(id) {
        if (!id || id === root.currentId)
            return;
        setCurrent.command = ["busctl", "--user", "set-property", root.service, root.path, root.iface,
                              "current", "s", id];
        setCurrent.running = true;
    }

    // Wraps around, matching KWin's own default for desktop navigation.
    function switchBy(step) {
        if (root.count === 0)
            return;
        const from = root.currentIndex < 0 ? 0 : root.currentIndex;
        const next = ((from + step) % root.count + root.count) % root.count;
        root.switchTo(root.desktops[next].id);
    }

    readonly property Process _setCurrent: Process { id: setCurrent }

    readonly property DbusProperty _desktops: DbusProperty {
        service: root.service
        path: root.path
        iface: root.iface
        name: "desktops"

        // busctl renders a(uss) as [[position, id, name], ...].
        onLoaded: value => {
            root.desktops = (value ?? []).map(row => ({
                position: row[0],
                id: row[1],
                name: row[2]
            }));
        }
    }

    readonly property DbusProperty _current: DbusProperty {
        service: root.service
        path: root.path
        iface: root.iface
        name: "current"
        onLoaded: value => root.currentId = value ?? ""
    }

    // KWin emits currentChanged/desktopCreated/desktopRemoved. Rather than
    // decoding each payload, any signal on the object triggers a re-read: it is
    // cheap, and it cannot drift out of sync with the compositor.
    readonly property DbusWatch _watch: DbusWatch {
        service: root.service
        path: root.path
        onChanged: {
            root._current.refresh();
            root._desktops.refresh();
        }
    }
}
