pragma ComponentBehavior: Bound

// Quick settings' Wi-Fi page: the switch, the networks in reach, and a
// password asked for in place when a secured one is joined for the first
// time. Anything more is Plasma's own applet, a button away.

import QtQuick
import Quickshell
import Quickshell.Networking
import qs.domain.status
import qs.domain.status.icons
import qs.domain.theme
import qs.platform.kde
import qs.ui.primitives
import qs.ui.controls

Column {
    id: wifi

    // The status widget: `typing` hands the popout the keyboard while a
    // password is typed, and its `page` is where the header goes back to.
    required property var widget

    readonly property var device: NetworkStatus.wifiDevices[0] ?? null
    readonly property var networks: Array.from(wifi.device?.networks?.values ?? [])
        .filter(n => n && (n.name ?? "").length > 0)
        .sort((a, b) => (b.connected - a.connected) || (b.known - a.known)
                        || ((b.signalStrength ?? 0) - (a.signalStrength ?? 0)))
        .slice(0, 9)

    // The network a password is being asked for.
    property string asking: ""

    function secured(n) {
        return n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe;
    }

    function choose(n) {
        if (n.connected || n.stateChanging)
            return;
        if (n.known || !wifi.secured(n)) {
            n.connect();
            return;
        }
        wifi.asking = n.name;
        wifi.widget.typing = true;
    }

    spacing: 12

    // A fresh list while the page is open.
    Component.onCompleted: if (wifi.device) wifi.device.scannerEnabled = true
    Component.onDestruction: {
        if (wifi.device)
            wifi.device.scannerEnabled = false;
        wifi.widget.typing = false;
    }

    PageHeader {
        widget: wifi.widget
        title: "Wi-Fi"
        switchable: NetworkStatus.wifiHardwareEnabled
        switchedOn: NetworkStatus.wifiEnabled
        onSwitched: on => NetworkStatus.setWifiEnabled(on)
    }

    PanelText {
        visible: !NetworkStatus.wifiHardwareEnabled || !NetworkStatus.wifiEnabled || wifi.networks.length === 0
        width: parent.width
        wrapMode: Text.WordWrap
        color: Theme.mut
        font.pixelSize: 12
        leftPadding: 4
        text: !NetworkStatus.wifiHardwareEnabled ? "Wi-Fi is off at the hardware: a switch, a key, or airplane mode."
            : !NetworkStatus.wifiEnabled ? "Wi-Fi is off."
            : "Looking for networks…"
    }

    Column {
        visible: NetworkStatus.wifiEnabled
        width: parent.width
        spacing: 2

        Repeater {
            // Through a ScriptModel, not the array: the list is sorted by
            // signal strength, so every scan made a new one, and a Repeater
            // handed a new array rebuilds every row -- the password field with
            // them, emptied under the person typing into it. A network is the
            // same object from one scan to the next, so a re-sort is now a
            // move and a row lives as long as its network is on the list.
            model: ScriptModel {
                values: NetworkStatus.wifiEnabled ? wifi.networks : []
                comparisonMode: ObjectComparison.Identity
            }

            Column {
                id: network

                required property var modelData

                width: parent.width
                spacing: 6

                ItemRow {
                    glyph: StatusIcons.wifiGlyph(network.modelData.signalStrength ?? 0)
                    title: network.modelData.name
                    current: network.modelData.connected
                    sub: network.modelData.stateChanging ? "Connecting…"
                       : network.modelData.connected ? "Connected"
                       : network.modelData.known ? "Saved"
                       : wifi.secured(network.modelData) ? "Secured" : "Open"
                    mark: network.modelData.connected ? "check"
                        : !network.modelData.known && wifi.secured(network.modelData) ? "lock" : ""
                    onActivated: wifi.choose(network.modelData)
                }

                // The password, for a secured network not yet saved.
                // Connecting saves it, as Plasma's applet does.
                Row {
                    visible: wifi.asking === network.modelData.name
                    width: parent.width
                    spacing: 8

                    TextInputRow {
                        id: password
                        width: parent.width - join.width - parent.spacing
                        echoMode: TextInput.Password
                        placeholderText: "Password"
                        onVisibleChanged: if (visible) Qt.callLater(() => password.forceActiveFocus())
                        onAccepted: join.activated()
                        Keys.onEscapePressed: {
                            wifi.asking = "";
                            wifi.widget.typing = false;
                        }
                    }

                    TextButton {
                        id: join
                        primary: true
                        text: "Join"
                        onActivated: {
                            if (password.text.length === 0)
                                return;
                            network.modelData.connectWithPsk(password.text);
                            password.text = "";
                            wifi.asking = "";
                            wifi.widget.typing = false;
                        }
                    }
                }
            }
        }
    }

    TextButton {
        glyph: "settings_ethernet"
        iconName: "network-wireless"
        text: "Networks and VPN…"
        onActivated: {
            PlasmaApplets.open("org.kde.plasma.networkmanagement");
            wifi.widget.closePopout();
        }
    }
}
