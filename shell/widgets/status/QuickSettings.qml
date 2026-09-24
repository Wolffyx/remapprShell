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
import qs.domain.config
import qs.domain.status
import qs.domain.status.icons
import qs.domain.notifications
import qs.domain.session
import qs.domain.theme
import qs.platform.kde
import qs.platform.system
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
                       : qs.widget.page === "ethernet" ? ethernetPage
                       : qs.widget.page === "bluetooth" ? bluetoothPage
                       : qs.widget.page === "volume" ? volumePage
                       : qs.widget.page === "microphone" ? microphonePage
                       : qs.widget.page === "brightness" ? brightnessPage
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

    // Every tile the machine could show, by id. What is here depends on what
    // the machine has: no Bluetooth adapter, no Bluetooth tile; GameMode and a
    // VPN only where they exist.
    //
    // Wi-Fi and the cable are two tiles, not one. A desktop with both plugged
    // in had a single "Wi-Fi" tile and no way to see the wired link at all,
    // which is the wrong answer on the machines most likely to have both.
    readonly property var available: {
        const t = [];
        if (NetworkStatus.available && NetworkStatus.wifiDevices.length > 0) {
            const wifi = NetworkStatus.connections.find(c => c.kind === "wifi");
            t.push({ id: "wifi", title: "Wi-Fi", page: "wifi", on: NetworkStatus.wifiEnabled,
                     glyph: !NetworkStatus.wifiEnabled ? "wifi_off" : StatusIcons.wifiGlyph(wifi?.strength ?? 0),
                     sub: !NetworkStatus.wifiEnabled ? "Off" : wifi ? wifi.name : "Not connected" });
        }
        // The cable earns a tile once it carries something, or where there is
        // no Wi-Fi to speak of -- a port with nothing in it, on a machine with
        // a network already, is a tile that says "Not connected" for ever.
        if (NetworkStatus.available && NetworkStatus.wiredDevices.length > 0) {
            const wired = NetworkStatus.connections.find(c => c.kind === "wired");
            if (wired || NetworkStatus.wifiDevices.length === 0) {
                t.push({ id: "ethernet", title: "Ethernet", page: "ethernet", on: !!wired,
                         glyph: wired ? "settings_ethernet" : "lan",
                         sub: wired ? [wired.name, StatusIcons.linkSpeed(wired.speed)].filter(x => x).join(" · ")
                                    : "Not connected" });
            }
        }
        if (BluetoothStatus.present) {
            const n = BluetoothStatus.connectedCount;
            t.push({ id: "bluetooth", title: "Bluetooth", page: "bluetooth", on: BluetoothStatus.enabled,
                     glyph: BluetoothStatus.glyph,
                     sub: !BluetoothStatus.enabled ? "Off" : n === 0 ? "On" : n === 1 ? "1 device" : `${n} devices` });
        }
        if (AudioStatus.source) {
            t.push({ id: "microphone", title: "Microphone", page: "microphone", on: !AudioStatus.micMuted,
                     glyph: StatusIcons.micGlyph(AudioStatus.micVolume, AudioStatus.micMuted),
                     sub: AudioStatus.micMuted ? "Muted" : AudioStatus.nameOf(AudioStatus.source) });
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

    // Which of them are drawn, in the order the setting lists them. A machine
    // that has none of what is chosen shows no grid rather than an empty one.
    readonly property var chosen: qs.widget.tiles
    readonly property var tiles: qs.chosen.map(id => qs.available.find(t => t.id === id)).filter(t => !!t)

    // What the grid repeats: the ids, through a ScriptModel. `tiles` is made
    // afresh whenever anything any tile says changes -- a signal strength, a
    // device connecting -- and a Repeater over it built every tile again each
    // time. Over the ids a tile is built once, and reads what it says through
    // tileAt.
    //
    // Not a ScriptModel over the tiles themselves with `objectProp: "id"`. In
    // Quickshell 0.3.1 a row it moves keeps the object it had, and once it has
    // updated one row in place it goes on updating the rows after it by
    // position, whatever their ids -- so a tile could show another's state, or
    // a stale one, until the next change. Strings compare by value, and a list
    // of them is only ever inserted into, removed from and reordered.
    readonly property var tileIds: qs.tiles.map(t => t.id)

    // A tile's contents: the one at its place, which is where it is once the
    // list has settled, as long as the id agrees -- and found by id while the
    // list is still moving under it.
    function tileAt(index, id) {
        const at = qs.tiles[index];
        return at?.id === id ? at : (qs.tiles.find(t => t.id === id) ?? qs.noTile);
    }

    // What a tile on its way out reads, for the moment between its id leaving
    // the list and the tile going.
    readonly property var noTile: ({ id: "", title: "", sub: "", glyph: "", page: "", on: false })

    function activate(tile) {
        if (tile.page)
            qs.widget.page = tile.page;
        else if (tile.act)
            tile.act();
    }

    // A tile in the grid: in the accent while on.
    component Tile: Rectangle {
        id: tile

        // The tile's id, and its place in the grid.
        required property string modelData
        required property int index
        readonly property var info: qs.tileAt(tile.index, tile.modelData)

        radius: Theme.radiusOf(20)
        color: tile.info.on ? Theme.acc : (tileHover.hovered ? Theme.s3 : Theme.s2)
        implicitHeight: tileColumn.implicitHeight + 28
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        readonly property color ink: tile.info.on ? Theme.accFg : Theme.fg

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
                    name: tile.info.glyph
                    size: 24
                    color: tile.ink
                }

                Glyph {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: (tile.info.page ?? "").length > 0
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
                text: tile.info.title
                font.pixelSize: 14
                font.weight: Font.Medium
                color: tile.ink
            }

            PanelText {
                width: parent.width
                elide: Text.ElideRight
                text: tile.info.sub
                font.pixelSize: 12
                color: tile.info.on ? Theme.alpha(Theme.accFg, 0.8) : Theme.mut
            }
        }

        HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: qs.activate(tile.info) }
    }

    // A tile as a row, when dense: its switch at the end, or a chevron to its
    // page.
    component TileRow: Rectangle {
        id: row

        // As a Tile's.
        required property string modelData
        required property int index
        readonly property var info: qs.tileAt(row.index, row.modelData)
        readonly property bool paged: (row.info.page ?? "").length > 0

        height: 44
        radius: Theme.radiusOf(14)
        color: row.paged && row.info.on ? Theme.accC : (rowHover.hovered ? Theme.s2 : "transparent")

        Glyph {
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            name: row.info.glyph
            size: 20
            color: row.info.on ? Theme.acc : Theme.mut
        }

        PanelText {
            x: 48
            anchors.verticalCenter: parent.verticalCenter
            text: row.info.title
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
                text: row.info.sub
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
                checked: row.info.on
                onToggled: qs.activate(row.info)
            }
        }

        HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: if (row.paged) qs.activate(row.info) }
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
        radius: Theme.radiusOf(14)
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
                    model: ScriptModel { values: qs.dense ? [] : qs.tileIds }

                    Tile {
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
                    model: ScriptModel { values: qs.dense ? qs.tileIds : [] }

                    TileRow { width: parent.width }
                }
            }

            // The levels. Sliders, not a panel of sliders: the popout is
            // already a card, and a card inside it is one more background
            // between the wallpaper and the thing being read.
            Item {
                width: parent.width
                height: levels.implicitHeight + 32

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.out
                }

                Column {
                    id: levels
                    x: 16
                    y: 16
                    width: parent.width - 32
                    spacing: 12

                    // Each level has a page behind it, reached by the chevron
                    // at its end: the devices to play through or record from,
                    // and a slider per display. The tiles have had that since
                    // the design was drawn and the sliders had not, which left
                    // the output device pickable only in Plasma's own applet.
                    LevelSlider {
                        visible: !!AudioStatus.sink
                        width: parent.width
                        glyph: AudioStatus.glyph
                        iconName: AudioStatus.icon
                        to: Math.round(AudioStatus.ceilingFor(AudioStatus.volume) * 100)
                        value: AudioStatus.volume * 100
                        onMoved: v => AudioStatus.setVolume(v / 100)
                        onIconActivated: AudioStatus.toggleMute()

                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            glyph: "chevron_right"
                            iconName: "go-next"
                            onActivated: qs.widget.page = "volume"
                        }
                    }

                    // Every display powerdevil can dim, at once; the page
                    // behind this has a slider per display.
                    LevelSlider {
                        visible: BrightnessStatus.displays.length > 0
                        width: parent.width
                        glyph: StatusIcons.brightnessGlyph(BrightnessStatus.level)
                        iconName: BrightnessStatus.icon
                        from: 1
                        value: BrightnessStatus.level * 100
                        onMoved: v => BrightnessStatus.setAllPercent(v)

                        IconButton {
                            anchors.verticalCenter: parent.verticalCenter
                            glyph: "chevron_right"
                            iconName: "go-next"
                            // One display and no night light to speak of is a
                            // page with the slider already on this one on it.
                            visible: BrightnessStatus.displays.length > 1
                                     || BrightnessStatus.nightState !== "unavailable"
                            onActivated: qs.widget.page = "brightness"
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
                        Launch.command(["systemsettings"], "systemsettings");
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
                    // Through a ScriptModel, not the array: the list is sorted
                    // by signal strength, so every scan made a new one, and a
                    // Repeater handed a new array rebuilds every row -- the
                    // password field with them, emptied under the person
                    // typing into it. A network is the same object from one
                    // scan to the next, so a re-sort is now a move and a row
                    // lives as long as its network is on the list.
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

    // ---- Ethernet ----------------------------------------------------------
    //
    // Read-only, like the rest of what this shell does with NetworkManager:
    // bringing a wired connection up or down, or editing one, is Plasma's
    // applet's job and it does it properly.

    Component {
        id: ethernetPage

        Column {
            spacing: 12

            PageHeader {
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
                            qs.close();
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
                    qs.close();
                }
            }
        }
    }

    // ---- sound, and the microphone -----------------------------------------
    //
    // One component for both: an output and an input differ in which node they
    // write to and in nothing else anybody looking at the page would name.
    // Two copies of this drifted apart in every shell that has written them.

    component LevelPage: Column {
        id: level

        property string title: ""
        property string glyph: ""
        property var devices: []
        property var current: null
        property real volume: 0
        property bool muted: false
        property string emptyText: ""

        signal setLevel(real value)
        signal setMuted(bool value)
        signal use(var node)

        spacing: 12

        PageHeader {
            title: level.title
            switchedOn: !level.muted
            onSwitched: on => level.setMuted(!on)
        }

        // The level itself, so the page it was reached from is not the only
        // place to set it.
        LevelSlider {
            width: parent.width
            glyph: level.glyph
            sliderEnabled: !level.muted
            to: Math.round(AudioStatus.ceilingFor(level.volume) * 100)
            value: level.volume * 100
            onMoved: v => level.setLevel(v / 100)
            onIconActivated: level.setMuted(!level.muted)
        }

        PanelText {
            visible: level.devices.length === 0
            width: parent.width
            wrapMode: Text.WordWrap
            color: Theme.mut
            font.pixelSize: 12
            leftPadding: 4
            text: level.emptyText
        }

        Column {
            width: parent.width
            spacing: 2

            Repeater {
                model: level.devices

                ItemRow {
                    required property var modelData
                    glyph: level.glyph
                    title: AudioStatus.nameOf(modelData)
                    current: modelData === level.current
                    mark: modelData === level.current ? "check" : ""
                    onActivated: level.use(modelData)
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.out
        }

        // The one thing on these pages that is a setting rather than a state:
        // it is written to the configuration and every slider in the shell
        // reads it, which is why it is here rather than being a mode this
        // popout remembers by itself.
        ToggleRow {
            width: parent.width
            label: "Raise maximum volume"
            description: "Up to 150%, amplified in software. It distorts on most hardware."
            checked: AudioStatus.raiseMax
            onToggled: value => ConfigStore.set("audio.raiseMaxVolume", value)
        }

        TextButton {
            glyph: "tune"
            iconName: "preferences-desktop-sound"
            text: "Sound settings…"
            onActivated: {
                PlasmaApplets.openSettings("kcm_pulseaudio");
                qs.close();
            }
        }
    }

    Component {
        id: volumePage

        LevelPage {
            title: "Sound"
            glyph: AudioStatus.glyph
            devices: AudioStatus.sinks
            current: AudioStatus.sink
            volume: AudioStatus.volume
            muted: AudioStatus.muted
            emptyText: "No sound output."
            onSetLevel: value => AudioStatus.setVolume(value)
            onSetMuted: value => { if (value !== AudioStatus.muted) AudioStatus.toggleMute(); }
            onUse: node => AudioStatus.useSink(node)
        }
    }

    Component {
        id: microphonePage

        LevelPage {
            title: "Microphone"
            glyph: StatusIcons.micGlyph(AudioStatus.micVolume, AudioStatus.micMuted)
            devices: AudioStatus.sources
            current: AudioStatus.source
            volume: AudioStatus.micVolume
            muted: AudioStatus.micMuted
            emptyText: "No input device."
            onSetLevel: value => AudioStatus.setMicVolume(value)
            onSetMuted: value => { if (value !== AudioStatus.micMuted) AudioStatus.toggleMicMute(); }
            onUse: node => AudioStatus.useSource(node)
        }
    }

    // ---- brightness --------------------------------------------------------

    Component {
        id: brightnessPage

        Column {
            spacing: 12

            PageHeader {
                title: "Brightness"
                switchable: false
            }

            PanelText {
                visible: BrightnessStatus.displays.length === 0
                width: parent.width
                wrapMode: Text.WordWrap
                color: Theme.mut
                font.pixelSize: 12
                leftPadding: 4
                text: "No display powerdevil can dim."
            }

            // One slider per display, rather than the one on the first page
            // that moves all of them together.
            Column {
                width: parent.width
                spacing: 10

                // Keyed by name, as the brightness widget's are: every step
                // of a drag replaces the list of displays, and a Repeater over
                // the list itself rebuilt the row -- and the slider -- being
                // dragged.
                Repeater {
                    model: JSON.parse(BrightnessStatus.displayNames)

                    Column {
                        id: screen

                        required property string modelData
                        readonly property var display: BrightnessStatus.displayNamed(screen.modelData)
                                                       ?? { label: "", brightness: 0, max: 1 }

                        width: parent.width
                        spacing: 2

                        // powerdevil's own name for a display ("display0")
                        // is an id, not a name anybody chose; its label is the
                        // monitor's own, as the manufacturer wrote it. The
                        // brightness widget has always shown the label and
                        // this page showed the id instead.
                        PanelText {
                            width: parent.width
                            elide: Text.ElideRight
                            text: screen.display.label || screen.modelData
                            font.pixelSize: 12
                            color: Theme.mut
                            leftPadding: 4
                        }

                        LevelSlider {
                            width: parent.width
                            glyph: StatusIcons.brightnessGlyph((screen.display.brightness ?? 0) / Math.max(1, screen.display.max))
                            from: 1
                            value: 100 * (screen.display.brightness ?? 0) / Math.max(1, screen.display.max)
                            onMoved: v => BrightnessStatus.setPercent(screen.modelData, v)
                        }
                    }
                }
            }

            Rectangle {
                visible: BrightnessStatus.nightState !== "unavailable"
                width: parent.width
                height: 1
                color: Theme.out
            }

            // Said the way the brightness widget says it -- the state in
            // words, and when it next changes -- rather than in wording of
            // this page's own. Two screens describing one thing differently
            // is how a reader ends up believing they are two things.
            ToggleRow {
                visible: BrightnessStatus.nightState !== "unavailable"
                width: parent.width
                label: StatusIcons.nightLightLabel(BrightnessStatus.nightLight)
                description: BrightnessStatus.nightState === "off"
                    ? "Off in System Settings, which is the only place that turns it on."
                    : BrightnessStatus.nightDetail
                enabled: BrightnessStatus.nightState !== "off"
                checked: BrightnessStatus.nightState === "warm" || BrightnessStatus.nightState === "day"
                onToggled: BrightnessStatus.toggleNightLight()
            }

            TextButton {
                glyph: "display_settings"
                iconName: "preferences-desktop-display"
                text: "Display settings…"
                onActivated: {
                    PlasmaApplets.openSettings("kcm_kscreen");
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
