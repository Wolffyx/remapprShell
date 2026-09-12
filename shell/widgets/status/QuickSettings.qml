pragma ComponentBehavior: Bound

// Quick settings: the switches and sliders people reach for every day, as the
// design draws them -- a grid of tiles, or rows when dense -- with Wi-Fi and
// Bluetooth a page away.
//
// Everything goes through the services the single widgets use, so a switch
// here and on the volume widget are the same switch. Whatever needs more than
// a switch -- a VPN to set up, a device to pair -- opens Plasma's own applet
// or System Settings, rather than a lesser copy of either.

import QtQuick
import Quickshell
import Quickshell.Networking
import qs.core
import qs.domain.status
import qs.domain.status.icons
import qs.domain.notifications
import qs.domain.session
import qs.domain.theme
import qs.platform.kde
import qs.ui.primitives
import qs.ui.controls

Item {
    id: qs

    required property var widget
    readonly property bool dense: qs.widget.density === "dense"

    implicitWidth: 384
    implicitHeight: (pages.item as Item)?.implicitHeight ?? 0

    function close() {
        qs.widget.popoutVisible = false;
    }

    Loader {
        id: pages
        width: parent.width
        sourceComponent: qs.widget.page === "wifi" ? wifiPage
                       : qs.widget.page === "bluetooth" ? bluetoothPage
                       : mainPage
        onLoaded: slide.restart()

        NumberAnimation {
            id: slide
            target: pages
            property: "x"
            from: qs.widget.page === "main" ? -18 : 18
            to: 0
            duration: 170
            easing.type: Easing.OutCubic
        }
    }

    // ---- the tiles ---------------------------------------------------------
    //
    // What is here depends on what the machine has: no Bluetooth adapter, no
    // Bluetooth tile; GameMode and a VPN only where they exist.

    readonly property var tiles: {
        const t = [];
        const wifiDevice = NetworkStatus.wifiDevices.length > 0;
        if (NetworkStatus.available) {
            const wifi = NetworkStatus.connections.find(c => c.kind !== "wired");
            const wired = NetworkStatus.connections.find(c => c.kind === "wired");
            t.push(wifiDevice ? {
                id: "wifi", title: "Wi-Fi", page: "wifi", on: NetworkStatus.wifiEnabled,
                glyph: !NetworkStatus.wifiEnabled ? "wifi_off" : StatusIcons.wifiGlyph(wifi?.strength ?? 0),
                sub: !NetworkStatus.wifiEnabled ? "Off" : wifi ? wifi.name : "Not connected"
            } : {
                id: "network", title: "Network", page: "", on: !!wired, glyph: NetworkStatus.glyph,
                sub: wired ? wired.name : "Not connected", act: () => PlasmaApplets.open("org.kde.plasma.networkmanagement")
            });
        }
        if (BluetoothStatus.present) {
            const n = BluetoothStatus.connectedCount;
            t.push({ id: "bluetooth", title: "Bluetooth", page: "bluetooth", on: BluetoothStatus.enabled,
                     glyph: BluetoothStatus.glyph,
                     sub: !BluetoothStatus.enabled ? "Off" : n === 0 ? "On" : n === 1 ? "1 device" : `${n} devices` });
        }
        if (AudioStatus.source) {
            t.push({ id: "microphone", title: "Microphone", page: "", on: !AudioStatus.micMuted,
                     glyph: StatusIcons.micGlyph(AudioStatus.micVolume, AudioStatus.micMuted),
                     sub: AudioStatus.micMuted ? "Muted" : "On", act: () => AudioStatus.toggleMicMute() });
        }
        t.push({ id: "dnd", title: "Do not disturb", page: "", on: DoNotDisturb.active,
                 glyph: DoNotDisturb.active ? "do_not_disturb_on" : "do_not_disturb_off",
                 sub: DoNotDisturb.active ? "On" : "Off", act: () => DoNotDisturb.toggle() });
        if (BrightnessStatus.nightState !== "unavailable") {
            const s = BrightnessStatus.nightState;
            t.push({ id: "night", title: "Night Light", page: "", on: s === "warm" || s === "day",
                     glyph: StatusIcons.nightLightGlyph(s),
                     sub: ({ off: "Off in System Settings", suspended: "Suspended", warm: "Warming the screen", day: "On" })[s] ?? "",
                     act: () => s === "off" ? PlasmaApplets.openSettings("kcm_nightlight") : BrightnessStatus.toggleNightLight() });
        }
        if (GameModeStatus.available) {
            t.push({ id: "game", title: "Game mode", page: "", on: GameModeStatus.active, glyph: "sports_esports",
                     sub: GameModeStatus.active ? "On" : "Off", act: () => GameModeStatus.toggle() });
        }
        if (VpnStatus.available) {
            t.push({ id: "vpn", title: "VPN", page: "", on: VpnStatus.active, glyph: "vpn_lock",
                     sub: VpnStatus.current?.name ?? "Disconnected", act: () => VpnStatus.toggle() });
        }
        return t;
    }

    function activate(tile) {
        if (tile.page)
            qs.widget.page = tile.page;
        else if (tile.act)
            tile.act();
    }

    // A tile in the grid: in the accent while on.
    component Tile: Rectangle {
        id: tile

        required property var modelData

        radius: 20
        color: tile.modelData.on ? Theme.acc : (tileHover.hovered ? Theme.s3 : Theme.s2)
        implicitHeight: tileColumn.implicitHeight + 28
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        readonly property color ink: tile.modelData.on ? Theme.accFg : Theme.fg

        Column {
            id: tileColumn
            x: 16
            y: 14
            width: parent.width - 32
            spacing: 0

            Item {
                width: parent.width
                height: 24

                Glyph {
                    name: tile.modelData.glyph
                    size: 24
                    color: tile.ink
                }

                Glyph {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: (tile.modelData.page ?? "").length > 0
                    name: "chevron_right"
                    size: 18
                    color: tile.ink
                    opacity: 0.8
                }
            }

            Item { width: 1; height: 14 }

            PanelText {
                width: parent.width
                elide: Text.ElideRight
                text: tile.modelData.title
                font.pixelSize: 14
                font.weight: Font.Medium
                color: tile.ink
            }

            PanelText {
                width: parent.width
                elide: Text.ElideRight
                text: tile.modelData.sub
                font.pixelSize: 12
                color: tile.modelData.on ? Theme.alpha(Theme.accFg, 0.8) : Theme.mut
            }
        }

        HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: qs.activate(tile.modelData) }
    }

    // A tile as a row, when dense: its switch at the end, or a chevron to its
    // page.
    component TileRow: Rectangle {
        id: row

        required property var modelData
        readonly property bool paged: (row.modelData.page ?? "").length > 0

        height: 44
        radius: 14
        color: row.paged && row.modelData.on ? Theme.accC : (rowHover.hovered ? Theme.s2 : "transparent")

        Glyph {
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            name: row.modelData.glyph
            size: 20
            color: row.modelData.on ? Theme.acc : Theme.mut
        }

        PanelText {
            x: 48
            anchors.verticalCenter: parent.verticalCenter
            text: row.modelData.title
            font.pixelSize: 14
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            PanelText {
                anchors.verticalCenter: parent.verticalCenter
                visible: row.paged
                width: Math.min(implicitWidth, 160)
                elide: Text.ElideRight
                text: row.modelData.sub
                font.pixelSize: 12
                color: Theme.mut
            }

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                visible: row.paged
                name: "chevron_right"
                size: 18
                color: Theme.mut
            }

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                visible: !row.paged
                checked: row.modelData.on
                onToggled: qs.activate(row.modelData)
            }
        }

        HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: if (row.paged) qs.activate(row.modelData) }
    }

    // A page's head: back to the first page, a title, the page's own switch.
    component PageHeader: Item {
        id: head

        property string title: ""
        property bool switchable: true
        property bool switchedOn: false
        signal switched(bool on)

        width: parent ? parent.width : 0
        height: 36

        IconButton {
            id: back
            anchors.verticalCenter: parent.verticalCenter
            glyph: "arrow_back"
            iconName: "go-previous"
            onActivated: qs.widget.page = "main"
        }

        PanelText {
            anchors.left: back.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: head.title
            font.pixelSize: 16
            font.weight: Font.Medium
        }

        Toggle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: head.switchable
            checked: head.switchedOn
            onToggled: value => head.switched(value)
        }
    }

    // A network or a device: what it is, how it is, and a mark at the end.
    component ItemRow: Rectangle {
        id: item

        property string glyph: ""
        property string title: ""
        property string sub: ""
        property string mark: ""
        property bool current: false
        signal activated

        width: parent ? parent.width : 0
        height: 52
        radius: 14
        color: item.current ? Theme.accC : (itemHover.hovered ? Theme.s2 : "transparent")

        Glyph {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            name: item.glyph
            size: 20
            color: item.current ? Theme.acc : Theme.mut
        }

        Column {
            x: 44
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 44 - 40

            PanelText {
                width: parent.width
                elide: Text.ElideRight
                text: item.title
                font.pixelSize: 14
                color: item.current ? Theme.accCFg : Theme.fg
            }

            PanelText {
                visible: item.sub.length > 0
                width: parent.width
                elide: Text.ElideRight
                text: item.sub
                font.pixelSize: 12
                color: item.current ? Theme.alpha(Theme.accCFg, 0.75) : Theme.mut
            }
        }

        Glyph {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            visible: item.mark.length > 0
            name: item.mark
            size: 18
            color: item.current ? Theme.acc : Theme.mut
        }

        HoverHandler { id: itemHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: item.activated() }
    }

    // ---- the first page ----------------------------------------------------

    Component {
        id: mainPage

        Column {
            spacing: 16

            // Who, and the state of the machine: the power profile and the
            // battery on a laptop, the host and how long it has been up on a
            // desktop.
            Item {
                width: parent.width
                height: 44

                Avatar {
                    id: avatar
                    anchors.verticalCenter: parent.verticalCenter
                    size: 40
                    source: Session.avatar
                    initial: Session.initial
                }

                Column {
                    anchors.left: avatar.right
                    anchors.leftMargin: 12
                    anchors.right: headButtons.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter

                    PanelText {
                        width: parent.width
                        elide: Text.ElideRight
                        text: Session.displayName
                        font.pixelSize: 15
                        font.weight: Font.Medium
                    }

                    PanelText {
                        width: parent.width
                        elide: Text.ElideRight
                        font.pixelSize: 12
                        color: Theme.mut
                        text: PowerStatus.present
                            ? [StatusIcons.profileLabel(PowerStatus.profile), StatusIcons.percent(PowerStatus.level), PowerStatus.timeLabel]
                                .filter(s => s).join(" · ")
                            : [Session.hostName, Session.uptime].filter(s => s).join(" · ")
                    }
                }

                Row {
                    id: headButtons
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    IconButton {
                        glyph: "tune"
                        iconName: "configure"
                        onActivated: {
                            Quickshell.execDetached([Branding.ctlBin, "settings"]);
                            qs.close();
                        }
                    }

                    IconButton {
                        glyph: "power_settings_new"
                        iconName: "system-shutdown"
                        onActivated: {
                            qs.close();
                            Session.prompt("promptAll");
                        }
                    }
                }
            }

            // The tiles. An odd one out at the end takes the whole row.
            Flow {
                visible: !qs.dense
                width: parent.width
                spacing: 10

                Repeater {
                    model: qs.dense ? [] : qs.tiles

                    Tile {
                        required property int index
                        width: index === qs.tiles.length - 1 && qs.tiles.length % 2 === 1
                            ? parent.width : (parent.width - 10) / 2
                    }
                }
            }

            Column {
                visible: qs.dense
                width: parent.width
                spacing: 4

                Repeater {
                    model: qs.dense ? qs.tiles : []

                    TileRow { width: parent.width }
                }
            }

            // The levels.
            Rectangle {
                width: parent.width
                height: levels.implicitHeight + 32
                radius: 20
                color: Theme.s2

                Column {
                    id: levels
                    x: 16
                    y: 16
                    width: parent.width - 32
                    spacing: 12

                    Row {
                        visible: !!AudioStatus.sink
                        width: parent.width
                        spacing: 10

                        IconButton {
                            id: muteButton
                            anchors.verticalCenter: parent.verticalCenter
                            glyph: AudioStatus.glyph
                            iconName: AudioStatus.icon
                            onActivated: AudioStatus.toggleMute()
                        }

                        NumberSlider {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - muteButton.width - parent.spacing
                            live: true
                            from: 0
                            to: Math.max(100, Math.round(AudioStatus.volume * 100))
                            value: AudioStatus.volume * 100
                            onMoved: v => AudioStatus.setVolume(v / 100)
                        }
                    }

                    // Every display powerdevil can dim, at once; each has a
                    // slider of its own in the brightness widget.
                    Row {
                        visible: BrightnessStatus.displays.length > 0
                        width: parent.width
                        spacing: 10

                        IconButton {
                            id: sun
                            anchors.verticalCenter: parent.verticalCenter
                            glyph: StatusIcons.brightnessGlyph(BrightnessStatus.level)
                            iconName: BrightnessStatus.icon
                        }

                        NumberSlider {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - sun.width - parent.spacing
                            live: true
                            from: 1
                            to: 100
                            value: BrightnessStatus.level * 100
                            onMoved: v => {
                                for (const d of BrightnessStatus.displays)
                                    BrightnessStatus.setBrightness(d.name, Math.max(StatusIcons.brightnessFloor(d.max),
                                                                                    Math.round(v * d.max / 100)));
                            }
                        }
                    }
                }
            }

            // power-profiles-daemon's profiles, where there is a battery to
            // spare.
            Row {
                visible: PowerStatus.present
                width: parent.width
                spacing: 8

                Repeater {
                    model: PowerStatus.present ? PowerStatus.profiles : []

                    TextButton {
                        required property string modelData
                        width: (parent.width - 8 * (PowerStatus.profiles.length - 1)) / PowerStatus.profiles.length
                        text: StatusIcons.profileLabel(modelData)
                        checked: PowerStatus.profile === modelData
                        onActivated: PowerStatus.setProfile(modelData)
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.out
            }

            Item {
                width: parent.width
                height: 34

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: PowerStatus.present
                        name: PowerStatus.glyph
                        fallback: PowerStatus.icon
                        size: 19
                    }

                    PanelText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: PowerStatus.present ? StatusIcons.percent(PowerStatus.level) : Session.uptime
                        font.pixelSize: 13
                        color: PowerStatus.present ? Theme.fg : Theme.mut
                    }

                    PanelText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: PowerStatus.present && text.length > 0
                        text: PowerStatus.timeLabel ? `· ${PowerStatus.timeLabel}` : ""
                        font.pixelSize: 13
                        color: Theme.mut
                    }
                }

                IconButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: "settings"
                    iconName: "preferences-system"
                    onActivated: {
                        Quickshell.execDetached(["systemsettings"]);
                        qs.close();
                    }
                }
            }
        }
    }

    // ---- Wi-Fi -------------------------------------------------------------

    Component {
        id: wifiPage

        Column {
            id: wifi

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
                qs.widget.typing = true;
            }

            spacing: 12

            // A fresh list while the page is open.
            Component.onCompleted: if (wifi.device) wifi.device.scannerEnabled = true
            Component.onDestruction: {
                if (wifi.device)
                    wifi.device.scannerEnabled = false;
                qs.widget.typing = false;
            }

            PageHeader {
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
                    model: NetworkStatus.wifiEnabled ? wifi.networks : []

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
                                    qs.widget.typing = false;
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
                                    qs.widget.typing = false;
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
                    qs.close();
                }
            }
        }
    }

    // ---- Bluetooth ---------------------------------------------------------

    Component {
        id: bluetoothPage

        Column {
            spacing: 12

            PageHeader {
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
                    qs.close();
                }
            }
        }
    }
}
