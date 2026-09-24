pragma ComponentBehavior: Bound

// KWin virtual desktops, as a row of pills.
//
// KWin owns virtual desktops, so this shows and switches them rather than
// inventing a parallel notion of workspaces. Adding and removing desktops is
// KWin's too -- the widget only asks.
//
// The current desktop is a pill in the accent; one with windows on it is a
// raised pill; an empty one is a dot, so eight desktops fit where three pills
// would. A pill shows the desktop's number, the icons of the windows on it, or
// a dot (`style`), and at most `maxShown` desktops are drawn -- the current
// one always among them.

import QtQuick
import qs.ui.primitives
import qs.domain.desktops
import qs.domain.theme
import qs.domain.windows

BarWidget {
    id: root

    readonly property string style: root.widgetConfig?.style ?? "numbers"
    readonly property int maxShown: Math.max(1, root.widgetConfig?.maxShown ?? 8)
    readonly property bool showNames: root.widgetConfig?.showNames ?? false

    // Scrolling through desktops is a convenience, not everyone's preference:
    // it is easy to trigger by accident while reaching past the panel.
    wantsWheel: root.widgetConfig?.scrollToSwitch ?? true

    // Clicks, and which pill the pointer is over, come through the panel, as
    // they do for the task buttons. A TapHandler per pill never saw a click:
    // the panel's MouseArea, there for the wheel, lay on top of it.
    wantsHover: true

    function handleWheel(delta) {
        Desktops.switchBy(delta > 0 ? -1 : 1);
    }

    // The first `maxShown`, with the current desktop swapped in for the last
    // when it is further along than that.
    readonly property var shownDesktops: {
        const all = Desktops.desktops ?? [];
        if (all.length <= root.maxShown)
            return all;
        const first = all.slice(0, root.maxShown);
        const current = all.find(d => d.id === Desktops.currentId);
        if (current && first.indexOf(current) < 0)
            first[first.length - 1] = current;
        return first;
    }

    // The windows on a desktop. A window on every desktop lists none, and
    // counts for none of them: it would make every pill look occupied.
    function windowsOn(id) {
        return WindowsService.windows.filter(w => Array.isArray(w.desktops) && w.desktops.indexOf(id) >= 0);
    }

    function numberOf(desktop) {
        return (Desktops.desktops ?? []).findIndex(d => d.id === desktop.id) + 1;
    }

    property int hoveredIndex: -1

    tooltip: {
        const d = root.shownDesktops[root.hoveredIndex];
        if (!d)
            return "";
        const n = root.windowsOn(d.id).length;
        const name = d.name && d.name.length > 0 ? d.name : `Desktop ${root.numberOf(d)}`;
        return `${name}\n${n === 0 ? "No windows" : n === 1 ? "1 window" : `${n} windows`}`;
    }
    tooltipCentre: {
        const p = pills.itemAt(root.hoveredIndex);
        return p ? (root.barVertical ? p.y + p.height / 2 : p.x + p.width / 2) : -1;
    }

    function handleHover(position, horizontal) {
        root.hoveredIndex = -1;
        for (let i = 0; i < pills.count; i++) {
            const p = pills.itemAt(i);
            if (!p)
                continue;
            const start = root.barVertical ? p.y : p.x;
            const size = root.barVertical ? p.height : p.width;
            if (position >= start - row.spacing / 2 && position < start + size + row.spacing / 2) {
                root.hoveredIndex = i;
                return;
            }
        }
    }

    onDismissPopout: root.hoveredIndex = -1

    function handleActivate(button) {
        const d = root.shownDesktops[root.hoveredIndex];
        if (d)
            Desktops.switchTo(d.id);
    }

    readonly property int pillSize: Math.max(18, Math.round(34 * root.unit))
    readonly property real k: Math.max(0.7, root.unit)

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    // Only `columns` is set -- see ZoneRow.
    Grid {
        id: row
        anchors.centerIn: parent
        spacing: Math.max(2, Math.round(5 * root.unit))
        columns: root.barVertical ? 1 : Math.max(1, root.shownDesktops.length)
        verticalItemAlignment: Grid.AlignVCenter
        horizontalItemAlignment: Grid.AlignHCenter

        Repeater {
            id: pills
            model: root.shownDesktops

            Rectangle {
                id: pill

                required property var modelData
                required property int index

                readonly property bool active: pill.modelData.id === Desktops.currentId
                readonly property var windows: root.windowsOn(pill.modelData.id)
                readonly property bool occupied: pill.windows.length > 0
                readonly property bool compact: !pill.active && !pill.occupied
                readonly property bool hovered: pill.index === root.hoveredIndex
                readonly property int pad: Math.round((pill.active ? 13 : 11) * root.k)
                readonly property real along: pill.compact ? Math.round(26 * root.k) : content.implicitWidth + 2 * pill.pad

                implicitWidth: root.barVertical ? root.pillSize : pill.along
                implicitHeight: root.barVertical ? (pill.compact ? Math.round(22 * root.k) : content.implicitHeight + 2 * Math.round(8 * root.k)) : root.pillSize
                radius: Math.round(11 * root.k)

                color: pill.active ? Theme.acc
                     : pill.occupied ? (pill.hovered ? Theme.s3 : Theme.s2)
                     : pill.hovered ? Theme.s2 : "transparent"

                Behavior on implicitWidth { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 150 } }

                readonly property color ink: pill.active ? Theme.accFg : Theme.mut

                Grid {
                    id: content
                    anchors.centerIn: parent
                    visible: !pill.compact
                    columns: root.barVertical ? 1 : 3
                    spacing: Math.round(6 * root.k)
                    verticalItemAlignment: Grid.AlignVCenter
                    horizontalItemAlignment: Grid.AlignHCenter

                    PanelText {
                        visible: root.style === "numbers" || (root.style === "icons" && pill.windows.length === 0)
                        text: root.showNames && !root.barVertical && (pill.modelData.name ?? "").length > 0
                            ? pill.modelData.name : String(root.numberOf(pill.modelData))
                        font.pixelSize: 13
                        font.weight: pill.active ? Font.Medium : Font.Normal
                        color: pill.ink
                    }

                    Repeater {
                        model: root.style === "icons" ? pill.windows.slice(0, root.barVertical ? 1 : 2) : []

                        PanelIcon {
                            required property var modelData
                            required property int index
                            implicitSize: Math.round(16 * Math.max(0.85, root.unit))
                            iconName: WindowsService.iconFor(modelData)
                            iconFile: WindowsService.iconFileFor(modelData)
                            opacity: index === 1 ? 0.75 : 1
                        }
                    }

                    Rectangle {
                        visible: root.style === "dots"
                        width: 6
                        height: 6
                        radius: Theme.radiusOf(3)
                        color: pill.ink
                    }
                }

                // An empty desktop is a dot and nothing more.
                Rectangle {
                    anchors.centerIn: parent
                    visible: pill.compact
                    width: 4
                    height: 4
                    radius: Theme.radiusOf(2)
                    color: Theme.mut
                    opacity: 0.6
                }
            }
        }
    }
}
