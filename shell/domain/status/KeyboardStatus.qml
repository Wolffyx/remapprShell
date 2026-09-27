pragma Singleton

// KWin's keyboard layouts.
//
// KWin does the switching -- the shortcut, the layout remembered per window
// -- and keeps doing it whatever draws the panel. Plasma's layout indicator
// lives in its system tray, so under our renderer the layout was switched
// with nothing on screen to say which one was on. This says it, and switches
// on request through KWin's own methods.

import QtQuick
import Quickshell.Io
import qs.domain.status.icons
import qs.platform.kde

QtObject {
    id: root

    readonly property string service: "org.kde.keyboard"
    readonly property string path: "/Layouts"
    readonly property string iface: "org.kde.KeyboardLayouts"

    // [{ short, display, long }], in KWin's order.
    property var layouts: []
    property int current: -1

    // One layout is nothing to switch between, and nothing to show.
    readonly property bool present: root.layouts.length > 1

    readonly property var layout: root.layouts[root.current] ?? null
    readonly property string label: StatusIcons.layoutLabel(root.layout)

    function next() {
        root._call("switchToNextLayout", "", []);
    }

    function cycle(steps) {
        const index = StatusIcons.cycleIndex(root.current, root.layouts.length, steps);
        if (index >= 0)
            root.setLayout(index);
    }

    function setLayout(index) {
        if (index < 0 || index >= root.layouts.length || index === root.current)
            return;
        root._call("setLayout", "u", [index]);
    }

    function refresh() {
        list.running = false;
        list.running = true;
        currentProc.running = false;
        currentProc.running = true;
    }

    function summary() {
        return {
            present: root.present,
            current: root.current,
            label: root.label,
            layouts: root.layouts
        };
    }

    // Sent, not waited for: the layout that results comes back through the
    // watch below, and a second press while the first call is still running
    // is a second switch, not one to drop.
    function _call(method, signature, args) {
        Dbus.send(root.service, root.path, root.iface, method, signature, args);
    }

    readonly property Process _list: Process {
        id: list
        command: Dbus.callArgs(root.service, root.path, root.iface, "getLayoutsList", "", [])
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const data = Dbus.unwrap(text, "getLayoutsList");
                root.layouts = StatusIcons.keyboardLayouts(Array.isArray(data) ? data[0] : []);
            }
        }
    }

    readonly property Process _current: Process {
        id: currentProc
        command: Dbus.callArgs(root.service, root.path, root.iface, "getLayout", "", [])
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const data = Dbus.unwrap(text, "getLayout");
                root.current = Array.isArray(data) && typeof data[0] === "number" ? data[0] : -1;
            }
        }
    }

    // layoutChanged and layoutListChanged; either way, read both again.
    readonly property DbusWatch _watch: DbusWatch {
        service: root.service
        path: root.path
        onChanged: root.refresh()
    }
}
