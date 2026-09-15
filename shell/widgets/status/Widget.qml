pragma ComponentBehavior: Bound

// Network, Bluetooth, sound and battery in one place, as the design has it:
// their glyphs on the panel, and quick settings a click away.
//
// Every glyph is the one the part's own widget draws, from the same service,
// so the two cannot disagree -- and the parts can still be put on the panel
// one by one. A part with no hardware, a battery on a desktop, is left out.
// Each glyph names itself when the pointer rests on it. Scroll for the
// volume, middle-click to mute, as on the volume widget.

import QtQuick
import qs.domain.status
import qs.domain.status.icons
import qs.domain.theme
import qs.ui.primitives

BarWidget {
    id: root

    readonly property string density: root.widgetConfig?.density ?? "roomy"

    // Which tiles the grid draws, in this order. The manifest's default is
    // every one of them; what the machine actually has still decides.
    readonly property var tiles: root.widgetConfig?.tiles
        ?? ["wifi", "ethernet", "bluetooth", "microphone", "dnd", "night", "game", "vpn"]
    readonly property int step: root.widgetConfig?.step ?? 5
    readonly property bool vertical: !(root.bar?.horizontal ?? true)
    readonly property real k: Math.max(0.7, root.unit)
    readonly property int size: Math.max(22, Math.round(40 * root.unit))

    // Which page of quick settings is showing. Kept here rather than in the
    // popout, so that closing it and opening it again starts at the top.
    property string page: "main"

    // Set while a Wi-Fi password is being typed: only then does the popout
    // take the keyboard from the window in use.
    property bool typing: false

    readonly property var parts: [
        { id: "network", shown: NetworkStatus.available, glyph: NetworkStatus.glyph, icon: NetworkStatus.icon },
        { id: "bluetooth", shown: BluetoothStatus.present, glyph: BluetoothStatus.glyph, icon: BluetoothStatus.icon },
        { id: "volume", shown: true, glyph: AudioStatus.glyph, icon: AudioStatus.icon },
        { id: "battery", shown: PowerStatus.present, glyph: PowerStatus.glyph, icon: PowerStatus.icon }
    ].filter(p => p.shown)

    function tipFor(id) {
        switch (id) {
        case "network": {
            const lines = NetworkStatus.connections.map(c => c.kind === "wired"
                ? [c.name, StatusIcons.linkSpeed(c.speed)].filter(s => s).join(" · ")
                : `${c.name} · ${StatusIcons.percent(c.strength)}`);
            if (lines.length === 0)
                return "Not connected";
            if (StatusIcons.isLimited(NetworkStatus.connectivity))
                lines.push(NetworkStatus.connectivity === "Portal" ? "A sign-in page is in the way" : "No internet");
            return lines.join("\n");
        }
        case "bluetooth": {
            if (!BluetoothStatus.enabled)
                return "Bluetooth is off";
            const on = BluetoothStatus.paired.filter(d => d.connected);
            return on.length === 0 ? "Bluetooth on\nNothing connected"
                : `Bluetooth on\n${on.map(d => d.batteryAvailable ? `${BluetoothStatus.nameOf(d)} ${StatusIcons.percent(d.battery)}`
                                                                : BluetoothStatus.nameOf(d)).join(" · ")}`;
        }
        case "volume":
            return AudioStatus.sink
                ? `${AudioStatus.muted ? "Muted" : `Volume ${StatusIcons.percent(AudioStatus.volume)}`}\n${AudioStatus.nameOf(AudioStatus.sink)}`
                : "No sound output";
        case "battery":
            return [`Battery ${StatusIcons.percent(PowerStatus.level)}`,
                    [PowerStatus.timeLabel || PowerStatus.stateLabel, StatusIcons.profileLabel(PowerStatus.profile)]
                        .filter(s => s).join(" · ")].join("\n");
        }
        return "";
    }

    property int hoveredIndex: -1

    tooltip: root.hoveredIndex >= 0 ? root.tipFor(root.parts[root.hoveredIndex]?.id ?? "") : "Network, sound and battery"
    tooltipCentre: {
        const g = glyphs.itemAt(root.hoveredIndex);
        if (!g)
            return -1;
        return root.vertical ? layout.y + g.y + g.height / 2 : layout.x + g.x + g.width / 2;
    }

    wantsHover: true
    wantsWheel: true

    function handleHover(position, horizontal) {
        const p = position - (root.vertical ? layout.y : layout.x);
        root.hoveredIndex = -1;
        for (let i = 0; i < glyphs.count; i++) {
            const g = glyphs.itemAt(i);
            if (!g)
                continue;
            const start = root.vertical ? g.y : g.x;
            const length = root.vertical ? g.height : g.width;
            if (p >= start - layout.spacing / 2 && p < start + length + layout.spacing / 2) {
                root.hoveredIndex = i;
                return;
            }
        }
    }

    onDismissPopout: root.hoveredIndex = -1

    function handleWheel(delta) {
        AudioStatus.setVolume(StatusIcons.stepVolume(AudioStatus.volume, delta, root.step, AudioStatus.maxVolume));
    }

    function handleActivate(button) {
        if (button === Qt.MiddleButton) {
            AudioStatus.toggleMute();
            return;
        }
        root.popoutVisible = !root.popoutVisible;
    }

    onPopoutVisibleChanged: {
        if (!root.popoutVisible) {
            root.page = "main";
            root.typing = false;
        } else {
            VpnStatus.refresh();
        }
    }

    popoutGrabsFocus: root.typing
    popout: Component {
        QuickSettings { widget: root }
    }

    implicitWidth: root.vertical ? root.size : layout.implicitWidth + 2 * Math.round(13 * root.k)
    implicitHeight: root.vertical ? layout.implicitHeight + 2 * Math.round(11 * root.k) : root.size

    Rectangle {
        anchors.fill: parent
        radius: Math.round(13 * root.k)
        color: root.hovered || root.popoutVisible ? Theme.s2 : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    }

    // Only `columns` is set -- see ZoneRow.
    Grid {
        id: layout
        anchors.centerIn: parent
        columns: root.vertical ? 1 : Math.max(1, root.parts.length)
        spacing: Math.round(11 * root.k)

        Repeater {
            id: glyphs
            model: root.parts

            Glyph {
                required property var modelData
                name: modelData.glyph
                fallback: modelData.icon
                size: root.panelIconSize
                color: Theme.fg
            }
        }
    }
}
