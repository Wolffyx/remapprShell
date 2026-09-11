pragma Singleton

// VPN and WireGuard connections, as NetworkManager keeps them.
//
// Read with nmcli -- Quickshell's Networking has no VPNs -- and brought up or
// down the same way. Setting one up is Plasma's network applet's job; this
// only switches the ones already there, and is absent when there are none.

import QtQuick
import Quickshell.Io
import qs.core
import qs.domain.status.icons

QtObject {
    id: root

    property var connections: []

    readonly property bool available: root.connections.length > 0
    readonly property var current: root.connections.find(c => c.active) ?? null
    readonly property bool active: root.current !== null

    function refresh() {
        list.running = false;
        list.running = true;
    }

    // The active one down, or the first one up.
    function toggle() {
        const target = root.current ?? root.connections[0];
        if (!target)
            return;
        change.command = ["nmcli", "connection", target.active ? "down" : "up", "id", target.name];
        change.running = true;
    }

    readonly property Process _list: Process {
        id: list
        command: ["nmcli", "-t", "-f", "NAME,TYPE,ACTIVE", "connection", "show"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.connections = StatusIcons.vpnConnections(StatusIcons.nmcliRows(text))
        }
    }

    readonly property Process _change: Process {
        id: change
        onExited: code => {
            if (code !== 0)
                Log.warn("status", `nmcli could not switch the VPN (exit ${code})`);
            root.refresh();
        }
    }

    // NetworkManager says nothing a busctl monitor would need to parse for
    // this, and VPNs change rarely: a look every half minute is plenty.
    readonly property Timer _poll: Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }
}
