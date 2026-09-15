pragma Singleton

// What the network is doing, as NetworkManager sees it.
//
// Read-mostly, deliberately. Joining a network means asking for a password
// through a secret agent, and Plasma's applet already does that properly; the
// widget opens that applet for it rather than growing a second, lesser one.
// The one thing written here is the Wi-Fi switch.

import QtQuick
import Quickshell.Networking
import qs.domain.status.icons

QtObject {
    id: root

    readonly property bool available: Networking.backend === NetworkBackendType.NetworkManager

    readonly property var devices: Networking.devices?.values ?? []
    readonly property var wiredDevices: root.devices.filter(d => d && d.type === DeviceType.Wired)
    readonly property var wifiDevices: root.devices.filter(d => d && d.type === DeviceType.Wifi)

    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled

    // Named rather than passed through the enum's own toString, whose wording
    // is the library's to change; these names are compared against.
    readonly property string connectivity: {
        switch (Networking.connectivity) {
        case NetworkConnectivity.Full:
            return "Full";
        case NetworkConnectivity.Limited:
            return "Limited";
        case NetworkConnectivity.Portal:
            return "Portal";
        case NetworkConnectivity.None:
            return "None";
        default:
            return "Unknown";
        }
    }

    // One entry per connected device: [{ kind, device, name, speed | strength }].
    readonly property var connections: {
        const out = [];
        // A wired network is named after its interface, which the detail
        // line already shows -- so it is called what it is instead.
        for (const d of root.wiredDevices) {
            if (!d.connected)
                continue;
            const named = d.network?.name && d.network.name !== d.name ? d.network.name : "Ethernet";
            out.push({ kind: "wired", device: d.name, name: named, speed: d.linkSpeed ?? 0 });
        }
        for (const d of root.wifiDevices) {
            if (!d.connected)
                continue;
            const joined = (d.networks?.values ?? []).find(n => n && n.connected);
            out.push({ kind: "wifi", device: d.name, name: joined?.name ?? "", strength: joined?.signalStrength ?? 0 });
        }
        return out;
    }

    readonly property var state: {
        const wifi = root.connections.find(c => c.kind === "wifi");
        return {
            wired: root.connections.some(c => c.kind === "wired"),
            wifi: !!wifi,
            strength: wifi?.strength ?? 0,
            connectivity: root.connectivity
        };
    }

    readonly property string icon: StatusIcons.networkIcon(root.state)
    readonly property string glyph: StatusIcons.networkGlyph(root.state)

    function setWifiEnabled(on) {
        Networking.wifiEnabled = on;
    }

    function summary() {
        return {
            available: root.available,
            connectivity: root.connectivity,
            wifiEnabled: root.wifiEnabled,
            wifiHardwareEnabled: root.wifiHardwareEnabled,
            connections: root.connections,
            icon: root.icon
        };
    }
}
