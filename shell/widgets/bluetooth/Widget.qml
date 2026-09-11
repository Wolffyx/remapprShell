pragma ComponentBehavior: Bound

// Bluetooth, as BlueZ sees it.
//
// Switches the adapter and connects or disconnects a device already paired,
// which is most of what anyone does with Bluetooth day to day. Pairing a new
// device needs a PIN prompt and an agent, which Plasma's applet has, so
// "Pair a device" opens that. No adapter, no widget.

import QtQuick
import qs.domain.status
import qs.domain.status.icons
import qs.domain.theme
import qs.platform.kde
import qs.ui.controls
import qs.ui.primitives

BarWidget {
    id: root

    present: BluetoothStatus.present

    tooltip: {
        if (!BluetoothStatus.enabled)
            return "Bluetooth is off";
        const on = BluetoothStatus.paired.filter(d => d.connected);
        if (on.length === 0)
            return "Bluetooth: nothing connected";
        return on.map(d => d.batteryAvailable
            ? `${BluetoothStatus.nameOf(d)} · ${StatusIcons.percent(d.battery)}`
            : BluetoothStatus.nameOf(d)).join("\n");
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    function handleActivate(button) {
        root.popoutVisible = !root.popoutVisible;
    }

    BarButton {
        id: button
        thickness: root.bar?.thickness ?? 40
        hovered: root.hovered
        active: root.popoutVisible
        size: Math.max(22, Math.round(40 * root.unit))
        glyph: BluetoothStatus.glyph
        fallback: BluetoothStatus.icon
        glyphSize: root.panelIconSize
    }

    popout: Component {
        Item {
            implicitWidth: 300
            implicitHeight: body.implicitHeight

            Column {
                id: body
                width: parent.width
                spacing: 8

                Row {
                    width: parent.width
                    spacing: 8

                    PanelText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - power.width - 8
                        text: "Bluetooth"
                        font.bold: true
                    }

                    Toggle {
                        id: power
                        anchors.verticalCenter: parent.verticalCenter
                        enabled: !BluetoothStatus.blocked
                        opacity: enabled ? 1 : 0.4
                        checked: BluetoothStatus.enabled
                        onToggled: value => BluetoothStatus.setEnabled(value)
                    }
                }

                PanelText {
                    visible: BluetoothStatus.blocked
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: Theme.foregroundInactive
                    font.pixelSize: 11
                    text: "Bluetooth is blocked: a hardware switch, a key, or airplane mode."
                }

                Repeater {
                    model: BluetoothStatus.enabled ? BluetoothStatus.paired : []

                    Rectangle {
                        id: device

                        required property var modelData

                        width: body.width
                        height: line.implicitHeight + 10
                        radius: 6
                        color: deviceHover.hovered ? Theme.hoverBackground : "transparent"

                        Row {
                            id: line
                            x: 6
                            y: 5
                            width: parent.width - 12
                            spacing: 10

                            PanelIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                implicitSize: 22
                                iconName: device.modelData.icon ?? ""
                                fallbackName: "network-bluetooth"
                                opacity: device.modelData.connected ? 1 : 0.6
                            }

                            Column {
                                width: parent.width - 22 - parent.spacing
                                spacing: 1

                                PanelText {
                                    width: parent.width
                                    text: BluetoothStatus.nameOf(device.modelData)
                                    elide: Text.ElideRight
                                    font.bold: device.modelData.connected
                                }

                                PanelText {
                                    width: parent.width
                                    text: BluetoothStatus.describe(device.modelData)
                                    color: Theme.foregroundInactive
                                    font.pixelSize: 10
                                }
                            }
                        }

                        HoverHandler { id: deviceHover }
                        TapHandler { onTapped: BluetoothStatus.toggleConnection(device.modelData) }
                    }
                }

                PanelText {
                    visible: BluetoothStatus.enabled && BluetoothStatus.paired.length === 0
                    width: parent.width
                    color: Theme.foregroundInactive
                    font.pixelSize: 11
                    text: "No paired devices."
                }

                TextButton {
                    text: "Pair a device…"
                    iconName: "network-bluetooth"
                    onActivated: {
                        PlasmaApplets.open("org.kde.plasma.bluetooth");
                        root.popoutVisible = false;
                    }
                }
            }
        }
    }
}
