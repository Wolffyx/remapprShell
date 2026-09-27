pragma ComponentBehavior: Bound

// Quick settings' Ethernet page: the wired devices, and how each is.
//
// Read-only, like the rest of what this shell does with NetworkManager:
// bringing a wired connection up or down, or editing one, is Plasma's
// applet's job and it does it properly.

import QtQuick
import qs.domain.status
import qs.domain.status.icons
import qs.domain.theme
import qs.platform.kde
import qs.ui.primitives
import qs.ui.controls

Column {
    id: ethernet

    // The status widget: its `page` is where the header goes back to.
    required property var widget

    spacing: 12

    PageHeader {
        widget: ethernet.widget
        title: "Ethernet"
        switchable: false
    }

    PanelText {
        visible: NetworkStatus.wiredDevices.length === 0
        width: parent.width
        wrapMode: Text.WordWrap
        color: Theme.mut
        font.pixelSize: 12
        leftPadding: 4
        text: "No wired device."
    }

    Column {
        width: parent.width
        spacing: 2

        Repeater {
            model: NetworkStatus.wiredDevices

            ItemRow {
                required property var modelData
                glyph: modelData.connected ? "settings_ethernet" : "lan"
                title: modelData.network?.name && modelData.network.name !== modelData.name
                    ? modelData.network.name : "Ethernet"
                sub: [modelData.name,
                      modelData.connected ? StatusIcons.linkSpeed(modelData.linkSpeed ?? 0) : "Cable out"]
                    .filter(x => x).join(" · ")
                current: modelData.connected
                mark: modelData.connected ? "check" : ""
                onActivated: {
                    PlasmaApplets.open("org.kde.plasma.networkmanagement");
                    ethernet.widget.closePopout();
                }
            }
        }
    }

    TextButton {
        glyph: "settings_ethernet"
        iconName: "network-wired"
        text: "Networks and VPN…"
        onActivated: {
            PlasmaApplets.open("org.kde.plasma.networkmanagement");
            ethernet.widget.closePopout();
        }
    }
}
