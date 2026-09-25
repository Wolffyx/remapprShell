pragma ComponentBehavior: Bound

// Quick settings' Wi-Fi page: the switch, the networks in reach, and a
// password asked for in place when a secured one is joined for the first
// time. Anything more is Plasma's own applet, a button away.

import QtQuick
import Quickshell
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

    // Already sorted -- connected, then saved, then by signal -- and one per
    // name (NmcliState).
    readonly property var networks: NetworkStatus.wifiNetworks.slice(0, 9)

    // The network a password is being asked for.
    property string asking: ""

    function choose(n) {
        if (n.connected || NetworkStatus.joining.length > 0)
            return;
        // More than a password: Plasma's applet sets those up.
        if (n.enterprise && !n.known) {
            PlasmaApplets.open("org.kde.plasma.networkmanagement");
            wifi.widget.closePopout();
            return;
        }
        if (n.known || !n.secured) {
            NetworkStatus.connectTo(n, "");
            return;
        }
        wifi.asking = n.name;
        wifi.widget.typing = true;
    }

    spacing: 12

    // A fresh list while the page is open: a rescan now, and again while it
    // stays open, as Plasma's applet does.
    Component.onCompleted: NetworkStatus.scan()
    Component.onDestruction: wifi.widget.typing = false

    Timer {
        interval: 12000
        running: true
        repeat: true
        onTriggered: NetworkStatus.scan()
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
            // Through a ScriptModel keyed by name, not the array: every read
            // makes new objects, and a Repeater handed a new array rebuilds
            // every row -- the password field with them, emptied under the
            // person typing into it. Keyed, a network's row lives as long as
            // the network is on the list, and reads its latest state by name.
            model: ScriptModel {
                values: NetworkStatus.wifiEnabled ? wifi.networks : []
                objectProp: "key"
            }

            Column {
                id: network

                required property var modelData
                readonly property var live: wifi.networks.find(n => n.key === network.modelData.key) ?? network.modelData

                width: parent.width
                spacing: 6

                ItemRow {
                    glyph: StatusIcons.wifiGlyph(network.live.signal ?? 0)
                    title: network.live.name
                    current: network.live.connected
                    sub: NetworkStatus.joining === network.live.name ? "Connecting…"
                       : network.live.connected ? "Connected"
                       : NetworkStatus.failed === network.live.name ? "Could not connect"
                       : network.live.known ? "Saved"
                       : network.live.enterprise ? "Enterprise -- set up in Plasma's applet"
                       : network.live.secured ? "Secured" : "Open"
                    mark: network.live.connected ? "check"
                        : !network.live.known && network.live.secured ? "lock" : ""
                    onActivated: wifi.choose(network.live)
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
                            NetworkStatus.connectTo(network.live, password.text);
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
