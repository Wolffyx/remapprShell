pragma ComponentBehavior: Bound

// The network, as NetworkManager sees it.
//
// Shows what is connected and switches Wi-Fi on and off. Choosing a network
// means a password prompt and a secret agent, which Plasma's applet already
// does properly, so "Networks and VPN" opens that applet rather than a copy.
// Hidden where NetworkManager is not running: there is nothing to report.

import QtQuick
import qs.domain.status
import qs.domain.status.icons
import qs.domain.theme
import qs.platform.kde
import qs.ui.controls
import qs.ui.primitives

BarWidget {
    id: root

    present: NetworkStatus.available

    tooltip: {
        const lines = NetworkStatus.connections.map(c => c.kind === "wired"
            ? [c.name, StatusIcons.linkSpeed(c.speed)].filter(s => s).join(" · ")
            : `${c.name} · ${StatusIcons.percent(c.strength)}`);
        if (lines.length === 0)
            return "Not connected";
        if (StatusIcons.isLimited(NetworkStatus.connectivity))
            lines.push(NetworkStatus.connectivity === "Portal" ? "A sign-in page is in the way" : "No internet");
        return lines.join("\n");
    }

    implicitWidth: 24
    implicitHeight: 24

    function handleActivate(button) {
        root.popoutVisible = !root.popoutVisible;
    }

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: (hover.hovered || root.popoutVisible) ? PlasmaColors.hoverBackground : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }

        PanelIcon {
            anchors.centerIn: parent
            implicitSize: 18
            iconName: NetworkStatus.icon
        }

        HoverHandler { id: hover }
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
                        width: parent.width - (wifi.visible ? wifi.width + wifiLabel.width + 16 : 0)
                        text: "Network"
                        font.bold: true
                    }

                    PanelText {
                        id: wifiLabel
                        anchors.verticalCenter: parent.verticalCenter
                        visible: wifi.visible
                        text: "Wi-Fi"
                        color: PlasmaColors.foregroundInactive
                        font.pixelSize: 11
                    }

                    Toggle {
                        id: wifi
                        anchors.verticalCenter: parent.verticalCenter
                        visible: NetworkStatus.wifiDevices.length > 0
                        enabled: NetworkStatus.wifiHardwareEnabled
                        opacity: enabled ? 1 : 0.4
                        checked: NetworkStatus.wifiEnabled
                        onToggled: value => NetworkStatus.setWifiEnabled(value)
                    }
                }

                PanelText {
                    visible: NetworkStatus.wifiDevices.length > 0 && !NetworkStatus.wifiHardwareEnabled
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: PlasmaColors.foregroundInactive
                    font.pixelSize: 11
                    text: "Wi-Fi is off at the hardware: a switch, a key, or airplane mode."
                }

                Repeater {
                    model: NetworkStatus.connections

                    Row {
                        id: connection

                        required property var modelData
                        readonly property bool wired: connection.modelData.kind === "wired"

                        width: body.width
                        spacing: 10

                        PanelIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 22
                            iconName: connection.wired ? "network-wired-activated"
                                                       : StatusIcons.wifiIcon(connection.modelData.strength)
                        }

                        Column {
                            width: parent.width - 22 - parent.spacing
                            spacing: 1

                            PanelText {
                                width: parent.width
                                text: connection.modelData.name
                                elide: Text.ElideRight
                                font.bold: true
                            }

                            PanelText {
                                width: parent.width
                                text: [connection.modelData.device,
                                       connection.wired ? StatusIcons.linkSpeed(connection.modelData.speed)
                                                        : StatusIcons.percent(connection.modelData.strength)]
                                      .filter(s => s).join(" · ")
                                color: PlasmaColors.foregroundInactive
                                font.pixelSize: 10
                            }
                        }
                    }
                }

                PanelText {
                    visible: NetworkStatus.connections.length === 0
                    width: parent.width
                    color: PlasmaColors.foregroundInactive
                    font.pixelSize: 11
                    text: "Not connected."
                }

                PanelText {
                    visible: NetworkStatus.connections.length > 0 && StatusIcons.isLimited(NetworkStatus.connectivity)
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: PlasmaColors.neutral
                    font.pixelSize: 11
                    text: NetworkStatus.connectivity === "Portal"
                        ? "Connected, but a sign-in page is in the way."
                        : "Connected, but not to the internet."
                }

                TextButton {
                    text: "Networks and VPN…"
                    iconName: "network-wireless"
                    onActivated: {
                        PlasmaApplets.open("org.kde.plasma.networkmanagement");
                        root.popoutVisible = false;
                    }
                }
            }
        }
    }
}
