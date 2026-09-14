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

    // One more desktop, at the end. KWin names it itself when the name is
    // empty, the same as adding one in System Settings does.
    function create() {
        createCall.command = Dbus.callArgs(root.service, root.path, root.iface, "createDesktop", "us",
                                           [String(root.count), ""]);
        createCall.running = true;
    }

    readonly property Process _create: Process { id: createCall }

    // Takes one away. KWin moves whatever was on it to the desktop before, and
    // refuses to remove the last one -- a window has to be somewhere.
    function remove(id) {
        if (!id || root.count <= 1)
            return;
        removeCall.command = Dbus.callArgs(root.service, root.path, root.iface, "removeDesktop", "s", [id]);
        removeCall.running = true;
    }

    readonly property Process _remove: Process { id: removeCall }

    // Whether KWin is showing the desktop. Read back from KWin rather than
    // remembered from our own clicks, so Meta+D, a hot corner and a window
    // being activated all count -- a strip that kept its own flag got out of
    // step with the first of them and then did the opposite of what it said.
    property bool showingDesktop: false

    function showDesktop(show) {
        showDesktopCall.running = false;
        showDesktopCall.command = Dbus.callArgs(root.service, "/KWin", "org.kde.KWin", "showDesktop", "b",
                                                [show ? "true" : "false"]);
        showDesktopCall.running = true;
    }

    readonly property Process _showDesktopCall: Process { id: showDesktopCall }

    readonly property DbusProperty _showing: DbusProperty {
        service: root.service
        path: "/KWin"
        iface: "org.kde.KWin"
        name: "showingDesktop"
        onLoaded: value => root.showingDesktop = value === true
    }

    // showingDesktopChanged, and the PropertiesChanged carrying the same.
    readonly property DbusWatch _kwinWatch: DbusWatch {
        service: root.service
        path: "/KWin"
        filter: "showingDesktop"
        onChanged: root._showing.refresh()
    }

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
