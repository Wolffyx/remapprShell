pragma Singleton

// Bluetooth, as BlueZ sees it.
//
// Switching the adapter and connecting a device that is already paired are
// done here; pairing a new one needs a PIN prompt and an agent, which
// Plasma's applet already provides, so the widget opens that for it.

import QtQuick
import Quickshell.Bluetooth
import qs.domain.status.icons

QtObject {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool present: !!root.adapter
    readonly property bool enabled: root.adapter?.enabled ?? false

    // rfkill or airplane mode: the adapter exists and will not switch on.
    readonly property bool blocked: root.adapter?.state === BluetoothAdapterState.Blocked

    readonly property var devices: root.adapter?.devices?.values ?? []

    // Connected first, then by name, so what is in use is at the top.
    readonly property var paired: root.devices
        .filter(d => d && d.paired)
        .sort((a, b) => (b.connected - a.connected) || root.nameOf(a).localeCompare(root.nameOf(b)))

    readonly property int connectedCount: root.devices.filter(d => d && d.connected).length

    readonly property string icon: StatusIcons.bluetoothIcon(root.enabled, root.connectedCount)
    readonly property string glyph: StatusIcons.bluetoothGlyph(root.enabled, root.connectedCount)

    function nameOf(device) {
        return device?.name || device?.deviceName || device?.address || "";
    }

    function describe(device) {
        if (!device)
            return "";
        switch (device.state) {
        case BluetoothDeviceState.Connecting:
            return "Connecting…";
        case BluetoothDeviceState.Disconnecting:
            return "Disconnecting…";
        case BluetoothDeviceState.Connected:
            return device.batteryAvailable ? `Connected · ${StatusIcons.percent(device.battery)}` : "Connected";
        default:
            return "Not connected";
        }
    }

    function setEnabled(on) {
        if (root.adapter)
            root.adapter.enabled = on;
    }

    function toggleConnection(device) {
        if (!device)
            return;
        if (device.connected)
            device.disconnect();
        else
            device.connect();
    }

    function summary() {
        return {
            present: root.present,
            enabled: root.enabled,
            blocked: root.blocked,
            paired: root.paired.map(d => ({ name: root.nameOf(d), state: root.describe(d) })),
            icon: root.icon
        };
    }
}
