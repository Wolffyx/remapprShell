pragma ComponentBehavior: Bound

// Quick settings' Bluetooth page: the switch, and the devices already paired,
// to connect or disconnect. Pairing a new one is Plasma's own applet.

import QtQuick
import qs.domain.status
import qs.domain.status.icons
import qs.domain.theme
import qs.platform.kde
import qs.ui.primitives
import qs.ui.controls

Column {
    id: bluetooth

    // The status widget: its `page` is where the header goes back to.
    required property var widget

    spacing: 12

    PageHeader {
        widget: bluetooth.widget
        title: "Bluetooth"
        switchable: !BluetoothStatus.blocked
        switchedOn: BluetoothStatus.enabled
        onSwitched: on => BluetoothStatus.setEnabled(on)
    }

    PanelText {
        visible: !BluetoothStatus.enabled || BluetoothStatus.paired.length === 0
        width: parent.width
        wrapMode: Text.WordWrap
        color: Theme.mut
        font.pixelSize: 12
        leftPadding: 4
        text: BluetoothStatus.blocked ? "Bluetooth is blocked: a switch, a key, or airplane mode."
            : !BluetoothStatus.enabled ? "Bluetooth is off."
            : "No paired devices yet."
    }

    Column {
        visible: BluetoothStatus.enabled
        width: parent.width
        spacing: 2

        Repeater {
            model: BluetoothStatus.enabled ? BluetoothStatus.paired : []

            ItemRow {
                required property var modelData
                glyph: StatusIcons.deviceGlyph(modelData.icon ?? "")
                title: BluetoothStatus.nameOf(modelData)
                sub: BluetoothStatus.describe(modelData)
                current: modelData.connected
                mark: modelData.connected ? "check" : ""
                onActivated: BluetoothStatus.toggleConnection(modelData)
            }
        }
    }

    TextButton {
        glyph: "bluetooth_searching"
        iconName: "preferences-system-bluetooth"
        text: "Pair a new device…"
        onActivated: {
            PlasmaApplets.open("org.kde.plasma.bluetooth");
            bluetooth.widget.closePopout();
        }
    }
}
