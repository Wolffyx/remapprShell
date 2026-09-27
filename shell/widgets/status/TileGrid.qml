pragma ComponentBehavior: Bound

// Quick settings' tiles: the ones the machine could show, the ones chosen of
// them, and the grid they are drawn in -- or rows, when dense.
//
// A tile with a page behind it opens the page; the rest switch something
// through the same service its own widget uses.

import QtQuick
import Quickshell
import qs.domain.notifications
import qs.domain.status
import qs.domain.status.icons
import qs.platform.kde

Column {
    id: grid

    // The status widget: its `tiles` say which are drawn, its `density` how,
    // and its `page` is where a tile with a page goes.
    required property var widget
    readonly property bool dense: grid.widget.density === "dense"

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
    readonly property var chosen: grid.widget.tiles
    readonly property var tiles: grid.chosen.map(id => grid.available.find(t => t.id === id)).filter(t => !!t)

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
    readonly property var tileIds: grid.tiles.map(t => t.id)

    // A tile's contents: the one at its place, which is where it is once the
    // list has settled, as long as the id agrees -- and found by id while the
    // list is still moving under it.
    function tileAt(index, id) {
        const at = grid.tiles[index];
        return at?.id === id ? at : (grid.tiles.find(t => t.id === id) ?? grid.noTile);
    }

    // What a tile on its way out reads, for the moment between its id leaving
    // the list and the tile going.
    readonly property var noTile: ({ id: "", title: "", sub: "", glyph: "", page: "", on: false })

    function activate(tile) {
        if (tile.page)
            grid.widget.page = tile.page;
        else if (tile.act)
            tile.act();
    }

    // The tiles. An odd one out at the end takes the whole row.
    Flow {
        visible: !grid.dense
        width: parent.width
        spacing: 10

        Repeater {
            model: ScriptModel { values: grid.dense ? [] : grid.tileIds }

            Tile {
                id: tile

                // The tile's id, and its place in the grid.
                required property string modelData
                required property int index

                info: grid.tileAt(tile.index, tile.modelData)
                width: tile.index === grid.tiles.length - 1 && grid.tiles.length % 2 === 1
                    ? parent.width : (parent.width - 10) / 2
                onActivated: grid.activate(tile.info)
            }
        }
    }

    Column {
        visible: grid.dense
        width: parent.width
        spacing: 4

        Repeater {
            model: ScriptModel { values: grid.dense ? grid.tileIds : [] }

            TileRow {
                id: row

                // As a Tile's.
                required property string modelData
                required property int index

                info: grid.tileAt(row.index, row.modelData)
                width: parent.width
                onActivated: grid.activate(row.info)
            }
        }
    }
}
